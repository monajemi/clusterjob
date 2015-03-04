package CJ;
# This is part of Clusterjob (CJ)
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)
use strict;
use warnings;
use CJ::CJVars;


sub host{
    my ($machine_name) = @_;
    
    my $ssh_config = {};

    
    
    my $lines;
    open(my $FILE, $ssh_config_file) or  die "could not open $ssh_config_file: $!";
    local $/ = undef;
    $lines = <$FILE>;
    close ($FILE);
    
    my $this_host ;
    if($lines =~ /\[$machine_name\](.*?)\[$machine_name\]/isg)
    {
        $this_host = $1;
    }else{
        &CJ::err(".ssh_config:: Machine $machine_name not found. ")
    }
    my ($user) = $this_host =~ /User[\t\s]*(.*)/;$user =~ s/^\s+|\s+$//g;
    my ($host) = $this_host =~ /Host[\t\s]*(.*)/;$host =~ s/^\s+|\s+$//g;
    my ($bqs)  = $this_host =~ /Bqs[\t\s]*(.*)/ ;$bqs =~ s/^\s+|\s+$//g;
    
    my $account  = $user . "@" . $host;
    
    
    $ssh_config->{'account'} = $account;
    $ssh_config->{'bqs'}     = $bqs;
    
    return $ssh_config;
}


sub date{
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year 	+= 1900;
my @abbr = qw( JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC );
my $date = sprintf ("%04d%03s%02d_%02d%02d%02d", $year, $abbr[$mon], $mday, $hour,$min, $sec);
    return $date;
}

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


sub err{
    my ($message) = @_;
    die(' ' x 5 . "CJerr::$message\n");
}

sub message{
    my ($msg) = @_;
    print(' ' x 5 . "CJmessage::$msg\n");
}


sub my_system
{
    print "system: ",$_[0],"\n";
    system($_[0]);
}



sub touch
{
    &my_system("touch $_[0]");
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