package CJ;
# This is part of Clusterjob (CJ)
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)
use strict;
use warnings;
use CJ::CJVars;

sub version_info{
my $version_script="\n\n          This is Clusterjob (CJ) verion 1.1.0";
$version_script .=  "\n          Copyright (c) 2015 Hatef Monajemi (monajemi\@stanford.edu)";
$version_script .="\n\n          CJ may be copied only under the terms and conditions of";
$version_script .=  "\n          the GNU General Public License, which may be found in the CJ";
$version_script .=  "\n          source code. For more info please visit";
$version_script .=  "\n          https://github.com/monajemi/clusterjob";
    return $version_script ;
}






sub rerun
{
    my ($package,$counter,$mem,$runtime,$qsub_extra,$verbose) = @_;
   
    my $info;
    if( (!defined $package) || ($package eq "") ){
        #read last_instance.info;
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
    my $runflag = $info->{'runflag'};
    my $program = $info->{'program'};
    my $job_id = $info->{'job_id'};
    my $bqs = $info->{'bqs'};

    #my $programName = &CJ::remove_extention($program);
    
    my @job_ids = split(',',$job_id);


    
    my $date = &CJ::date();
    my $master_script;
    if ($#job_ids eq 0) { # if there is only one job
        #run
        $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$bqs,$mem,$runtime,$remote_path,$qsub_extra);
    }else{
        #parrun
        if(@$counter){
            foreach my $count (@$counter){
                $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$bqs,$mem,$runtime,$remote_path,$qsub_extra,$count);
            }
        }else{
            # Package is parrun, run the whole again!
            foreach my $i (0..$#job_ids){
               $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$bqs,$mem,$runtime,$remote_path,$qsub_extra,$i);
            }
        }
    }


    

#===================================
# write out developed rerun master script
#===================================
my $local_master_path="/tmp/rerun_master.sh";
&CJ::writeFile($local_master_path, $master_script);

    
#==============================================
# Send master script over to the server, run it
#==============================================

&CJ::message("Sending rerun script over to the $account");
my $cmd = "rsync -arvz  $local_master_path ${account}:$remote_path/";
&CJ::my_system($cmd,$verbose);
    
    
&CJ::message("Submitting job(s)");
$cmd = "ssh $account 'source ~/.bashrc;cd $remote_path; bash -l rerun_master.sh > $remote_path/rerun_qsub.info; sleep 2'";
&CJ::my_system($cmd,$verbose);
    
    
    
# bring the log file
my $qsubfilepath="$remote_path/rerun_qsub.info";
$cmd = "rsync -avz $account:$qsubfilepath  $install_dir/";
&CJ::my_system($cmd,$verbose);

die;
    


#=======================================
# write changes to the run_history file
#=======================================
  # - replace the old job_id's by new one
  # - Keep track of the old id in the rerun section
  #  <Rerun>  .... </Rerun>

exit 0;
}




















# This is the CJ confirmation included in the
# reproducible package
sub build_cj_confirmation{
    my ($package, $path) = @_;
    
    my $info = retrieve_package_info($package);
    my $program = $info->{'program'};
    
    my $version_script = &CJ::version_info() ;
my $confirmation_script =<<CONFIRM;
$version_script
------------------------------------------------------------
This reproducible package is generated using Clusterjob (CJ)
    on $info->{'date'}->{'month'} $info->{'date'}->{'day'}, $info->{'date'}->{'year'} at $info->{'date'}->{'hour'}:$info->{'date'}->{'min'}:$info->{'date'}->{'sec'}. To reproduce the results,
please rerun
    "reproduce_$program"

The following is the job discription:

PACKAGE     = $info->{'package'}
PROGRAM     = $info->{'program'}
LOCAL_PATH  = $info->{'local_path'}
MACHINE     = $info->{'machine'}
ACCOUNT     = $info->{'account'}
RUNFLAG     = $info->{'runflag'}
BQS         = $info->{'bqs'}
REMOTE_PATH = $info->{'remote_path'}
JOB_ID      = $info->{'job_id'};

------------------------------------------------------------
    
CONFIRM

CJ::writeFile("$path/CJ_CONFIRMATION.TXT", $confirmation_script);
my $cmd = "chmod +x $path/CJ_CONFIRMATION.TXT";
&CJ::my_system($cmd,0);
}

# ======
# Build master script
sub make_master_script{
    my($master_script,$runflag,$program,$date,$bqs,$mem, $runtime, $remote_sep_Dir,$qsub_extra,$counter) = @_;
    
    
    
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
    
        my $tagstr="CJ$date\_$programName";
        if($bqs eq "SGE"){
            
        $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem -l h_rt=$runtime $qsub_extra -N $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n";
        }elsif($bqs eq "SLURM"){
            
            $master_script.="sbatch --mem=$mem --time=$runtime $qsub_extra -J $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n"
            
        }else{
            &CJ::err("unknown BQS")
        }

    
    
    }elsif(defined($counter)){
    
    
    
        # Add QSUB to MASTER SCRIPT
        $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/logs"    . "\n" ;
        $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/scripts" . "\n" ;
        
        
        my $tagstr="CJ$date\_$counter\_$programName";
        if($bqs eq "SGE"){
            $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem  -l h_rt=$runtime $qsub_extra -N $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n";
        }elsif($bqs eq "SLURM"){
            
            $master_script.="sbatch --mem=$mem --time=$runtime $qsub_extra -J $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n"
            
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
    
    
    
    
    if(-d "$save_path/$package"){
        # Ask if it needs to be overwritten
        
        CJ::message("Directory $save_path already exists. Do you want to overwrite? Y/N");
        my $yesno =  <STDIN>; chomp($yesno);
        if(lc($yesno) eq "y" or lc($yesno) eq "yes"){
            
            my $cmd = "rm -rf $save_path/$package/*";
            &CJ::my_system($cmd,$verbose);
            
            $cmd = "rsync -arz  $get_tmp_dir/$package/ $save_path/$package/";
            &CJ::my_system($cmd,$verbose);
            
        }else{
            
            &CJ::err("Directory $save_path cannot be overwritten!");
            
        }
        
        
    }else{
        
        # Create directories
        my $cmd = "mkdir -p $save_path/$package";
        &CJ::my_system($cmd,$verbose) ;
        
        $cmd = "rsync -arz  $get_tmp_dir/$package/ $save_path/$package/";
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
    
    if(defined($info->{'clean'}->{'date'})){
        CJ::message("Nothing to clean. Package $package has been cleaned on $info->{'clean'}->{'date'} at $info->{'clean'}->{'time'}.");
        exit 0;
    }
    
    
    
    
    
    # make sure s/he really want a deletion
    CJ::message("Are you sure you would like to clean $package? Y/N");
    my $yesno =  <STDIN>; chomp($yesno);
    
    if(lc($yesno) eq "y" or lc($yesno) eq "yes"){
    
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
        
        
    my @time_array = ( $time =~ m/../g );
    $time = join(":",@time_array);
    # Add the change to run_history file
my $text =<<TEXT;
\<Clean\>
    DATE -> $hist_date
    TIME -> $time
\<\/Clean\>
TEXT
&CJ::add_change_to_run_history($package, $text);
        
}
    
    exit 0;

}







sub show
{
    my ($package, $num, $show_tag) = @_;
    
    
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
    
    
    if(defined($info->{'clean'}->{'date'})){
        CJ::message("Nothing to clean. Package $package has been cleaned on $info->{'clean'}->{'date'} at $info->{'clean'}->{'time'}.");
        exit 0;
    }
   
    my $account     = $info->{'account'};
    my $remote_path = $info->{'remote_path'};
    my $runflag     = $info->{'runflag'};
    
    
    my $script;
    if($show_tag eq "program" ){
    my $program     = $info->{'program'};
        if($num){
          $script = (`ssh ${account} 'cat $remote_path/$num/$program'`) ;chomp($script);
        }else{
          $script = (`ssh ${account} 'cat $remote_path/$program'`) ;chomp($script);
        }
    }elsif($show_tag eq "error" ){
         if($num){
           $script = (`ssh ${account} 'cat $remote_path/$num/logs/*stderr'`) ;chomp($script);
         }else{
           $script = (`ssh ${account} 'cat $remote_path/logs/*stderr'`) ;chomp($script);
         }
        
    }elsif($show_tag eq "ls" ){
        if($num){
            $script = (`ssh ${account} 'ls -C1 $remote_path/$num/'`) ;chomp($script);
        }else{
            $script = (`ssh ${account} 'ls -C1 $remote_path/'`) ;chomp($script);
        }
    }
        
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

    my $cleanflag;
    if(defined($info->{'clean'}->{'date'})){
    $cleanflag = ",cleaned($info->{'clean'}->{'date'} at $info->{'clean'}->{'time'})";
    }
    
    print '-' x 35;print "\n";
    print "PACKAGE: " . "$package" . "\n";
    print "PROGRAM: " . "$program" . "\n";
    print "ACCOUNT: " . "$account" . "\n";
    print "PATH   : " . "$remote_path" . "\n";
    print "FLAGS   : " . "$runflag"  . "$cleanflag" . "\n";
    print '-' x 35;print "\n";

    
    
    
    exit 0;

}




















sub get_state
{
    my ($package,$num) = @_;
    
    
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
        
        # par case
        my @job_ids = split(',',$job_id);
        my $jobs = join('|', @job_ids);
      
        
        my $REC_STATES;
        my $REC_IDS;
        if($bqs eq "SGE"){
            $REC_STATES = (`ssh ${account} 'qstat -u \\* | grep -E "$jobs" ' | awk \'{print \$5}\'`) ;chomp($REC_STATES);
            $REC_IDS = (`ssh ${account} 'qstat -u \\* | grep -E "$jobs" ' | awk \'{print \$1}\'`) ;chomp($REC_IDS);
            
        }elsif($bqs eq "SLURM"){
            $REC_STATES = (`ssh ${account} 'sacct -n --jobs=$job_id | grep -v "^[0-9]*\\." ' | awk \'{print \$6}\'`) ;chomp($REC_STATES);
            $REC_IDS =  (`ssh ${account} 'sacct -n --jobs=$job_id | grep -v "^[0-9]*\\." ' | awk \'{print \$1}\'`) ;chomp($REC_IDS);
            
            #$states = (`ssh ${account} 'sacct -n --format=state --jobs=$job_id'`) ;chomp($state);
            
        }else{
            &CJ::err("Unknown batch queueing system");
        }
        
        my @rec_states = split('\n',$REC_STATES);
        my @rec_ids = split('\n',$REC_IDS);

        
        my $states={};
        foreach my $i (0..$#rec_ids){
            my $key = $rec_ids[$i];
            my $val = $rec_states[$i];
            $states->{$key} = $val;
        }
            

        if((!defined $num) || ($num eq "")){
            print '-' x 50;print "\n";
            print "PACKAGE " . "$package" . "\n";
            print "CLUSTER " . "$account" . "\n";
            foreach my $i (0..$#job_ids)
            {
                my $counter = $i+1;
                my $state;
                if($states->{$job_ids[$i]}){
                $state= $states->{$job_ids[$i]}; chomp($state);
                }else{
                $state = "Unknown";
                }
                #$state = s/^\s+|\s+$/;
                $state =~ s/[^A-Za-z]//g;
                print "$counter     " . "$job_ids[$i]      "  . "$state" . "\n";
            }
        }elsif(&CJ::isnumeric($num) && $num < $#job_ids+1){
            print '-' x 50;print "\n";
            print "PACKAGE " . "$package" . "\n";
            print "CLUSTER " . "$account" . "\n";
            my $tmp = $num -1;
            my $val = $states->{$job_ids[$tmp]};
            if (! $val){
            $val = "unknwon";
            }
            print "$num     " . "$job_ids[$tmp]      "  . "$val" . "\n";
            
            
        }else{
            &CJ::err("incorrect entry. Input $num >= $#job_ids.")
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
        if($line =~ /^\s*(?<!\%)${pattern}\s*=.*/){
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
    my ($remote_matlabpath)  = $this_host =~ /MATlib[\t\s]*(.*)/;$remote_repo =~ s/^\s+|\s+$//g;
    my $account  = $user . "@" . $host;
    
    
    $ssh_config->{'account'}         = $account;
    $ssh_config->{'bqs'}             = $bqs;
    $ssh_config->{'remote_repo'}     = $remote_repo;
    $ssh_config->{'matlib'}          = $remote_matlabpath;
    
    return $ssh_config;
}





sub retrieve_package_info{
    
    my ($package) = @_;
    
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
    
    if(!$package){
        $package    =   `sed -n '1{p;q;}' $last_instance_file`;chomp($package);
    }

    $machine        = `grep -A 14 $package $run_history_file| sed -n '2{p;q;}'` ; chomp($machine);
    $account        = `grep -A 14 $package $run_history_file| sed -n '3{p;q;}'` ; chomp($account);
    $local_prefix   = `grep -A 14 $package $run_history_file| sed -n '4{p;q;}'` ; chomp($local_prefix);
    $local_path     = `grep -A 14 $package $run_history_file| sed -n '5{p;q;}'` ; chomp($local_path);
    $remote_prefix  = `grep -A 14 $package $run_history_file| sed -n '6{p;q;}'` ; chomp($remote_prefix);
    $remote_path    = `grep -A 14 $package $run_history_file| sed -n '7{p;q;}'` ; chomp($remote_path);
    $job_id         = `grep -A 14 $package $run_history_file| sed -n '8{p;q;}'` ; chomp($job_id);
    $bqs            = `grep -A 14 $package $run_history_file| sed -n '9{p;q;}'` ; chomp($bqs);
    $save_prefix    = `grep -A 14 $package $run_history_file| sed -n '10{p;q;}'` ; chomp($save_prefix);
    $save_path      = `grep -A 14 $package $run_history_file| sed -n '11{p;q;}'` ; chomp($save_path);
    $runflag        = `grep -A 14 $package $run_history_file| sed -n '12{p;q;}'` ; chomp($runflag);
    $program        = `grep -A 14 $package $run_history_file| sed -n '13{p;q;}'` ; chomp($program);
    $message        = `grep -A 14 $package $run_history_file| sed -n '14{p;q;}'` ; chomp($message);
    
    
    ($package) = $package =~ m/^(?:\[?)(\d{4}\D{3}\d{2}_\d{6})(?:\]?)$/g;
    my $info = {};
    $info->{'package'}  = $package;
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
    ######## Original run date info
   
    my @datearray = ( $package =~ m/^(\d{4})(\D{3})(\d{2})_(\d{2})(\d{2})(\d{2})$/g );
    $info->{'date'} = {
        year    => $datearray[0],
        month   => $datearray[1],
        day     => $datearray[2],
        hour    => $datearray[3],
        min     => $datearray[4],
        sec     => $datearray[5],
    };
    
    ######Clean info
    
    my $CLEANDATE = undef;
    my $CLEANTIME = undef;
    

    # find the related package
    my $PKG_START = "\\[$package\\]";
    my $PKG_END   = "\\[\\/$package\\]";
    my $THIS_RECORD = `awk \'/$PKG_START/{flag=1;next}/$PKG_END/{flag=0}flag\' $run_history_file`;
    $THIS_RECORD =~ s/\n//g;
    
    my $CLEAN_START = "\<Clean\>";
    my $CLEAN_END = "\<\/Clean\>";
    if ($THIS_RECORD  =~ /$CLEAN_START(.*?)$CLEAN_END/) {
        my $result = $1;
        # do something with results
        ($CLEANDATE) = $result =~ m/DATE.*?(\d{4}\D{3}\d{2})/;
        ($CLEANTIME) = $result =~ m/TIME.*?(\d{2}:\d{2}:\d{2})/;
    }
   
    $info->{'clean'} = {
                date    => $CLEANDATE,
                time  => $CLEANTIME,
    };

    #print "$info->{'clean'}->{'date'}\n";
    #print "$info->{'clean'}->{'time'}\n";



    
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
    
    # it should generate a bak up later!
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
    my ($runinfo) = @_;
my $text=<<TEXT;
\[$runinfo->{'package'}\]
$runinfo->{machine}
$runinfo->{account}
$runinfo->{local_prefix}
$runinfo->{local_path}
$runinfo->{remote_prefix}
$runinfo->{remote_path}
$runinfo->{job_id}
$runinfo->{bqs}
$runinfo->{save_prefix}
$runinfo->{save_path}
$runinfo->{runflag}
$runinfo->{program}
$runinfo->{message}
\[\/$runinfo->{'package'}\]
TEXT

    
    
    # ADD THIS SAVE TO HISTRY
    open (my $FILE , '>>', $run_history_file) or die("could not open file '$run_history_file' $!");
    print $FILE "$text\n";
    close $FILE;
    
}



sub add_change_to_run_history
{
    my ($package, $text) = @_;
    
    
    # find the related package
    my $START = "\\[$package\\]";
    my $END   = "\\[\\/$package\\]";
    
    
    my $TOP  = `awk \'1;/$START/{exit}\' $run_history_file`;
    my $THIS = `awk \'/$START/{flag=1;next}/$END/{flag=0}flag\' $run_history_file`;
    my $BOT  = `awk \'/$END/,0\' $run_history_file`;
   
my $contents="$TOP"."$THIS"."$text"."$BOT";
    
&CJ::writeFile($run_history_file, $contents)
    
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