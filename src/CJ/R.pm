package CJ::R;

# This is the R class of CJ 
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu) 

use strict;
use warnings;
use CJ;
use CJ::Install;
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
&CJ::err(" 'parrun' does not allow less than 1 parallel loops inside the MAIN script. Please use 'run'") if ($#forlines_idx_set+1 < 1);

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
    
# Create CJ env
.CJ <- new.env(parent=parent.env(.GlobalEnv))
attr( .CJ , "name" ) <- "CJ_ENV"
parent.env(.GlobalEnv) <- .CJ
    
# Courtesy of Narasimhan, Balasubramanian and Riccardo Murri
# for help with this function
.CJ$installIfNeeded <- function(packages, ...) {
    toInstall <- setdiff(packages, utils::installed.packages()[, 1])
    if (length(toInstall) > 0) {
        utils::install.packages(pkgs = toInstall,
        repos = "https://cloud.r-project.org",
        ...)
    }
}

load("sessionInfo.Rd")
installIfNeeded(names(r_session_info$otherPkgs))
    
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
    .CJ$source <- function(file, ...) { base::source(paste0("../",file), ...)}
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
    my ($ssh, $machine) = @_;
    
# Find R libpath
my $libpath  = &CJ::r_lib_path($ssh);
    
    
my $script =<<BASH;

# load R if there is LMOD installed
if [ \$(type -t module)=='function' ]; then
module load <R_MODULE>
echo "loaded module <R_MODULE> "
fi
    
    
R --no-save <<'HERE'
    
.libPaths("<RLIBPATH>")
# ###########################################################################################
# Change the behavior of library() and require() to install automatically if
# Package needed.

# Create CJ env
.CJ <- new.env(parent=parent.env(.GlobalEnv))
attr( .CJ , "name" ) <- "CJ_ENV"
attr( .CJ , "path" ) <- "<RLIBPATH>"

# Make .CJ the parent of the globalenv to avoid removal of
# .CJ objects by user's rm(list=ls()) function
parent.env(.GlobalEnv) <- .CJ

# Courtesy of Narasimhan, Balasubramanian and Riccardo Murri
# for help with this function
.CJ\\\$installIfNeeded <- function(packages, ...) {
        toInstall <- setdiff(packages, utils::installed.packages()[, 1])
        if (length(toInstall) > 0) {
            utils::install.packages(pkgs = toInstall,
            repos = "https://cloud.r-project.org",
            lib = "<RLIBPATH>",
            ...)
        }
}
.CJ\\\$library <- function(package,...) {package<-as.character(substitute(package));.CJ\\\$installIfNeeded(package,...);base::library(package,...,character.only=TRUE)}
.CJ\\\$require <- function(package,...) {package<-as.character(substitute(package));.CJ\\\$installIfNeeded(package,...);base::require(package,...,character.only=TRUE)}
#############################################################################################
    
    
# make sure each run has different random number stream
mydate = Sys.time();
#sum(100*clock)
seed <- sum(100*c(as.integer(format(mydate,"%Y")), as.integer(format(mydate,"%m")), as.integer(format(mydate,"%d")),
    as.integer(format(mydate,"%H")), as.integer(format(mydate,"%M")),  as.integer(format(mydate,"%S")) ))
    
    
# Set the seed for R
set.seed(seed);
CJsavedState = list("myversion"=version, "mydate"=mydate, 'CJsavedState'= .Random.seed)
fname = "\$DIR/CJrandState.Rd";
save(CJsavedState,file=fname)

# later use:
# CJsavedState = load("CJrandState.Rd");

setwd("\$DIR")

source("\${PROGRAM}");

# Save session info for loading packages later in Reproducible code
r_session_info <- sessionInfo()
save(r_session_info, file="sessionInfo.Rd")
    
HERE

  
BASH


$script =~ s|<R_MODULE>|$ssh->{'r'}|g;
$script =~ s|<RLIBPATH>|$libpath|g;

return $script;
    
}






################################
sub read_R_array_values{
    ################################
    my $self = shift;
    my ($string) = @_;
    
    my $floating_pattern = "[-+]?[0-9]*[\.]?[0-9]+(?:[eE][-+]?[0-9]+)?";
    my $fractional_pattern = "(?:${floating_pattern}\/)?${floating_pattern}";
    my @vals = undef;
    
    #print $string;
    if($string =~ /(.*c\()?[\s,]*(?<!\D)($fractional_pattern)+\s*(\))?/){
        my ($numbers) = $string =~ /(?:.*c\()?\s*(.+)\s*(?:\))?/;
        @vals = $numbers =~ /[\,]?($fractional_pattern)[\,]?/g;
        #print Dumper @vals;
        return \@vals;
    }else{
        return undef;
    }
    
}


#############################################################
# This function is used for parsing the content of _for_ line
# low and high limits of the loop
sub read_R_lohi{
    #############################################################
    my $self  = shift;
    my ($input,$TOP) = @_;
    
    my $lohi = undef;
    
    if( &CJ::isnumeric($input) ) {
        $lohi = $input;
        
    }elsif ($input =~ /\s*length\(\s*(.+)\s*\)/) {
        my $this_line = &CJ::grep_var_line($1,$TOP);
        
        #extract the range
        my @this_array    = split(/\s*=\s*/,$this_line);
        my $vals = $self->read_R_array_values($this_array[1]);  # This reads the vals;
        $lohi = 1+$#{ $vals } unless not defined($vals);
        
    }elsif($input =~ /\s*(\D+)\s*:/){
        # CASE var
        my $this_line = &CJ::grep_var_line($1,$TOP);
        
        #extract the range
        my @this_array    = split(/\s*=\s*/,$this_line);
        my $vals = $self->read_R_array_values($this_array[1]);
        $lohi = $vals->[0];  # This reads a number;
        $lohi = undef if (!&CJ::isnumeric($lohi));
    }
    
    return $lohi;
}






##########################
sub read_R_index_set{
    ##########################
    my $self = shift;
    
    my ($forline, $TOP, $verbose) = @_;
    
    chomp($forline);
    
    my @tags = $forline=~/^\s*for\s*\((\S+)\s*\bin\b\s*(\S+)\)/;
    
    CJ::err("$forline is not a valid R loop") if($#tags+1 ne 2);
    
    
    
    my $idx_tag    = $tags[0];
    # The right of 'in' keyword
    my $right  = $tags[1];
    

    
    
    #c(1,2,10), 1:10, Array, seq_along, seq

    #determine the range
    my $range;
    
    if($right =~ /^\s*(c\(\s*.+\s*\)) )
        #CASE: for (i in c(...) );
        
        my $range = $self->read_R_array_values($1);
        my @range = @{$range};
        $range      = join(',',@range);
    }elsif($right =~ /^[^:]+:[^:]+$/){
        #CASE: for (i in 1:10 );
        my @rightarray = split( /\s*:\s*/, $right, 2 );
        my $low  = $self->read_R_lohi($rightarray[0],$TOP);
        #CJ::remove_white_space($rightarray[1]);
        my $high = $self->read_R_lohi($rightarray[1],$TOP);
        $range      = join(',',($low..$high)) if defined($high);
        
    }elsif($right =~ /^\s*(\w+)\s*:$/){
            #print $1 . "\n";
            my $this_line = &CJ::grep_var_line($1,$TOP);
            #extract the range
            my @this_array    = split(/\s*=\s*/,$this_line);
            my $range = $self->read_R_array_values($this_array[1]);
            my @range = @{$range};
            $range      = join(',',@range);

    }else{
        $range = undef;
    }
        
        
return ($idx_tag, $range);
}




##################################
sub run_python_index_interpreter{
    ##################################
}





#####################
sub findIdxTagRange{
    #####################
    
    my $self = shift;
    my ($parser,$verbose) = @_;
    
    my $FOR = $parser->{FOR};
    my $TOP = $parser->{TOP};
    
    # Determine the tags and ranges of the
    # indecies
    my @idx_tags;
    my $ranges={};  # This is a hashref $range->{tag}
    my @tags_to_R_interpret;
    my @forlines_to_R_interpret;
    
    
    my @forline_list = split /^/, $FOR;
    
    for my $this_forline (@forline_list) {
        
        my ($idx_tag, $range) = $self->read_R_index_set($this_forline, $TOP,$verbose);
        
        
        print $idx_tag;
        die;
        #FIX
        
        CJ::err("Index tag cannot be established for $this_forline") unless ($idx_tag);
        push @idx_tags, $idx_tag;   # This will keep order.
        
        
        
        
        
        if(defined($range)){
            $ranges->{$idx_tag} = $range;
        }else{
            push @tags_to_R_interpret, $idx_tag;
            push @forlines_to_R_interpret, $this_forline;
        }
        
    }
    
    
    
    
    
    
    
    if ( @tags_to_R_interpret ) {
        
        # if we need to run python
        my $range_run_interpret = $self->run_R_index_interpreter($TOP,\@tags_to_R_interpret,\@forlines_to_R_interpret, $verbose);
        
        
        for (keys %$range_run_interpret){
            $ranges->{$_} = $range_run_interpret->{$_};
            #print"$_:$range_run_interpret->{$_} \n";
        }
    }
    
    
    
    return (\@idx_tags,$ranges);
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
