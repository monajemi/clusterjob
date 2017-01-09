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
 	my ($path,$program) = @_;
	
	my $self= bless {
		path 	=> $path, 
		program => $program
	}, $class;
		
	return $self;
	
}

