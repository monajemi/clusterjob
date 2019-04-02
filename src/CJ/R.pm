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

# This includes fors on one line
my @lines = split('\n|\{\K\s*(?=for)', $script_lines);


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
    
    if( $string =~ /(.*c\()?[,\s]*(?<![\w|:])($fractional_pattern)+(?![\w|:])\s*(\))?/  ){
        
        my ($numbers) = $string =~ /(?:.*c\()?\s*(.+)\s*(?:\))?/;
        
        @vals = $numbers =~ /[\,]?($fractional_pattern)[\,]?/g;
        #print Dumper @vals;
        return \@vals;
        
        
    }elsif($string =~ /^[^:]+:[^:]+$/){
    
        my @array = split( /\s*:\s*/, $string, 2 );
        my $low  = &CJ::isnumeric($array[0]) ? $array[0]:undef ;
        my $high = &CJ::isnumeric($array[1]) ? $array[1]:undef ;
        @vals    = ($low..$high) if (defined($low) && defined($high));
        
        #print Dumper(@vals) ."\n";
        
        return \@vals;

    }else{
        #print "its here\n";
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
        
    }elsif($input =~ /\s*(\D+)\s*/){
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
    
    if( $right =~ /^\s*(c\(\s*.+\s*\))/ ){
        #CASE: for (i in c(...) );
        
        #print $1 . "\n";
        my $vals = $self->read_R_array_values($1);
        my @vals = @{$vals};
        $range      = join(',',@vals);
        
    }elsif($right =~ /^[^:]+:[^:]+$/){
        #CASE: for (i in 1:10 );
        my @rightarray = split( /\s*:\s*/, $right, 2 );
        my $low  = $self->read_R_lohi($rightarray[0],$TOP);

        #CJ::remove_white_space($rightarray[1]);
        my $high = $self->read_R_lohi($rightarray[1],$TOP);

        $range      = join(',',($low..$high)) if defined($high);
    }elsif($right =~ /^\s*(\w+)\s*$/){

            #CASE: for (i in RANGE );
            my $this_line = &CJ::grep_var_line($1,$TOP);
            #extract the range
            my @this_array    = split(/\s*=\s*/,$this_line);
            my $arr = $this_array[1];
            $arr =~  s/;$//g;
            my $vals = $self->read_R_array_values($arr);
            my @vals = @{$vals};
        
            $range      = join(',',@vals);

    }else{
        $range = undef;
    }
        
        
return ($idx_tag, $range);
}




##################################
sub run_R_index_interpreter{
    ##############################
        my $self = shift;
        my ($TOP,$tag_list,$for_lines,$verbose) = @_;
        
        &CJ::message("Invoking R to find range of indices. Please be patient...");
        
        
        # Check that the local machine has R (we currently build package locally!)
        # Open R and eval
        
        my $test_name= "/tmp/CJ_R_test";
        my $test_file = "\'$test_name\'";
        
my $R_check_script = <<R_CHECK;
test_fid <-file($test_file)
writeLines('test_passed', test_fid)
close(test_fid)
R_CHECK
    
my $check_path = "/tmp";
my $check_name= "CJ_R_check_script.R";
my $check_file="$check_path/$check_name";
&CJ::writeFile($check_file,$R_check_script);
        
my $junk = "/tmp/CJ_R.output";
        
my $R_check_bash = <<CHECK_BASH;
#!/bin/bash -l
Rscript '$check_file'  &>$junk;
CHECK_BASH
        
        
        
&CJ::message("Checking command 'R' is available...",1);
    
    
# this will generate a file test_file
CJ::my_system("[ -f \"~/.bash_profile\" ] && . \"~/.bash_profile\"; [ -f \"~/.bashrc\" ] && . ~/.bashrc ; printf '%s' $R_check_bash",$verbose);
    
eval{
my $check = &CJ::readFile($test_name);     # this causes error if there is no file which indicates R were not found.
#print $check . "\n";
};
        
if($@){
    #print $@ . "\n";
    &CJ::err("CJ requires 'R' but it cannot access it on your local machine. Check 'R' command.");
}else{
    &CJ::message("R available.",1);
};

    
# build a script from top to output the range of index
    
my $R_interpreter_script=<<LIB;
    
# ###########################################################################################
# Change the behavior of library() and require() to install automatically if
# Package needed.

# Create CJ env
.CJ <- new.env(parent=parent.env(.GlobalEnv))
attr( .CJ , "name" ) <- "CJ_ENV"

# Make .CJ the parent of the globalenv to avoid removal of
# .CJ objects by user's rm(list=ls()) function
parent.env(.GlobalEnv) <- .CJ

# Courtesy of Narasimhan, Balasubramanian and Riccardo Murri
# for help with this function
.CJ\$installIfNeeded <- function(packages, ...) {
    toInstall <- setdiff(packages, utils::installed.packages()[, 1])
    if (length(toInstall) > 0) {
        utils::install.packages(pkgs = toInstall,
        repos = "https://cloud.r-project.org",
        ...)
    }
}
.CJ\$library <- function(package,...) {package<-as.character(substitute(package));.CJ\$installIfNeeded(package,...);base::library(package,...,character.only=TRUE)}
.CJ\$require <- function(package,...) {package<-as.character(substitute(package));.CJ\$installIfNeeded(package,...);base::require(package,...,character.only=TRUE)}
# ############################################################################################
    
    
LIB
    
 
    
# Add top
$R_interpreter_script.=$TOP;

# Add for lines
my $tagfiles={};
foreach my $i (0..$#{$for_lines}){
    my $tag = $tag_list->[$i];
    my $hex = join('', map { sprintf "%X", rand(16) } 1..10);

    my $forline = $for_lines->[$i];
    
    # print  "$tag:$hex: $forline\n";
    
    $tagfiles->{$tag} = "/tmp/${tag}\_${hex}\.tmp";
    
$R_interpreter_script .=<<RSCRIPT
$tag\_fid = file("$tagfiles->{$tag}");
$forline
write(sprintf(\'%i\', $tag),file="$tagfiles->{$tag}",append=TRUE)
\}
close($tag\_fid);
RSCRIPT
}


my $name = "CJ_R_interpreter_script.R";
&CJ::writeFile("$self->{path}/${name}",$R_interpreter_script);


my $R_interpreter_bash = <<BASH;
#!/bin/bash -l

[[ -f "\$HOME/.bash_profile" ]] && source "\$HOME/.bash_profile"
[[ -f "\$HOME/.bashrc" ]] && source "\$HOME/.bashrc"
[[ -f "\$HOME/.profile" ]] && source "\$HOME/.profile"


# dump everything user-generated from top in /tmp
cd $self->{'path'}
R --no-save <<HERE &>$junk;
.libPaths('$self->{path}/$self->{dep_folder}');
source('$name')
HERE
BASH


&CJ::message("finding range of indices...",1);
my $range=&CJ::read_idx_range_from_script($R_interpreter_bash, $tag_list, $tagfiles, $name, $junk, $verbose);

&CJ::message("Closing R session!",1);

# remove the files you made in /tmp
&CJ::my_system("rm -f $test_name $junk $check_path/$check_name $self->{path}/$name $self->{path}/${name}.bak");

print Dumper $range;
return $range;

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

        CJ::err("Index tag cannot be established for $this_forline") unless ($idx_tag);
        push @idx_tags, $idx_tag;   # This will keep order.
        
        
        if(defined($range)){
            $ranges->{$idx_tag} = $range;
        }else{
            push @tags_to_R_interpret, $idx_tag;
            push @forlines_to_R_interpret, $this_forline;
        }
        
    }
    
    
    ########### EDITED TILL INTERPRET
    
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
