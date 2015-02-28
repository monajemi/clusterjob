package CJ;
# This is part of Clusterjob (CJ)
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)
use strict;
use warnings;
use CJ::CJVars;

# Check the package name given is valid
sub is_valid_package_name
{
my ($name) = @_;
if( $name =~ m/^\d{4}\D{3}\d{2}_\d{6}$/){
return 1;
}else{
return 0;
}
}




# Bash header based on the Batch Queueing System (BQS)
sub bash_header{
    my ($bqs) = @_;

my $HEADER;
if($bqs eq "SGE"){
$HEADER=<<SGE_HEADER;
#!/bin/bash -l
#\$ -cwd
#\$ -S /bin/bash
SGE_HEADER
}elsif($bqs eq "SLURM"){
$HEADER=<<SLURM_HEADER;
#!/bin/bash -l
SLURM_HEADER
}else{
die "unknown BQS"
}
return $HEADER;
}

# Check Numeric
sub isnumeric
{
my ($s) = @_;
if($s =~ /^[0-9,.E]+$/){
return 1;
}else{
return 0;
}

}




sub my_system
{
    print "system: ",$_[0],"\n";
    system($_[0]);
}




sub writeFile
{
    my ($path, $contents) = @_;
    open(FILE,">$path") or die "can't create file $path";
    print FILE $contents;
    close FILE;
}



sub add_to_history
{
    my ($text) = @_;
    # ADD THIS SAVE TO HISTRY
    open (my $FILE , '>>', $history_file) or die("could not open file '$history_file' $!");
    print $FILE "$text\n";
    close $FILE;
    
}



sub add_to_run_history
{
    my ($text) = @_;
    # ADD THIS SAVE TO HISTRY
    open (my $FILE , '>>', $run_history_file) or die("could not open file '$run_history_file' $!");
    print $FILE "$text\n";
    close $FILE;
    
}






1;