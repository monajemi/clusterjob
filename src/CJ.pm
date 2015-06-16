package CJ;
# This is part of Clusterjob (CJ)
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)
use strict;
use warnings;
use CJ::CJVars;
$::VERSION = 0.0.1;









# ======
# Build master script
sub make_master_script{
    my($master_script,$runflag,$program,$date,$bqs,$mem,$remote_sep_Dir,$counter) = @_;
    
    
    
if( (!defined($master_script)) ||  ($master_script eq "")){
my $docstring=<<DOCSTRING;
# EXPERIMENT $program
# COPYRIGHT 2014:
# Hatef Monajemi (monajemi AT stanford DOT edu)
# DATE : $date
DOCSTRING

my $HEADER = &CJ::bash_header($bqs);
$master_script=$HEADER;
$master_script.="$docstring";
}




    my $programName = &CJ::remove_extention($program);


    if(!($runflag =~ /^par.*/) ){
        
        
        $master_script .= "mkdir ${remote_sep_Dir}"."/logs" . "\n" ;
        $master_script .= "mkdir ${remote_sep_Dir}"."/scripts" . "\n" ;
    
        my $tagstr="$programName\_$date";
        if($bqs eq "SGE"){
            
        $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem -N $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n";
        }elsif($bqs eq "SLURM"){
            
            $master_script.="sbatch --mem=$mem  --time=40:00:00  -J $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n"
            
        }else{
            &CJ::err("unknown BQS")
        }

    
    
    }elsif(defined($counter)){
    
    
    
        # Add QSUB to MASTER SCRIPT
        $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/logs"    . "\n" ;
        $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/scripts" . "\n" ;
        
        
        my $tagstr="$programName\_$date\_$counter";
        if($bqs eq "SGE"){
            $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem -N $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n";
        }elsif($bqs eq "SLURM"){
            
            $master_script.="sbatch --mem=$mem  --time=40:00:00  -J $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n"
            
        }else{
            &CJ::err("unknown BQS");
        }
        
        
    }else{
            &CJ::err("counter is not defined");
    }
    
    
    
}





#=================================================================
#            CLUSTERJOB SAVE (ONLY SAVES THE OUTPUT OF 'GET')
#  ex.  clusterjob save package
#  ex.  clusterjob save package ~/Downloads/myDIR
#=================================================================



sub save_results{
    
    my ($package,$save_path,$verbose) = @_;
    
    
    
    if(! &CJ::is_valid_package_name($package)){
        &CJ::err("Please enter a valid package name");
    }
    
    my $info  = &CJ::retrieve_package_info($package);
    
    
    
    
    
    if( !defined($save_path)){
        # Read the deafult save directory
        $save_path= $info->{'save_path'};
        &CJ::message("Saving results in ${save_path}");
    }
    
    
    
    
    if(-d $save_path){
        # Ask if it needs to be overwritten
        
        CJ::message("Directory $save_path already exists. Do you want to overwrite? Y/N");
        my $yesno =  <STDIN>; chomp($yesno);
        if(lc($yesno) eq "y" or lc($yesno) eq "yes"){
            
            
            my $cmd = "rm -rf $save_path/*";
            &CJ::my_system($cmd,$verbose);
            
            $cmd = "rsync -arz  $get_tmp_dir/$package/ $save_path/";
            &CJ::my_system($cmd,$verbose);
            
        }else{
            
            &CJ::err("Directory $save_path cannot be overwritten!");
            
        }
        
        
    }else{
        
        # Create directories
        my $cmd = "mkdir -p $save_path";
        &CJ::my_system($cmd,$verbose) ;
        
        $cmd = "rsync -arz  $get_tmp_dir/$package/ $save_path/";
        &CJ::my_system($cmd,$verbose);
        
        
    }
    
    
    my $date = &CJ::date();
    # Find the last number
    my $lastnum=`grep "." $history_file | tail -1  | awk \'{print \$1}\' `;
    my ($hist_date, $time) = split('\_', $date);
    my $history = sprintf("%-15u%-15s",$lastnum+1, $hist_date );
    my $flag = "save";
    $history .= sprintf("%-21s%-10s",$package, $flag);
    # ADD THIS SAVE TO HISTRY
    &CJ::add_to_history($history);

    
    exit 0;
}










sub show_history{
    my ($history_argin) = @_;

    # check if it is the name of a package
    # such as 2015JAN07_212840
    
    if( (!defined $history_argin) || ($history_argin eq "") ){
        $history_argin= 1;
    }
    
    if(&CJ::is_valid_package_name($history_argin)){
        # read info from $run_history_file
        
        print '-' x 35;print "\n";
        print "run info, job $history_argin"; print "\n";
        print '-' x 35;print "\n";
        my $cmd= "grep -q '$history_argin' '$run_history_file'";
        my $pattern_exists = system($cmd);
        chomp($pattern_exists);
        
        if ($pattern_exists==0){
            
            my $cmd = "awk '/$history_argin/{f=1}f' $run_history_file | sed -n 1,14p ";
            
            system($cmd);
        }else{
            &CJ::err("No such job found in CJ database");
        }
        
        
        
        
        
        
    }elsif($history_argin =~ m/^\-?\d*$/){
        
        $history_argin =~ s/\D//g;   #remove any non-digit
        my $info=`tail -n  $history_argin $history_file`;chomp($info);
        print "$info \n";
       
    }elsif($history_argin =~ m/^\-?all$/){
        my $info=`cat $history_file`;chomp($info);
        print "$info \n";
    }else{
        &CJ::err("Incorrect usage: nothing to show");
    }
    
    
    
    
    exit 0;


}



sub clean
{
    my ($package, $verbose) = @_;
    
    my $account;
    my $local_path;
    my $remote_path;
    my $job_id;
    my $save_path;
    
    my $info;
    if((!defined $package)  || ($package eq "") ){
        #read the first lines of last_instance.info;
        $info =  &CJ::retrieve_package_info();
        $package = $info->{'package'};
    }else{
        
        if(&CJ::is_valid_package_name($package)){
            # read info from $run_history_file
            
            my $cmd= "grep -q '$package' '$run_history_file'";
            my $pattern_exists = system($cmd);chomp($pattern_exists);
            
            if ($pattern_exists==0){
                $info =  &CJ::retrieve_package_info($package);
                
                # TODO :
                # CHECK TO SEE IF package has already been deleted
                #
                
            }else{
                &CJ::err("No such job found in CJ database.");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
    }
    
    $account     =   $info->{'account'};
    $local_path  =   $info->{'local_path'};
    $remote_path =   $info->{'remote_path'};
    $job_id      =   $info->{'job_id'};
    $save_path   =   $info->{'save_path'};
    
    
    CJ::message("Cleaning $package");
    my $local_clean     = "$local_path\*";
    my $remote_clean    = "$remote_path\*";
    my $save_clean      = "$save_path\*";
    
    
    
    
    if (defined($job_id) && $job_id ne "") {
        CJ::message("Deleting jobs associated with package $package");
        my @job_ids = split(',',$job_id);
        $job_id = join(' ',@job_ids);
        my $cmd = "rm -rf $local_clean; rm -rf $save_clean; ssh ${account} 'qdel $job_id; rm -rf $remote_clean' " ;
        &CJ::my_system($cmd,$verbose);
    }else {
        my $cmd = "rm -rf $local_clean;rm -rf $save_clean; ssh ${account} 'rm -rf $remote_clean' " ;
        &CJ::my_system($cmd,$verbose);
    }
    
    
    
    
    
    my $date = &CJ::date();
    # Find the last number
    my $lastnum=`grep "." $history_file | tail -1  | awk \'{print \$1}\' `;
    my ($hist_date, $time) = split('\_', $date);
    my $history = sprintf("%-15u%-15s",$lastnum+1, $hist_date );
    
    my $flag = "clean";
    # ADD THIS CLEAN TO HISTRY
    $history .= sprintf("%-21s%-10s",$package, $flag);
    &CJ::add_to_history($history);
    
    
    exit 0;

}







sub show_program
{
    my ($package) = @_;
    
    
    my $info;
    if( (!defined $package) || ($package eq "") ){
        #read the first lines of last_instance.info;
        $info = &CJ::retrieve_package_info();
        $package = $info->{'package'};
        
    }else{
        
        if( &CJ::is_valid_package_name($package) ){
            # read info from $run_history_file
            
            my $cmd= "grep -q '$package' '$run_history_file'";
            my $pattern_exists = system($cmd);chomp($pattern_exists);
            
            if ($pattern_exists==0){
                $info = &CJ::retrieve_package_info($package);
                
            }else{
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }
    
    
    
    my $account     = $info->{'account'};
    my $remote_path = $info->{'remote_path'};
    my $program     = $info->{'program'};
    
    my $script = (`ssh ${account} 'cat $remote_path/$program'`) ;chomp($script);
    
    print "$script \n";
    exit 0;
    
}












sub show_info
{
    my ($package) = @_;
   
    
    my $info;
    if( (!defined $package) || ($package eq "") ){
        #read the first lines of last_instance.info;
        $info = &CJ::retrieve_package_info();
        $package = $info->{'package'};
        
    }else{
        
        if( &CJ::is_valid_package_name($package) ){
            # read info from $run_history_file
            
            my $cmd= "grep -q '$package' '$run_history_file'";
            my $pattern_exists = system($cmd);chomp($pattern_exists);
            
            if ($pattern_exists==0){
                $info = &CJ::retrieve_package_info($package);
                
            }else{
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }

    
    
    
    
    my $machine    = $info->{'machine'};
    my $account    = $info->{'account'};
    my $remote_path = $info->{'remote_path'};
    my $runflag    = $info->{'runflag'};
    my $bqs        = $info->{'bqs'};
    my $job_id     = $info->{'job_id'};
    my $program    = $info->{'program'};

    
    print '-' x 35;print "\n";
    print "PACKAGE: " . "$package" . "\n";
    print "PROGRAM: " . "$program" . "\n";
    print "ACCOUNT: " . "$account" . "\n";
    print "PATH   : " . "$remote_path" . "\n";
    print "FLAG   : " . "$runflag"  . "\n";
    print '-' x 35;print "\n";

    
    
    
    exit 0;

}




















sub get_state
{
    my ($package) = @_;
    
    
    my $info;
    if( (!defined $package) || ($package eq "") ){
        #read the first lines of last_instance.info;
        $info = &CJ::retrieve_package_info();
        $package = $info->{'package'};
        
    }else{
        
        if( &CJ::is_valid_package_name($package) ){
            # read info from $run_history_file
            
            my $cmd= "grep -q '$package' '$run_history_file'";
            my $pattern_exists = system($cmd);chomp($pattern_exists);
            
            if ($pattern_exists==0){
                $info = &CJ::retrieve_package_info($package);
                
            }else{
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }
    
    
    my $account = $info->{'account'};
    my $job_id  = $info->{'job_id'};
    my $bqs     = $info->{'bqs'};
    my $runflag = $info->{'runflag'};
    
    
    
    if($runflag =~ m/^par*/){
        my $num = shift;
        
        # par case
        my @job_ids = split(',',$job_id);
        my $jobs = join('|', @job_ids);
        my $states;
        if($bqs eq "SGE"){
            $states = (`ssh ${account} 'qstat -u \\* | grep -E "$jobs" ' | awk \'{print \$5}\'`) ;chomp($states);
        }elsif($bqs eq "SLURM"){
            $states = (`ssh ${account} 'sacct -n --jobs=$job_id | grep -v "^[0-9]*\\." ' | awk \'{print \$6}\'`) ;chomp($states);
            #$states = (`ssh ${account} 'sacct -n --format=state --jobs=$job_id'`) ;chomp($state);
            
        }else{
            &CJ::err("Unknown batch queueing system");
        }
        
        my @states = split('\n',$states);
        
        
        if($num eq ""){
            print '-' x 50;print "\n";
            print "PACKAGE " . "$package" . "\n";
            print "CLUSTER " . "$account" . "\n";
            foreach my $i (0..$#job_ids)
            {
                my $counter = $i+1;
                my $state= $states[$i]; chomp($state);
                #$state = s/^\s+|\s+$/;
                $state =~ s/[^A-Za-z]//g;
                print "$counter     " . "$job_ids[$i]      "  . "$state" . "\n";
            }
        }elsif(&CJ::isnumeric($num) && $num < $#job_ids+1){
            print '-' x 50;print "\n";
            print "PACKAGE " . "$package" . "\n";
            print "CLUSTER " . "$account" . "\n";
            print "$num     " . "$job_ids[$num]      "  . "$states[$num]" . "\n";
        }else{
            &CJ::err("incorrect entry. Input $num >= $#states.")
        }
        
        print '-' x 35;print "\n";
        
    }else{
        my $state;
        if($bqs eq "SGE"){
            $state = (`ssh ${account} 'qstat | grep $job_id' | awk \'{print \$5}\'`) ;chomp($state);
        }elsif($bqs eq "SLURM"){
            $state = (`ssh ${account} 'sacct | grep $job_id | grep -v "^[0-9]*\\." ' | awk \'{print \$6}\'`) ;chomp($state);
        }else{
            &CJ::err("Unknown batch queueing system");
        }
        
        print '-' x 35;print "\n";
        print "PACKAGE " . "$package" . "\n";
        print "CLUSTER " . "$account" . "\n";
        print "JOB_ID  " . "$job_id"  . "\n";
        print "STATE   " . "$state"   . "\n";
        print '-' x 35;print "\n";
    }
    
    
    
    exit 0;

    
    
    
    

}





sub grep_var_line
{
    my ($pattern, $string) = @_;
    
    # go to $TOP and look for the length of the found var;
    my $this_line;
    my @lines = split /\n/, $string;
    foreach my $line (@lines) {
        if($line =~ /\s*(?<!\%)${pattern}\s*=.*/){
            $this_line = $line;
            last;
        }
    }
    if($this_line){
        return $this_line;
    }else{
        &CJ::err("Variable '$pattern' was not declared.\n");
    }
}







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
    
if(!defined($name)){
$name = ""
}
    
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
   my($cmd,$verbose) = @_;
    if($verbose){
        print("system: ",$cmd,"\n");
        system("$cmd");
        
    }else{
        system("$cmd >> $CJlog  2>&1") ;#Error messages get sent to same place as standard output.
    }

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

sub readFile
{
    my ($filepath)  = @_;

    my $content;
    open(my $fh, '<', $filepath) or die "cannot open file $filepath";
    {
    local $/;
    $content = <$fh>;
    }
    close($fh);
    
    return $content;
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


sub remove_extention
{
    my ($program) = @_;
    
    my @program_name    = split /\./,$program;
    my $lastone = pop @program_name;
    my $program_name   =   join "\_",@program_name;  # NOTE: Dots in the name are replace by \_

    return $program_name;
    
}



1;