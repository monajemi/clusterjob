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
    my ($remote_repo)  = $this_host =~ /Repo[\t\s]*(.*)/ ;$remote_repo =~ s/^\s+|\s+$//g;
    my $account  = $user . "@" . $host;
    
    
    $ssh_config->{'account'} = $account;
    $ssh_config->{'bqs'}     = $bqs;
    $ssh_config->{'remote_repo'}     = $remote_repo;
    
    
    return $ssh_config;
}





sub retrieve_package_info{
    
    my ($package) = @_;
    my $info = {};
    
    my $machine   ;
    my $account   ;
    my $local_prefix;
    my $local_path ;
    my $remote_prefix;
    my $remote_path;
    my $job_id    ;
    my $bqs       ;
    my $save_prefix;
    my $save_path  ;
    my $runflag   ;
    my $program   ;
    my $message   ;
    
    if(! $package eq ""){
    $machine        = `grep -A 14 $package $run_history_file| sed -n '2{p;q;}'` ; chomp($machine);
    $account        = `grep -A 14 $package $run_history_file| sed -n '3{p;q;}'` ; chomp($account);
    $local_prefix   = `grep -A 14 $package $run_history_file| sed -n '4{p;q;}'` ; chomp($local_prefix);
    $local_path      = `grep -A 14 $package $run_history_file| sed -n '5{p;q;}'` ; chomp($local_path);
    $remote_prefix  = `grep -A 14 $package $run_history_file| sed -n '6{p;q;}'` ; chomp($remote_prefix);
    $remote_path     = `grep -A 14 $package $run_history_file| sed -n '7{p;q;}'` ; chomp($remote_path);
    $job_id         = `grep -A 14 $package $run_history_file| sed -n '8{p;q;}'` ; chomp($job_id);
    $bqs            = `grep -A 14 $package $run_history_file| sed -n '9{p;q;}'` ; chomp($bqs);
    $save_prefix    = `grep -A 14 $package $run_history_file| sed -n '10{p;q;}'` ; chomp($save_prefix);
    $save_path       = `grep -A 14 $package $run_history_file| sed -n '11{p;q;}'` ; chomp($save_path);
    $runflag        = `grep -A 14 $package $run_history_file| sed -n '12{p;q;}'` ; chomp($runflag);
    $program        = `grep -A 14 $package $run_history_file| sed -n '13{p;q;}'` ; chomp($program);
    $message        = `grep -A 14 $package $run_history_file| sed -n '14{p;q;}'`; chomp($message);
    
    }else{
    
        $package    =   `sed -n '1{p;q;}' $last_instance_file`;chomp($package);
        $machine    =   `sed -n '2{p;q;}' $last_instance_file`;chomp($machine);
        $account    =   `sed -n '3{p;q;}' $last_instance_file`;chomp($account);
        $local_prefix =  `sed -n '4{p;q;}' $last_instance_file`;chomp($local_prefix);
        $local_path  =   `sed -n '5{p;q;}' $last_instance_file`;chomp($local_path);
        $remote_prefix =`sed -n '6{p;q;}' $last_instance_file`;chomp($remote_prefix);
        $remote_path =   `sed -n '7{p;q;}' $last_instance_file`;chomp($remote_path);
        $job_id     =   `sed -n '8{p;q;}' $last_instance_file`;chomp($job_id);
        $bqs        =   `sed -n '9{p;q;}' $last_instance_file`;chomp($bqs);
        $save_prefix=   `sed -n '10{p;q;}' $last_instance_file`;chomp($save_prefix);
        $save_path   =   `sed -n '11{p;q;}' $last_instance_file`;chomp($save_path);
        $runflag    =   `sed -n '12{p;q;}' $last_instance_file`;chomp($runflag);
        $program    =   `sed -n '13{p;q;}' $last_instance_file`;chomp($program);
        $message    =   `sed -n '14{p;q;}' $last_instance_file`;chomp($message);
        
        
        
    }
    
    $info->{'package'}   = $package;
    $info->{'machine'}   = $machine;
    $info->{'account'}   = $account;
    $info->{'local_prefix'} = $local_prefix;
    $info->{'local_path'} = $local_path;
    $info->{'remote_prefix'}= $remote_prefix;
    $info->{'remote_path'}= $remote_path;
    $info->{'job_id'}    = $job_id;
    $info->{'bqs'}       = $bqs;
    $info->{'save_prefix'}  = $save_prefix;
    $info->{'save_path'}  = $save_path;
    $info->{'runflag'}  = $runflag;
    $info->{'program'}  = $program;
    $info->{'message'}   = $message;
    
    
    
    
    
    return $info;
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

sub warning{
    my ($msg) = @_;
    print(' ' x 5 . "CJwarning::$msg\n");
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