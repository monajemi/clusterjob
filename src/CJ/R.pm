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



sub build_reproducible_script{
	
	my $self = shift;
    my ($runflag) = @_;
	#TODO: add dependecies like CVX, etc.

my $program_script = CJ::readFile("$self->{path}/$self->{program}");
	
my $rp_program_script =<<RP_PRGRAM;

% CJ generates its own random state upon calling.
% to reproduce results, we set
% the internal State of the global stream
% to the one saved by CJ;
    
load('CJrandState.mat');
globalStream = RandStream.getGlobalStream;
globalStream.State = CJsavedState;
RP_PRGRAM
  
if($runflag =~ /^par.*/){
$rp_program_script .= "addpath(genpath('../.'));\n";
}else{
$rp_program_script .= "addpath(genpath('.'));\n";
}

$rp_program_script .= $program_script ;
    
my $rp_program = "reproduce_$self->{program}";
CJ::writeFile("$self->{path}/$rp_program", $rp_program_script);


}





1;