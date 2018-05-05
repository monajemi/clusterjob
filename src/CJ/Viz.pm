package CJ::Viz;

use strict;
use warnings;
use CJ;
use CJ::CJVars;
use Data::Dumper;


# This is a class that takes care of visualization
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)
# May 04 2018

# class constructor
sub new {
 	my $class= shift;
 	my ($file_type, $viz_type, $doc_type) = @_;
	
	my $self= bless {
		file_type => $file_type,
        viz_type =>  $viz_type,
        doc_type =>  $doc_type
	}, $class;
		
	return $self;
}



sub start {
    my $self = shift;
    my $url = $src_dir . "/external/D3/" . $self->{'viz_type'} . ".html";
    &CJ::Viz::open_default_browser($url)
}


sub open_default_browser {
    my $url = shift;
    my $platform = $^O;
    my $cmd;
    if    ($platform eq 'darwin')  { $cmd = "open \"$url\"";          } # Mac OS X
    elsif ($platform eq 'linux')   { $cmd = "xdg-open \"$url\"";      } # Linux
    elsif ($platform eq 'MSWin32') { $cmd = "start $url";             } # Win95..Win7
    if (defined $cmd) {
        system($cmd);
    } else {
        CJ::err("Can't locate default browser");
    }
    
}













1;
