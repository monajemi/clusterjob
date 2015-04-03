#!/usr/bin/perl
#
# run the specified code on a cluster
# Usage:
# perl clusterjob.pl (DEPLOY|RUN) MACHINE PROGRAM
# perl clusterjob.pl (DEPLOY|RUN) MACHINE PROGRAM DEP_FOLDER
#
# Options:
#   -mem <MEMORY_REQUESTED>
#   -m   <MESSAGE>
#   -dep <DEP_FOLDER>
# ex: perl CJ.pl (DEPLOY|RUN) MACHINE PROGRAM DEP_FOLDER -mem "10G" -m "REMINDER"
#
# In practice, one can leave 'perl clusterjob.pl'
# as an alias, say 'clusterjob'.
#
# in '~.profile' or '~/.bashrc' write:
# alias clusterjob='perl /path/to/clusterjob.pl';
#
# and then run
# clusterjob  (DEPLOY|RUN) MACHINE PROGRAM DEP_FOLDER -mem MEMORY_REQUESTED -m "message"
#
# To get the results of the last instance back to your machine
#   clusterjob get
#
# To save the results of the last instance on your machine
#   clusterjob save
#
# To show the history of the last n instances on your machine
#   clusterjob history -n
#
# To get info of the last instance
#   clusterjob info
#
# To get state of the last instance
#   clusterjob state
#
# To clean the last instance
#   clusterjob clean
#
# Copyright  Hatef Monajemi (monajemi@stanford.edu)


use lib '/Users/hatef/github_projects/clusterjob/src';  #for testing

use CJ;          # contains essential functions
use CJ::CJVars;  # contains global variables of CJ;
use CJ::Matlab;
use Getopt::Declare;
use vars qw($message $mem $dep_folder);  # options
$::VERSION = 0.0.1;




#====================================
#         READ OPTIONS
#====================================
$dep_folder = ".";
$mem        = "8G";      # default memeory
$message    = "";        # default message
my $spec = <<'EOSPEC';
   -dep    <dep_path>		 dependency folder path [nocase]
                                 {$dep_folder=$dep_path}
   -m      <msg>	         reminder message
                                 {$message=$msg}
   -mem    <memory>	         memory requested [nocase]
                                 {$mem=$memory}
EOSPEC

my $opts = Getopt::Declare->new($spec);

#    print "$opts->{-m}\n";
#    print "$opts->{-mem}\n";
#    print "$opts->{-dep}\n";



my $BASE = `pwd`;chomp($BASE);   # Base is where program lives!

#====================================
#         DATE OF CALL
#====================================
$date = &CJ::date();


#====================================
#         READ INPUT
#====================================
my $argin = $#ARGV+1 ;



if($argin < 1){
&CJ::err("Incorrect usage: use 'perl clusterjob.pl run MACHINE PROGRAM [options]' or 'perl clusterjon.pl clean' ")
}


# create .info directory
mkdir "$install_dir/.info" unless (-d "$install_dir/.info");


# create history file if it does not exist
if( ! -f $history_file ){
&CJ::touch($history_file);
my $header = sprintf("%-15s%-15s%-21s%-10s%-15s%-20s%30s", "count", "date", "package", "action", "machine", "job_id", "message");
&CJ::add_to_history($header);
}

# Find the last number
my $lastnum=`grep "." $history_file | tail -1  | awk \'{print \$1}\' `;
($hist_date, $time) = split('\_', $date);
my $history = sprintf("%-15u%-15s",$lastnum+1, $hist_date );


# create run_history file if it does not exit
# this file contains more information about a run
# such as where it is saved, etc.

&CJ::touch($run_history_file) unless (-f $run_history_file);


my $runflag= shift;
#==========================================================
#            CLUSTERJOB CLEAN
#       ex.  clusterjob clean
#       ex.  clusterjob clean 2015JAN07_213759
#==========================================================

if($runflag eq "clean"){
    
my $package = shift;
my $account;
my $local_path;
my $remote_path;
my $job_id;
my $save_path;
    
my $info;
if($package eq ""){
#read the first lines of last_instance.info;
$info =  &CJ::retrieve_package_info();
$package = $info->{'package'};
}else{

    if(&CJ::is_valid_package_name($package)){
    # read info from $run_history_file
            
        my $cmd= "grep -q '$package' '$run_history_file'";
        $pattern_exists = system($cmd);chomp($pattern_exists);
            
        if ($pattern_exists==0){
            $info =  &CJ::retrieve_package_info($package);
        }else{
            &CJ::err("No such job found in CJ database.");
        }
            
    }else{
        &CJ::err("incorrect usage: nothing to show");
    }
    
        
}

$account     =   $info->{'account'};
$local_path  =  $info->{'local_path'};
$remote_path =   $info->{'remote_path'};
$job_id      =   $info->{'job_id'};
$save_path   =   $info->{'save_path'};
    
    
print "CLEANing $package:\n";
my $local_clean     = "$local_path\*";
my $remote_clean    = "$remote_path\*";
my $save_clean      = "$save_path\*";

    
    

if (defined($job_id) && $job_id ne "") {
print "deleting jobs associated with job $package\n";
my @job_ids = split(',',$job_id);
$job_id = join(' ',@job_ids);
my $cmd = "rm -rf $local_clean; rm -rf $save_clean; ssh ${account} 'qdel $job_id; rm -rf $remote_clean' " ;
&CJ::my_system($cmd);
}else {
my $cmd = "rm -rf $local_clean;rm -rf $save_clean; ssh ${account} 'rm -rf $remote_clean' " ;
&CJ::my_system($cmd);
}
    

    
    
    
    
# ADD THIS CLEAN TO HISTRY
$history .= sprintf("%-21s%-10s",$package, $runflag);
&CJ::add_to_history($history);
    
    
    
exit 0;
}




#==========================================================
#            CLUSTERJOB STATE
#       ex.  clusterjob state
#       ex.  clusterjob state 2015JAN07_213759
#==========================================================

if($runflag eq "state"){


   
     my $package = shift;
    
    
       
    
    my $info;
    if($package eq ""){
        #read the first lines of last_instance.info;
         $info = &CJ::retrieve_package_info();
         $package = $info->{'package'};

    }else{
        
        if( &CJ::is_valid_package_name($package) ){
            # read info from $run_history_file
            
            my $cmd= "grep -q '$package' '$run_history_file'";
            $pattern_exists = system($cmd);chomp($pattern_exists);
            
            if ($pattern_exists==0){
                $info = &CJ::retrieve_package_info($package);
               
            }else{
                print "No such job found in the database\n";
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
    @job_ids = split(',',$job_id);
    my $jobs = join('|', @job_ids);
    my $states;
        if($bqs eq "SGE"){
            $states = (`ssh ${account} 'qstat -u \\* | grep -E "$jobs" ' | awk \'{print \$5}\'`) ;chomp($state);
        }elsif($bqs eq "SLURM"){
            $states = (`ssh ${account} 'sacct -n --jobs=$job_id | grep -v "^[0-9]*\\." ' | awk \'{print \$6}\'`) ;chomp($state);
            #$states = (`ssh ${account} 'sacct -n --format=state --jobs=$job_id'`) ;chomp($state);
	
	}else{
            &CJ::err("Unknown batch queueing system");
        }
    
    @states = split('\n',$states);
    
    
    if($num eq ""){
        print '-' x 50;print "\n";
        print "PACKAGE " . "$package" . "\n";
        print "CLUSTER " . "$account" . "\n";
        foreach $i (0..$#job_ids)
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
    $state = (`ssh ${account} 'sacct | grep $job_id' | awk \'{print \$6}\'`) ;chomp($state);
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






#==========================================================
#            CLUSTERJOB INFO
#       ex.  clusterjob info
#==========================================================
if($runflag eq "info" ){
    my $info=(`cat $last_instance_file`);
    print "$info \n";
    exit 0;
}




#==========================================================
#            CLUSTERJOB HISTORY
#       ex.  clusterjob history
#       ex.  clusterjob history -n
#       ex.  clusterjob history 2015JAN07_213759
#==========================================================

if($runflag eq "history" ){
    
    my $history_argin = shift;
    
    # check if it is the name of a package
    # such as 2015JAN07_212840
    
    if($history_argin eq ""){
        $history_argin= 1;
    }
    
    if(&CJ::is_valid_package_name($history_argin)){
    # read info from $run_history_file
        
        print '-' x 35;print "\n";
        print "run info, job $history_argin"; print "\n";
        print '-' x 35;print "\n";
        my $cmd= "grep -q '$history_argin' '$run_history_file'";
        $pattern_exists = system($cmd);
        chomp($pattern_exists);
        
        if ($pattern_exists==0){
    
        my $cmd = "awk '/$history_argin/{f=1}f' $run_history_file | sed -n 1,14p ";
            
        system($cmd);
        }else{
            &CJ::err("No such job found in CJ database");
        }
        
        
        
        
        
        
    }elsif($history_argin =~ m/^\d*$/){
    
        $history_argin =~ s/\D//g;   #remove any non-digit
        my $info=`tail -n  $history_argin $history_file`;chomp($info);
        print "$info \n";
        
    }else{
        &CJ::err("Incorrect usage: nothing to show");
    }
    
    
    
    
    exit 0;
}







#==========================================================
#            CLUSTERJOB GET
#       ex.  clusterjob get Results.txt
#       ex.  clusterjob get 2015JAN07_213759  Results.mat
#==========================================================


if($runflag eq "get" ){
    
    
    
    my $package = shift;
    
    my $machine;
    my $account;
    my $remote_path;
    my $local_path;
    my $job_id;
    my $bqs;
    my $runflag;
    my $program;
    
    my $res_filename;
    if(&CJ::is_valid_package_name($package)){
        
        $res_filename = shift;
        # read info from $run_history_file
        
        my $cmd= "grep -q '$package' '$run_history_file'";
        $pattern_exists = system($cmd);chomp($pattern_exists);
        
        if ($pattern_exists==0){
            
            my $info  = &CJ::retrieve_package_info($package);
            $machine = $info->{'machine'};
            $account    = $info->{'account'};
            $remote_path = $info->{'remote_path'};
            $runflag    = $info->{'runflag'};
            $bqs        = $info->{'bqs'};
            $job_id     = $info->{'job_id'};
            $program    = $info->{'program'};

           
            
        }else{
            &CJ::err("No such job found in CJ database");
        }

    }elsif($package ne "" ){
        $res_filename = $package;  # the input is then filename in this case.
        #read the first lines of last_instance.info;
        
        my $info  = &CJ::retrieve_package_info();   # retrieves the last instance info;
        $machine    = $info->{'machine'};
        $package    = $info->{'package'};
        $account    = $info->{'account'};
        $remote_path = $info->{'remote_path'};
        $runflag    = $info->{'runflag'};
        $bqs        = $info->{'bqs'};
        $job_id     = $info->{'job_id'};
        $program    = $info->{'program'};
        
        
    }else{
       &CJ::err("Incorrect use of 'CJ get'. Consider adding filename");
    }
    
    
    
    # Get current remote directory from .ssh_config
    # user might wanna rename, copy to anothet place,
    # etc. We consider the latest one , and if the
    # save remote is different, we issue a warning
    # for the user.
    print "$machine\n";
    my $ssh             = &CJ::host($machine);
    my $remotePrefix    = $ssh->{remote_repo};
    
    my @program_name    = split /\./,$program;
    my  $lastone = pop @program_name;
    my $program_name   =   join /\_/,@program_name;
    my $current_remote_path = "$remotePrefix/$program_name/$package";
  
    print("$remote_path");
    if($current_remote_path ne $remote_path){
        &CJ::warning("the .ssh_config remote directory and the history remote are not the same. CJ is choosing:\n     $account:${current_remote_path}.");
        $remote_path = $current_remote_path;
    }
    
    
    
    
    
    
    
    
    #my $cmd = "rm -rf  $get_tmp_dir/";
    #&CJ::my_system($cmd) unless($get_tmp_dir=="");

    
    
    
    
# a bit more work if it is parrun!
# just collecting all of the runs
if($runflag =~ m/^par*/){


if ($res_filename eq ""){
&CJ::err("The result filename must be provided for GET with parrun packages, eg, 'clusterjob get Results.mat' ");
}
#find the number of folders with results in it
my @job_ids = split(',', $job_id);
my $num_res = 1+$#job_ids;

# header for bqs's
$HEADER = &CJ::bash_header($bqs);
# check which jobs are done.
my $bash_remote_path  = $remote_path;
$bash_remote_path =~ s/~/\$HOME/;
my $check_runs=<<TEXT;
$HEADER

if [ ! -f "$bash_remote_path/run_list.txt" ];then
touch $bash_remote_path/done_list.txt
touch $bash_remote_path/run_list.txt
        
        for COUNTER in `seq $num_res`;do
            if [ -f "$bash_remote_path/\$COUNTER/$res_filename" ];then
        echo -e "\$COUNTER\\t" >> "$bash_remote_path/done_list.txt"
            else
                echo -e "\$COUNTER\\t" >> "$bash_remote_path/run_list.txt"
                fi
        done
else
    
    for line in \$(cat $bash_remote_path/run_list.txt);do
    COUNTER=`grep -o "[0-9]*" <<< \$line`
    if [ -f "$bash_remote_path/\$COUNTER/$res_filename" ];then
        echo -e "\$COUNTER\\t" >> "$bash_remote_path/done_list.txt"
        sed  '/\^\$COUNTER\$/d' "$bash_remote_path/run_list.txt" > "$bash_remote_path/run_list.txt"
    fi
        done
fi
        
TEXT
my $check_name = "check_complete.sh";
my $check_path = "/tmp/$check_name";
&CJ::writeFile($check_path,$check_runs);
my $cmd = "scp $check_path $account:$remote_path/ ;ssh $account 'source ~/.bashrc;cd $remote_path; bash $check_name'";
&CJ::my_system($cmd);
        
# Run a script to gather all *.mat files of the same name.
my $done_filename = "done_list.txt";
$collect_bash_script = &CJ::Matlab::make_collect_script($res_filename, $done_filename,$bqs);
#print "$collect_bash_script";

        
my $CJ_reduce = "$install_dir/CJ/CJ_reduce.m";
my $collect_name = "cj_collect.sh";
my $collect_bash_path = "/tmp/$collect_name";
&CJ::writeFile($collect_bash_path,$collect_bash_script);
my $cmd = "scp $collect_bash_path $CJ_reduce $account:$remote_path/";
&CJ::my_system($cmd);


my $cmd = "ssh $account 'cd $remote_path; srun bash -l $collect_name'";
&CJ::my_system($cmd);
        
}
 
mkdir "$get_tmp_dir" unless (-d "$get_tmp_dir");    
mkdir "$get_tmp_dir/$package" unless (-d "$get_tmp_dir/$package");
    
my $cmd = "rsync -arvz  $account:${remote_path}/* $get_tmp_dir/$package";
&CJ::my_system($cmd);
&CJ::message("Please see your last results in $get_tmp_dir/$package");
    
# In case save is run after, we must have the info of the package
#&CJ::writeFile($save_info_file, $package);
    
    exit 0;
}





#=================================================================
#            CLUSTERJOB SAVE (ONLY SAVES THE OUTPUT OF 'GET')
#  ex.  clusterjob save package
#  ex.  clusterjob save package ~/Downloads/myDIR
#=================================================================


if($runflag eq "save" ){
    my $package = shift;
    
    if(! &CJ::is_valid_package_name($package)){
        &CJ::err("Please enter a valid package name");
    }
    
    my $save_path = shift;
    # my $package = `sed -n '1{p;q;}' $save_info_file`;chomp($package);
    
    
    my $info  = &CJ::retrieve_package_info($package);
    
    
    
    
    
    if( $save_path eq ""){
    # Read the deafult save directory
        $save_path= $info->{'save_path'};

        print "Saving results in ${save_path}:\n";
    }
    
    
    
    
    if(-d $save_path){
        # Ask if it needs to be overwritten
        
        print "\nDirectory $save_path already exists. Do you want to overwrite? Y/N\n ";
        my $yesno =  <STDIN>; chomp($yesno);
        if(lc($yesno) eq "y" or lc($yesno) eq "yes"){
            
            
        my $cmd = "rm -rf $save_path/*";
        &CJ::my_system($cmd);
            
        my $cmd = "rsync -arz  $get_tmp_dir/ $save_path/";
        &CJ::my_system($cmd);
        
        my $cmd = "cp  $save_info_file $save_path/job.info";
        &CJ::my_system($cmd);
            
      
        $history .= sprintf("%-21s%-10s",$package, $runflag);
      
        
        # ADD THIS SAVE TO HISTRY
        &CJ::add_to_history($history);
            
            
        }else{
        
        print "Directory $save_path cannot be overwritten!\n";
        
        }
        
        
    }else{
    
    # Create directories
    my $cmd = "mkdir -p $save_path";
    &CJ::my_system($cmd) ;
    
    my $cmd = "rsync -arz  $get_tmp_dir/$package $save_path/";
    &CJ::my_system($cmd);
        
        #my $cmd = "cp  $save_info_file $save_path/job.info";
        #&CJ::my_system($cmd);
        
    
    $history .= sprintf("%-21s%-10s",$package, $runflag);
    # ADD THIS SAVE TO HISTRY
    &CJ::add_to_history($history);
        
    }
    


    exit 0;
}





















#========================================================================
#            CLUSTERJOB RUN/DEPLOY/PARRUN
#  ex.  clusterjob run sherlock myScript.m DepFolder
#  ex.  clusterjob run sherlock myScript.m DepFolder -m  "my reminder"
#========================================================================

if($argin < 3){
    &CJ::err("Incorrect usage: use 'perl clusterjob.pl run MACHINE PROGRAM' or 'perl clusterjon.pl clean' ");
}


# READ EXTRA ARGUMENTS
my $machine = shift;
my $program = shift;

$short_message = substr($message, 0, 30);

my $ssh      = &CJ::host($machine);
my $account  = $ssh->{account};
my $bqs      = $ssh->{bqs};
my $remotePrefix    = $ssh->{remote_repo};


#check to see if the file and dep folder exists
if(! -e "$BASE/$program" ){
 &CJ::err("$BASE/$program not found");
}
if(! -d "$BASE/$dep_folder" ){
    &CJ::err("Dependency folder $BASE/$dep_folder not found");
}




#=======================================
#       BUILD DOCSTRING
#       WE NAME THE REMOTE FOLDERS
#       BY PROGRAM AND DATE
#       EXAMPLE : MaxEnt/2014DEC02_1426
#=======================================

my $docstring=<<DOCSTRING;
# EXPERIMENT $program
# COPYRIGHT 2014:
# Hatef Monajemi (monajemi AT stanford DOT edu)
# DATE : $year $abbr[$mon] $mday  ($hour:$min)
DOCSTRING

my @program_name = split /\./,$program;


my @program_name    = split /\./,$program;
my  $lastone = pop @program_name;
my $program_name   =   join /\_/,@program_name;

my $localDir       = "$localPrefix/"."$program_name";
my $local_sep_Dir = "$localDir/" . "$date"  ;
my $saveDir       = "$savePrefix"."$program_name";


#====================================
#     CREATE LOCAL DIRECTORIES
#====================================
# create local directories
if(-d $localPrefix){
    
    mkdir "$localDir" unless (-d $localDir);
    mkdir "$local_sep_Dir" unless (-d $local_sep_Dir);
    
}else{
    # create local Prefix
    mkdir "$localPrefix";
    mkdir "$localDir" unless (-d $localDir);
    mkdir "$local_sep_Dir" unless (-d $local_sep_Dir);
}


# cp dependencies
my $cmd   = "cp -r $dep_folder/* $local_sep_Dir/";
&CJ::my_system($cmd);

#=====================
#  REMOTE DIRECTORIES
#=====================
my $remoteDir       = "$remotePrefix/"."$program_name[0]";
my $remote_sep_Dir = "$remoteDir/" . "$date"  ;

# for creating remote directory
my $outText;
if($bqs eq "SLURM"){
$outText=<<TEXT;
#!/bin/bash -l
if [ ! -d "$remotePrefix" ]; then
mkdir $remotePrefix
fi
mkdir $remoteDir
TEXT
}elsif($bqs eq "SGE"){
$outText=<<TEXT;
#!/bin/bash
#\$ -cwd
#\$ -S /bin/bash
if [ ! -d "$remotePrefix" ]; then
mkdir $remotePrefix
fi
mkdir $remoteDir
TEXT
}else{
&CJ::err("unknown BQS");
}











if ($runflag eq "deploy" || $runflag eq "run"){


#============================================
#   COPY ALL NECESSARY FILES INTO THE
#    EXPERIMENT FOLDER
#============================================
my $cmd = "cp $BASE/$program $local_sep_Dir/";
&CJ::my_system($cmd);


#===========================================
# BUILD A BASH WRAPPER
#===========================================

my $sh_script = make_shell_script($program,$date);
$local_sh_path = "$local_sep_Dir/bashMain.sh";
&CJ::writeFile($local_sh_path, $sh_script);



my $master_script;
$HEADER = &CJ::bash_header($bqs);
$master_script=$HEADER;
$master_script.="$docstring";
 
    
$master_script .= "mkdir ${remote_sep_Dir}"."/logs" . "\n" ;
$master_script .= "mkdir ${remote_sep_Dir}"."/scripts" . "\n" ;


my $tagstr="$program_name[0]_$date";
if($bqs eq "SGE"){
    
$master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem -N $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n";
}elsif($bqs eq "SLURM"){

$master_script.="sbatch --mem=$mem  --time=40:00:00  -J $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n"

}else{
&CJ::err("unknown BQS")
}

my $local_master_path="$local_sep_Dir/master.sh";
    &CJ::writeFile($local_master_path, $master_script);





#==================================
#       PROPAGATE THE FILES
#       AND RUN ON CLUSTER
#==================================
my $tarfile="$date".".tar.gz";
my $cmd="cd $localDir; tar -czf $tarfile $date/  ; rm -rf $local_sep_Dir  ; cd $BASE";
&CJ::my_system($cmd);

    
# create remote directory  using outText
my $cmd = "ssh $account 'echo `$outText` '  ";
&CJ::my_system($cmd);


print "$runflag"."ing files:\n";
# copy tar.gz file to remoteDir
my $cmd = "rsync -avz  ${localDir}/${tarfile} ${account}:$remoteDir/";
&CJ::my_system($cmd);



my $cmd = "ssh $account 'source ~/.bashrc;cd $remoteDir; tar -xzvf ${tarfile} ; cd ${date}; bash master.sh > $remote_sep_Dir/qsub.info; sleep 2'";
&CJ::my_system($cmd) unless ($runflag eq "deploy");
    

 
# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
my $cmd = "rsync -avz $account:$qsubfilepath  $install_dir/.info";
&CJ::my_system($cmd) unless ($runflag eq "deploy");

    
    
    
    
    
my $job_id;
if($runflag eq "run"){
# read run info
my $local_qsub_info_file = "$install_dir/.info/"."qsub.info";
open my $FILE, '<', $local_qsub_info_file;
my $job_id_info = <$FILE>;
close $FILE;
    
chomp($job_id_info);
($job_id) = $job_id_info =~ /(\d+)/; # get the first string of integer, i.e., job_id
print "JOB_ID: $job_id\n";
    
#delete the local qsub.info after use
my $cmd = "rm $local_qsub_info_file";
&CJ::my_system($cmd);
    
    

$history .= sprintf("%-21s%-10s%-15s%-20s%30s",$date, $runflag, $machine, $job_id, $short_message);
&CJ::add_to_history($history);
#=================================
# store tarfile info for deletion
# when needed
#=================================

    
}else{
$job_id ="";
$history .= sprintf("%-21s%-10s%-15s%-20s%30s",$date, $runflag, $machine, " ", $short_message);
&CJ::add_to_history($history);
}


my $run_history=<<TEXT;
${date}
$machine
${account}
${localPrefix}
${localDir}/${date}
${remotePrefix}
${remoteDir}/${date}
$job_id
$bqs
${savePrefix}
${saveDir}/${date}
$runflag
$program
$message
TEXT

&CJ::add_to_run_history($run_history);

    
    
    
my $last_instance=$run_history;
$last_instance.=`cat $BASE/$program`;
&CJ::writeFile($last_instance_file, $last_instance);

    


    
    
}elsif($runflag eq "parrun"  || $runflag eq "pardeploy"){
#==========================================
#   clusterjob parrun myscript.m DEP
#
#   this implements parfor in perl so for
#   each grid point, we will have one separate
#   job
#==========================================

# read the script, parse it out and
# find the for loops
my $scriptfile = "$BASE/$program";
  
    
# script lines will have blank lines or comment lines removed;
# ie., all remaining lines are effective codes
# that actually do something.
my $script_lines;
open my $fh, "$scriptfile" or die "Couldn't open file: $!";
while(<$fh>){
    $_ = &uncomment_matlab_line($_);
    if (!/^\s*$/){
        $script_lines .= $_;
    }
}
close $fh;
    
    
    
my @lines = split('\n', $script_lines);
my @forlines_idx_set;
foreach my $i (0..$#lines){
$line = $lines[$i];
    if ($line =~ /^\s*(for.*)/ ){
    push @forlines_idx_set, $i;
    }
}
# ==============================================================
# complain if the size of for loops is more than three or
# if they are not consecetive. We do not allow it in clusterjob.
# ==============================================================
if($#forlines_idx_set+1 > 3 || $#forlines_idx_set+1 < 1)
{
 &CJ::err(" 'parrun' does not allow a non-par loop, less than 1 or more than 3 parloops inside the MAIN script.");
}
    
foreach my $i (0..$#forlines_idx_set-1){
if($forlines_idx_set[$i+1] ne $forlines_idx_set[$i]+1){
 &CJ::err("CJ does not allow anything between the parallel for's. try rewriting your loops");
}
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
    

    
# Determine the tags and ranges of the
# indecies
my @idx_tags;
my @ranges;
for (split /^/, $FOR) {

    my ($idx_tag, $range) = &read_matlab_index_set($_, $TOP);
    
    push @idx_tags, $idx_tag;
    push @ranges, $range;
    
}

    
    
#==============================================
#        MASTER SCRIPT
#==============================================
my $master_script;
$HEADER = &CJ::bash_header($bqs);
$master_script=$HEADER;
$master_script.="$docstring";
    
    
    
    
my $nloops = $#forlines_idx_set+1;

my $counter = 0;   # counter gives the total number of jobs submited: (1..$counter)
if($nloops eq 1){

    
            # parallel vars
            my @idx_0 = split(',', $ranges[0]);
            
            foreach my $v0 (@idx_0){
                  $counter = $counter+1;
                    
                    #============================================
                    #     BUILD EXP FOR this (v0,v1)
                    #============================================
                    
                    
                    my $INPUT;
                    $INPUT .= "if ($idx_tags[0]~=$v0); continue;end";
                    my $new_script = "$TOP \n $FOR \n $INPUT \n $BOT";
                    undef $INPUT;                   #undef INPUT for the next run
                    
                    #============================================
                    #   COPY ALL NECESSARY FILES INTO THE
                    #   EXPERIMENTS FOLDER
                    #============================================
                    
                
                    mkdir "$local_sep_Dir/$counter";
                    
                    my $this_path  = "$local_sep_Dir/$counter/$program";
                    &CJ::writeFile($this_path,$new_script);
                    
                    
                    
                    # build bashMain.sh for each parallel package
                    my $remote_par_sep_dir = "$remote_sep_Dir/$counter";
                    my $sh_script = make_par_shell_script($program,$date,$counter, $remote_par_sep_dir);
                    $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
                    &CJ::writeFile($local_sh_path, $sh_script);
                    
                    
                    # Add QSUB to MASTER SCRIPT
                    $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/logs"    . "\n" ;
                    $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/scripts" . "\n" ;
                    
                    
                    my $tagstr="$program_name[0]_$date_$counter";
                    if($bqs eq "SGE"){
                        $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem -N $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n";
                    }elsif($bqs eq "SLURM"){
                        
                        $master_script.="sbatch --mem=$mem  --time=40:00:00  -J $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n"
                        
                    }else{
                        &CJ::err("unknown BQS");
                    }
                    
                } #v0
    

}elsif($nloops eq 2){

  
    
        # parallel vars
        my @idx_0 = split(',', $ranges[0]);
        my @idx_1 = split(',', $ranges[1]);
        
        
        foreach my $v0 (@idx_0){
            foreach my $v1 (@idx_1){
            
                $counter = $counter+1;
                
                #============================================
                #     BUILD EXP FOR this (v0,v1)
                #============================================
                
                
                my $INPUT;
                $INPUT .= "if ($idx_tags[0]~=$v0 || $idx_tags[1]~=$v1 ); continue;end";
                my $new_script = "$TOP \n $FOR \n $INPUT \n $BOT";
                undef $INPUT;                   #undef INPUT for the next run
               
                #============================================
                #   COPY ALL NECESSARY FILES INTO THE
                #   EXPERIMENTS FOLDER
                #============================================
                
                
                mkdir "$local_sep_Dir/$counter";
                my $this_path  = "$local_sep_Dir/$counter/$program";
                &CJ::writeFile($this_path,$new_script);
                
                
                
                # build bashMain.sh for each parallel package
                my $remote_par_sep_dir = "$remote_sep_Dir/$counter";
                my $sh_script = make_par_shell_script($program,$date,$counter, $remote_par_sep_dir);
                $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
                &CJ::writeFile($local_sh_path, $sh_script);
                
                
                # Add QSUB to MASTER SCRIPT
                $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/logs"    . "\n" ;
                $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/scripts" . "\n" ;
                
                
                my $tagstr="$program_name[0]_$date_$counter";
                if($bqs eq "SGE"){
                    $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem -N $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n";
                }elsif($bqs eq "SLURM"){
                    
                    $master_script.="sbatch --mem=$mem  --time=40:00:00  -J $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n"
                    
                }else{
                    &CJ::err("unknown BQS");
                }
                
            } #v0
        } #v1
    

}elsif($nloops eq 3){
    
    
    
        # parallel vars
        my @idx_0 = split(',', $ranges[0]);
        my @idx_1 = split(',', $ranges[1]);
        my @idx_2 = split(',', $ranges[2]);
        foreach my $v0 (@idx_0){
            foreach my $v1 (@idx_1){
                foreach my $v2 (@idx_2){
                $counter = $counter+1;
                
                #============================================
                #     BUILD EXP FOR this (v0,v1)
                #============================================
                
                
                my $INPUT;
                $INPUT .= "if ($idx_tags[0]~=$v0 || $idx_tags[1]~=$v1  || $idx_tags[2]~=$v2); continue;end";
                my $new_script = "$TOP \n $FOR \n $INPUT \n $BOT";
                undef $INPUT;                   #undef INPUT for the next run
                
                #============================================
                #   COPY ALL NECESSARY FILES INTO THE
                #   EXPERIMENTS FOLDER
                #============================================
                
                
                mkdir "$local_sep_Dir/$counter";
                    
                my $this_path  = "$local_sep_Dir/$counter/$program";
                &CJ::writeFile($this_path,$new_script);
                
                
                
                # build bashMain.sh for each parallel package
                my $remote_par_sep_dir = "$remote_sep_Dir/$counter";
                my $sh_script = make_par_shell_script($program,$date,$counter, $remote_par_sep_dir);
                $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
                &CJ::writeFile($local_sh_path, $sh_script);
                
                
                # Add QSUB to MASTER SCRIPT
                $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/logs"    . "\n" ;
                $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/scripts" . "\n" ;
                
                
                my $tagstr="$program_name[0]_$date_$counter";
                if($bqs eq "SGE"){
                    $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem -N $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n";
                }elsif($bqs eq "SLURM"){
                    
                    $master_script.="sbatch --mem=$mem  --time=40:00:00  -J $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n"
                    
                }else{
                    &CJ::err("unknown BQS");
                }
                
            } #v0
        } #v1
        } #v2
        
        
    
    
    


}else{
    &CJ::err("Max number of parallel variables exceeded; $nloops > 3 ");
}
    

    
#============================================
#   COPY ALL NECESSARY FILES INTO THE
#    EXPERIMENT FOLDER
#============================================
my $cmd = "cp $BASE/$program $local_sep_Dir/";
&CJ::my_system($cmd);
    
    
#===================================
# write out developed master script
#===================================
my $local_master_path="$local_sep_Dir/master.sh";
    &CJ::writeFile($local_master_path, $master_script);
    

#==================================
#       PROPAGATE THE FILES
#       AND RUN ON CLUSTER
#==================================
my $tarfile="$date".".tar.gz";
my $cmd="cd $localDir; tar -czf $tarfile $date/  ; rm -rf $local_sep_Dir  ; cd $BASE";
system($cmd);


# create remote directory  using outText
my $cmd = "ssh $account 'echo `$outText` '  ";
system($cmd);


print "$runflag"."ing files:\n";
# copy tar.gz file to remoteDir
my $cmd = "rsync -avz  ${localDir}/${tarfile} ${account}:$remoteDir/";
&CJ::my_system($cmd);



my $cmd = "ssh $account 'source ~/.bashrc;cd $remoteDir; tar -xzf ${tarfile} ; cd ${date}; bash -l master.sh > $remote_sep_Dir/qsub.info; sleep 2'";
system($cmd) unless ($runflag eq "pardeploy");
 

    
# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
my $cmd = "rsync -avz $account:$qsubfilepath  $install_dir/";
&CJ::my_system($cmd) unless ($runflag eq "pardeploy");
    

    
my @job_ids;
if($runflag eq "parrun"){
    # read run info
        my $local_qsub_info_file = "$install_dir/"."qsub.info";
        open my $FILE, '<', $local_qsub_info_file;
        while(<$FILE>){
        my $job_id_info = $_;
        chomp($job_id_info);
        ($this_job_id) = $job_id_info =~/(\d+)/; # get the first string of integer, i.e., job_id
        #print "JOB_ID: $this_job_id\n";
        push @job_ids, $this_job_id;
        }
        close $FILE;

$job_id = join(',', @job_ids);

#delete the local qsub.info after use
my $cmd = "rm $local_qsub_info_file";
&CJ::my_system($cmd);
    
    
# store tarfile info for deletion
# when needed



$history .= sprintf("%-21s%-10s%-15s%-20s%-30s",$date, $runflag, $machine, "$job_ids[0]-$job_ids[-1]", $short_message);
&CJ::add_to_history($history);
    
    
}else{
$job_id = "";
$history .= sprintf("%-21s%-10s%-15s%-20s%-30s",$date, $runflag, $machine, " ", $short_message);
&CJ::add_to_history($history);
}

    
    
    
    
my $run_history=<<TEXT;
${date}
$machine
${account}
${localPrefix}
${localDir}/${date}
${remotePrefix}
${remoteDir}/${date}
$job_id
$bqs
${savePrefix}
${saveDir}/${date}
$runflag
$program
$message
TEXT
    
    
&CJ::add_to_run_history($run_history);


    
    
my $last_instance=$run_history;
$last_instance.=`cat $BASE/$program`;
&CJ::writeFile($last_instance_file, $last_instance);

    
    
    
    
    
    
    
    
    

}else{
&CJ::err("Runflag $runflag was not recognized");
}







#====================================
#       BUILD A BASH WRAPPER
#====================================

sub make_shell_script
    {
my ($program,$date) = @_;

my $sh_script;

if($bqs eq "SGE"){
$sh_script=<<'HEAD'
#!/bin/bash
#\$ -cwd
#\$ -S /bin/bash
    

echo JOB_ID $JOB_ID
echo WORKDIR $SGE_O_WORKDIR
DIR=`pwd`
HEAD
    
}elsif($bqs eq "SLURM"){
$sh_script=<<'HEAD'
#!/bin/bash -l
echo JOB_ID $SLURM_JOBID
echo WORKDIR $SLURM_SUBMIT_DIR
DIR=`pwd`
HEAD
}else{
&CJ::err("unknown BQS");
}
 
$sh_script.= <<'MID';
PROGRAM="<PROGRAM>";
DATE=<DATE>;
cd $DIR;
mkdir scripts
mkdir logs
SHELLSCRIPT=${DIR}/scripts/hm.runProgram.${DATE}.sh;
LOGFILE=${DIR}/logs/hm.runProgram.${DATE}.log;
MID

if($bqs eq "SGE"){
$sh_script.= <<'BASH';
cat <<THERE > $SHELLSCRIPT
#! /bin/bash
#$ -cwd
#$ -R y
#$ -S /bin/bash

echo starting job $SHELLSCRIPT
echo JOB_ID \$JOB_ID
echo WORKDIR \$SGE_O_WORKDIR
date
cd $DIR

module load MATLAB-R2014a
matlab -nosplash -nodisplay <<HERE
<MATPATH>

% make sure each run has different random number stream
mydate = date;
RandStream.setGlobalStream(RandStream('mt19937ar','seed', sum(100*clock)));
defaultStream = RandStream.getGlobalStream;
savedState = defaultStream.State;
fname = sprintf('randState.mat');
save(fname, 'mydate', 'savedState');
cd $DIR
run('${PROGRAM}');
quit;
HERE

echo ending job \$SHELLSCRIPT
echo JOB_ID \$JOB_ID
date
echo "done"
THERE
    
chmod a+x $SHELLSCRIPT
bash $SHELLSCRIPT > $LOGFILE
    
BASH
}elsif($bqs eq "SLURM"){
$sh_script.= <<'BASH';
cat <<THERE > $SHELLSCRIPT
#! /bin/bash -l

echo starting job \$SHELLSCRIPT
echo JOB_ID \$SLURM_JOBID
echo WORKDIR \$SLURM_SUBMIT_DIR
date
cd $DIR

module load matlab\/R2014a
matlab -nosplash -nodisplay <<HERE
<MATPATH>
% make sure each run has different random number stream
mydate = date;
RandStream.setGlobalStream(RandStream('mt19937ar','seed', sum(100*clock)));
defaultStream = RandStream.getGlobalStream;
savedState = defaultStream.State;
fname = sprintf('randState.mat');
save(fname, 'mydate', 'savedState');
cd $DIR
run('${PROGRAM}');
quit;
HERE
    
echo ending job \$SHELLSCRIPT
echo JOB_ID \$SLURM_JOBID
date
echo "done"
THERE
    
chmod a+x $SHELLSCRIPT
bash $SHELLSCRIPT > $LOGFILE
    
    
BASH
}

my $pathText;
if($bqs eq "SGE"){
# CVX is already setup on solomon and proclus
$pathText.=<<MATLAB;
cvx_setup;
cvx_quiet(true)
% Find and add Sedumi Path for machines that have CVX installed
cvx_path = which('cvx_setup.m');
oldpath = textscan( cvx_path, '%s', 'Delimiter', '/');
newpath = horzcat(oldpath{:});
sedumi_path = [sprintf('%s/', newpath{1:end-1}) 'sedumi'];
addpath(sedumi_path)
% MOSEK
addpath '~/mosek/7/toolbox/r2013a/'
MATLAB
}elsif($bqs eq "SLURM"){
$pathText.=<<MATLAB;
addpath '~/BPDN/CVX/cvx' -begin
cvx_setup;
cvx_quiet(true);
addpath '~/mosek/7/toolbox/r2013a/'
MATLAB
}
        
        
        
        
        
        
$sh_script =~ s|<PROGRAM>|$program|;
$sh_script =~ s|<DATE>|$date|;
$sh_script =~ s|<MATPATH>|$pathText|;
        
return $sh_script;
}
        
        

# parallel shell script
#====================================
#       BUILD A PARALLEL BASH WRAPPER
#====================================

sub make_par_shell_script
{
my ($program,$date,$counter,$remote_path) = @_;

my $sh_script;

if($bqs eq "SGE"){
    
$sh_script=<<'HEAD'
#!/bin/bash -l
#\$ -cwd
#\$ -S /bin/bash


echo JOB_ID $JOB_ID
echo WORKDIR $SGE_O_WORKDIR
DIR=<remote_path>
HEAD

}elsif($bqs eq "SLURM"){
$sh_script=<<'HEAD'
#!/bin/bash -l
echo JOB_ID $SLURM_JOBID
echo WORKDIR $SLURM_SUBMIT_DIR
DIR=<remote_path>
HEAD
}else{
&CJ::err("unknown BQS");
}
    

$sh_script.= <<'MID';
PROGRAM="<PROGRAM>";
DATE=<DATE>;
COUNTER=<COUNTER>;
cd $DIR;
mkdir scripts
mkdir logs
SHELLSCRIPT=${DIR}/scripts/hm.runProgram.${DATE}.${COUNTER}.sh;
LOGFILE=${DIR}/logs/hm.runProgram.${DATE}.${COUNTER}.log;
MID

if($bqs eq "SGE"){
$sh_script.= <<'BASH';
cat <<THERE > $SHELLSCRIPT
#! /bin/bash -l
#$ -cwd
#$ -R y
#$ -S /bin/bash

echo starting job $SHELLSCRIPT
echo JOB_ID \$JOB_ID
echo WORKDIR \$SGE_O_WORKDIR
date
cd $DIR

module load MATLAB-R2014a
matlab -nosplash -nodisplay <<HERE
<MATPATH>

    
% add path for parrun
oldpath = textscan('$DIR', '%s', 'Delimiter', '/');
newpath = horzcat(oldpath{:});
bin_path = sprintf('%s/', newpath{1:end-1});
addpath(bin_path);
    
    
    
% make sure each run has different random number stream
mydate = date;
RandStream.setGlobalStream(RandStream('mt19937ar','seed', sum(100*clock)));
defaultStream = RandStream.getGlobalStream;
savedState = defaultStream.State;
fname = sprintf('randState.mat');
save(fname, 'mydate', 'savedState');
cd $DIR
run('${PROGRAM}');
quit;
HERE

echo ending job \$SHELLSCRIPT
echo JOB_ID \$JOB_ID
date
echo "done"
THERE

chmod a+x $SHELLSCRIPT
bash $SHELLSCRIPT > $LOGFILE

BASH
}elsif($bqs eq "SLURM"){
$sh_script.= <<'BASH';
cat <<THERE > $SHELLSCRIPT
#! /bin/bash -l

echo starting job \$SHELLSCRIPT
echo JOB_ID \$SLURM_JOBID
echo WORKDIR \$SLURM_SUBMIT_DIR
date
cd $DIR

module load matlab\/R2014a
matlab -nosplash -nodisplay <<HERE
<MATPATH>

    
% add path for parrun
oldpath = textscan('$DIR', '%s', 'Delimiter', '/');
newpath = horzcat(oldpath{:});
bin_path = sprintf('%s/', newpath{1:end-1});
addpath(bin_path);
    
    
% make sure each run has different random number stream
mydate = date;
RandStream.setGlobalStream(RandStream('mt19937ar','seed', sum(100*clock)));
defaultStream = RandStream.getGlobalStream;
savedState = defaultStream.State;
fname = sprintf('randState.mat');
save(fname, 'mydate', 'savedState');
cd $DIR
run('${PROGRAM}');
quit;
HERE

echo ending job \$SHELLSCRIPT
echo JOB_ID \$SLURM_JOBID
date
echo "done"
THERE

chmod a+x $SHELLSCRIPT
bash $SHELLSCRIPT > $LOGFILE


BASH
}

my $pathText;
if($bqs eq "SGE"){
# CVX is already setup on solomon and proclus
$pathText.=<<MATLAB;

cvx_setup;
cvx_quiet(true)
% Find and add Sedumi Path for machines that have CVX installed
cvx_path = which('cvx_setup.m');
oldpath = textscan( cvx_path, '%s', 'Delimiter', '/');
newpath = horzcat(oldpath{:});
sedumi_path = [sprintf('%s/', newpath{1:end-1}) 'sedumi'];
addpath(sedumi_path)
    


% MOSEK
addpath '~/mosek/7/toolbox/r2013a/'

MATLAB
}elsif($bqs eq "SLURM"){
$pathText.=<<MATLAB;
addpath '~/BPDN/CVX/cvx' -begin
cvx_setup;
cvx_quiet(true);


    

    
addpath '~/mosek/7/toolbox/r2013a/'
    
    
MATLAB

}






$sh_script =~ s|<PROGRAM>|$program|;
$sh_script =~ s|<DATE>|$date|;
$sh_script =~ s|<COUNTER>|$counter|;
$sh_script =~ s|<MATPATH>|$pathText|;
$sh_script =~ s|<remote_path>|$remote_path|;
    

return $sh_script;
}

























#====================================
#       USEFUL SUBs
#====================================
        





sub matlab_var
{
    my ($s) = @_;
    
    if(&CJ::isnumeric($s)){
        return "[$s]";
    }else{
        return "\'$s\'";
    }
    
}




sub read_matlab_index_set
{
    my ($forline, $TOP) = @_;
    
    chomp($forline);
    $forline = &uncomment_matlab_line($forline);   # uncomment the line so you dont deal with comments. easier parsing;
    
    
    # split at equal sign.
    my @myarray    = split(/\s*=\s*/,$forline);
    my @tag     = split(/\s/,$myarray[0]);
    my $idx_tag = $tag[-1];
    
    
    
    
    my $range;
    # The right of equal sign
    my $right  = $myarray[1];
    
    # see if the forline contains :
    if($right =~ /.*\:.*/){
   
        my @rightarray = split( /\s*:\s*/, $right, 2 );
        
        my $low =$rightarray[0];
        if(! &CJ::isnumeric($low) ){
         &CJ::err("The lower limit of for MUST be numeric for this version of clusterjob\n");
        }
        
        
        
            # exit on unallowed structure
            if ($rightarray[1] =~ /.*:.*/){
                &CJ::err("Sorry!...structure 'for i=1:1:3' is not allowed in clusterjob. Try rewriting your script using 'for i = 1:3' structure\n");
            }
        
        
        
        if($rightarray[1] =~ /\s*length\(\s*(.+?)\s*\)/){
            
            #CASE i = 1:length(var);
            # find the variable;
            my ($var) = $rightarray[1] =~ /\s*length\(\s*(.+?)\s*\)/;
            my $this_line = &grep_var_line($var,$TOP);
            
            
            #extract the range
            my @this_array    = split(/\s*=\s*/,$this_line);
            
            my $numbers;
            if($this_array[1] =~ /\[\s*(.+?)\s*\]/){
                ($numbers) = $this_array[1] =~ /\[\s*(.+?)\s*\]/;
            }else{
                # FUTURE_REV_ADD
                &CJ::err("MATLAB structure '$this_line ' not currently supported for parrun.");
            }
            
            
            
            @vals = split(/,|;/,$numbers);
            
            my $high = 1+$#vals;
            @range = ($low..$high);
            $range = join(',',@range);
            
        }elsif($rightarray[1] =~ /\s*(\D+).*/) {
            print "$rightarray[1]"."\n";
            # CASE i = 1:L
            # find the variable;
            my($var) = $rightarray[1] =~ /\s*(\D+).*/;
            my $this_line = &grep_var_line($var,$TOP);
            
            #extract the range
            my @this_array    = split(/\s*=\s*/,$this_line);
            my ($high) = $this_array[1] =~ /\[?\s*(\d+)\s*\]?/;
            @range = ($low..$high);
            $range = join(',',@range);

        }elsif($rightarray[1] =~ /.*(\d+).*/){
            # CASE i = 1:10
            my ($high) = $rightarray[1] =~ /\s*(\d+).*/;
            @range = ($low..$high);
            $range = join(',',@range);

        }else{
            &CJ::err("strcuture of for loop not recognized by clusterjob. try rewriting your for loop using 'i = 1:10' structure");
            
        }
        

    }

    return ($idx_tag, $range);
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


sub uncomment_matlab_line{
    my ($line) = @_;
    $line =~ s/^(?:(?!\').)*\K\%(.*)//;
    return $line;
}








