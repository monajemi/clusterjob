package CJ::R;

# This is the R class of CJ 
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu) 

use strict;
use warnings;
use CJ;
use Data::Dumper;
use feature 'say';


# class constructor
sub new {
	my $class = shift;
 	my ($path,$program,$dep_folder) = @_;
	
	my $self= bless {
		path 	=> $path, 
		program => $program,
        dep_folder=>$dep_folder
	}, $class;
		
	return $self;
	
}



#####################
sub parse {
    #####################
    my $self = shift;
    
    # script lines will have blank lines or comment lines removed;
    # ie., all remaining lines are effective codes
    # that actually do something.
    my @CJbang;
    my $script_lines;
    open my $fh, "$self->{path}/$self->{program}" or CJ::err("Couldn't open file: $!");
    while(<$fh>){
        
        #if line starts with CJbang, keep them in CJbang!
        
        if($_ =~ /^\#CJ\s*(.*)$/){
            push @CJbang, $1;
        }else{
        $_ = $self->uncomment_R_line($_);
        if (!/^\s*$/){
            $script_lines .= $_;
        }
    }
}
close $fh;

# this includes fors on one line
my @lines = split('\n|[{]\s*(?=for)', $script_lines);


my @forlines_idx_set;
foreach my $i (0..$#lines){
    my $line = $lines[$i];
    if ($line =~ /^[\t\s]*(for.*)/ ){
        push @forlines_idx_set, $i;
    }
}

# ==============================================================
# complain if for loops are not
# consecutive. We do not allow it in clusterjob.
# ==============================================================
&CJ::err(" 'parrun' does not allow less than 1 parallel loops inside the MAIN script.") if ($#forlines_idx_set+1 < 1);

foreach my $i (0..$#forlines_idx_set-1){
    &CJ::err("CJ does not allow anything between the parallel for's. try rewriting your loops.") if($forlines_idx_set[$i+1] ne $forlines_idx_set[$i]+1);
}


my $TOP;
my $FOR;
my $BOT;

foreach my $i (0..$forlines_idx_set[0]-1){
    $TOP .= "$lines[$i]\n";
}
foreach my $i ($forlines_idx_set[0]..$forlines_idx_set[0]+$#forlines_idx_set){
    $FOR .= "$lines[$i]\n";
}
foreach my $i ($forlines_idx_set[0]+$#forlines_idx_set+1..$#lines){
    $BOT .= "$lines[$i]\n";
}


my $parser ={};
$parser->{TOP} = $TOP;
$parser->{FOR} = $FOR;
$parser->{BOT} = $BOT;
$parser->{nloop} = $#forlines_idx_set+1;
$parser->{CJbang} = \@CJbang;


return $parser;

}




##################################
sub build_reproducible_script{
    ##############################
    my $self = shift;
    my ($runflag) = @_;

my $program_script = CJ::readFile("$self->{path}/$self->{program}");

my $rp_program_script =<<'RP_PRGRAM';

# CJ has its own randState upon calling.
# to reproduce results one needs to set
# the internal State of the global stream
# to the one saved when ruuning the code for
# the fist time;

# Setup environment by loading packages
##################################################################################

# Use function for auto installationation provided by Narasimhan, Balasubramanian
cj_installIfNeeded <- function(packages, ...) {
    toInstall <- setdiff(packages, utils::installed.packages()[, 1])
    if (length(toInstall) > 0) {
        utils::install.packages(pkgs = toInstall,
        repos = "https://cloud.r-project.org",
        ...)
    }
}

load("sessionInfo.Rd")
cj_installIfNeeded(names(r_session_info$otherPkgs))
    
# set random seed to the one that created the results
#################################################################################
load("CJrandState.Rd");
.GlobalEnv$.Random.seed = CJsavedState$CJsavedState
    
RP_PRGRAM

# Figure out R path...
if($runflag =~ /^par.*/){
    # Here we need to change source to direct to
    # upper level dir.
    
$rp_program_script .=<<'SRC'
    cj_orig_source <- function(file,...) {source(file,...)}
    source <- function(file, ...) { cj_orig_source(paste0("../",file), ...)}
SRC
}
    
$rp_program_script .= $program_script ;

my $rp_program = "reproduce_$self->{program}";
CJ::writeFile("$self->{path}/$rp_program", $rp_program_script);
    
}




#######################
sub CJrun_body_script{
    #######################
    my $self = shift;
    my ($ssh) = @_;
    
my $script =<<'BASH';

# load R if there is LMOD installed
if [ $(type -t module)=='function' ]; then
module load <R_MODULE>
echo "loaded module <R_MODULE> "
fi
    
    
R --no-save <<HERE
# ###########################################################################################
# Change the behavior of library() and require() to install automatically if
# Package needed.
cj_orig_library <- function(package,...) {library(package,...)}
cj_orig_require <- function(package,...) {require(package,...)}
    
# Use function for auto installationation provided by Narasimhan, Balasubramanian
cj_installIfNeeded <- function(packages, ...) {
        toInstall <- setdiff(packages, utils::installed.packages()[, 1])
        if (length(toInstall) > 0) {
            utils::install.packages(pkgs = toInstall,
            repos = "https://cloud.r-project.org",
            ...)
        }
}
library <- function(package,...) {cj_installIfNeeded(package,...); cj_orig_library(package,...)}
require <- function(package,...) {cj_installIfNeeded(package,...); cj_orig_require(package,...)}
#############################################################################################
    
    

# make sure each run has different random number stream
mydate = Sys.time();
#sum(100*clock)
seed <- sum(100*c(as.integer(format(mydate,"%Y")), as.integer(format(mydate,"%m")), as.integer(format(mydate,"%d")),
    as.integer(format(mydate,"%H")), as.integer(format(mydate,"%M")),  as.integer(format(mydate,"%S")) ))
    
    
# Set the seed for R
set.seed(seed);
CJsavedState = list("myversion"=version, "mydate"=mydate, 'CJsavedState'= .Random.seed)
fname = "$DIR/CJrandState.Rd";
save(CJrandState,file=fname)

# later use:
# CJsavedState = load("CJrandState.Rd");

setwd("$DIR")
source(${PROGRAM});

# Save session info for loading packages in Reproducible code
r_session_info <- sessionInfo()
save(r_session_info, file="sessionInfo.Rd")
    
HERE

  
BASH


$script =~ s|<R_MODULE>|$ssh->{'r'}|;

return $script;
    
}













































############################
sub uncomment_R_line{
    ########################
    my $self = shift;
    my ($line) = @_;
    # This uncomments useless comment lines.
    $line =~ s/^(?:(?![\"|\']).)*\K\#(.*)//;
    return $line;
}



1;
