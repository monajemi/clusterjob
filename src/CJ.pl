#/usr/bin/perl
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
#   -h   <NUMBER>
# ex: perl CJ.pl (DEPLOY|RUN) MACHINE PROGRAM -dep DEP_FOLDER -mem "10G" -m "REMINDER"
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
# To get info of a package
#   clusterjob info <PACKAGE>
#
# To show the program a package ran
#   cluetrjob show <PACKAGE>
#
# To get state of the last instance
#   clusterjob state
#
# To clean the last instance
#   clusterjob clean
#
# Copyright 2014 Hatef Monajemi (monajemi@stanford.edu)


use lib '/Users/hatef/github_projects/clusterjob/src';  #for testing

use CJ;          # contains essential functions
use CJ::CJVars;  # contains global variables of CJ
use CJ::Matlab;  # Contains Matlab related subs
use CJ::Get;     # Contains Get related subs
use Getopt::Declare;
use vars qw($message $mem $dep_folder $verbose $text_header_lines);  # options
$::VERSION  ="\n\n          This is Clusterjob (CJ) verion 1.1.0";
$::VERSION .=  "\n          Copyright (c) 2015 Hatef Monajemi (monajemi\@stanford.edu)";
$::VERSION .="\n\n          CJ may be copied only under the terms and conditions of";
$::VERSION .=  "\n          the GNU General Public License, which may be found in the CJ";
$::VERSION .=  "\n          source code. For more info please visit";
$::VERSION .=  "\n          https://github.com/monajemi/clusterjob";







#=========================================
# refresh CJlog before declaring options.
# it keeps updated for each new run
&CJ::my_system("rm $CJlog");
#=========================================


#=========================================
# create .info directory
mkdir "$install_dir/.info" unless (-d "$install_dir/.info");

# create history file if it does not exist
if( ! -f $history_file ){
    &CJ::touch($history_file);
    my $header = sprintf("%-15s%-15s%-21s%-10s%-15s%-20s%30s", "count", "date", "package", "action", "machine", "job_id", "message");
    &CJ::add_to_history($header);
}


# create run_history file if it does not exit
# this file contains more information about a run
# such as where it is saved, etc.

&CJ::touch($run_history_file) unless (-f $run_history_file);
#=========================================





#====================================
#         READ FLAGS
#====================================
$dep_folder = ".";
$mem        = "8G";      # default memeory
$message    = "";        # default message
$verbose    = 0;	 # default - redirect to CJlog
$text_header_lines = undef;

my $spec = <<'EOSPEC';
   --v[erbose]	                         verbose mode [nocase]
                                             {$verbose=1}
   --header [=] <num_lines>	         number of header lines for reducing text files
                                          {$text_header_lines=$num_lines;}
   -dep          <dep_path>		 dependency folder path [nocase]
                                              {$dep_folder=$dep_path}
   -m            <msg>	                 reminder message
                                              {$message=$msg}
   -mem          <memory>	         memory requested [nocase]
                                              {$mem=$memory}
   log          [<argin>]	         historical info -n|pkg|all [nocase]
                                              {defer{ &CJ::show_history($argin) }}
   history      [<argin>]              	         [ditto]  
   clean        [<pkg>]	                 clean certain package [nocase]
                                              {defer{ &CJ::clean($pkg,$verbose); }}
   state        [<pkg>]	                 state of package [nocase]
                                              {defer{ &CJ::get_state($pkg) }}
   info         [<pkg>]	                 info of certain package [nocase]
                                              {defer{ &CJ::show_info($pkg); }}
   show         [<pkg>]	                 show program of certain package [nocase]
                                              {defer{ &CJ::show_program($pkg) }}
   run          <code> <cluster>	 run code on the cluster [nocase]
                                              {my $runflag = "run";
                                                  {defer{run($cluster,$code,$runflag)}}
                                               }
   parrun       <code> <cluster>	 parrun code on the cluster [nocase]
                                              {my $runflag = "parrun";
                                                  {defer{run($cluster,$code,$runflag)}}
                                               }
   reduce       <filename> [<pkg>] 	 reduce results of parrun [nocase]
                                                  {defer{&CJ::Get::reduce_results($pkg,$filename,$verbose,$text_header_lines)}}
   get          [<pkg>]	                 bring results back to local machine [nocase]
                                                  {defer{&CJ::Get::get_results($pkg,$verbose)}}
   save         <pkg> [<path>]	         save a package in path [nocase]
                                                  {defer{&CJ::save_results($pkg,$path,$verbose)}}


EOSPEC

my $opts = Getopt::Declare->new($spec);


#    print "$opts->{'-m'}\n";
#    print "$opts->{'-mem'}\n";
#   print "$text_header_lines\n";
#$opts->usage();





#========================================================================
#            CLUSTERJOB RUN/DEPLOY/PARRUN
#  ex.  clusterjob run myScript.m sherlock -dep DepFolder
#  ex.  clusterjob run myScript.m sherlock -dep DepFolder -m  "my reminder"
#========================================================================

sub run{
    
    my ($machine,$program, $runflag) = @_;
    
    CJ::message("$runflag"."ing [$program] on [$machine]");
   
    
#====================================
#         DATE OF CALL
#====================================
my $date = &CJ::date();
# Find the last number
my $lastnum=`grep "." $history_file | tail -1  | awk \'{print \$1}\' `;
my ($hist_date, $time) = split('\_', $date);
my $history = sprintf("%-15u%-15s",$lastnum+1, $hist_date );
    
    
    
    
$short_message = substr($message, 0, 30);

    
    
my $ssh      = &CJ::host($machine);
my $account  = $ssh->{account};
my $bqs      = $ssh->{bqs};
my $remotePrefix    = $ssh->{remote_repo};



#check to see if the file and dep folder exists
    
my $BASE = `pwd`;chomp($BASE);   # Base is where program lives!
if(! -e "$BASE/$program" ){
 &CJ::err("$BASE/$program not found");
}
if(! -d "$BASE/$dep_folder" ){
    &CJ::err("Dependency folder $BASE/$dep_folder not found");
}
    
&CJ::message("Base-dir=$BASE");


#=======================================
#       BUILD DOCSTRING
#       WE NAME THE REMOTE FOLDERS
#       BY PROGRAM AND DATE
#       EXAMPLE : MaxEnt/2014DEC02_1426
#=======================================



my $program_name   = &CJ::remove_extention($program);
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
&CJ::my_system($cmd,$verbose);

 
   
   
    
#=====================
#  REMOTE DIRECTORIES
#=====================
my $program_name    = &CJ::remove_extention($program);
my $remoteDir       = "$remotePrefix/"."$program_name";
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
&CJ::my_system($cmd,$verbose);


#===========================================
# BUILD A BASH WRAPPER
#===========================================
    
  

my $sh_script = make_shell_script($program,$date,$bqs);
$local_sh_path = "$local_sep_Dir/bashMain.sh";
&CJ::writeFile($local_sh_path, $sh_script);

# Build master-script for submission
my $master_script;
$master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$bqs,$mem,$remote_sep_Dir);
    
    

my $local_master_path="$local_sep_Dir/master.sh";
&CJ::writeFile($local_master_path, $master_script);





#==================================
#       PROPAGATE THE FILES
#       AND RUN ON CLUSTER
#==================================
my $tarfile="$date".".tar.gz";
my $cmd="cd $localDir; tar -czf $tarfile $date/  ; rm -rf $local_sep_Dir  ; cd $BASE";
&CJ::my_system($cmd,$verbose);

    
# create remote directory  using outText
my $cmd = "ssh $account 'echo `$outText` '  ";
&CJ::my_system($cmd, $verbose);


&CJ::message("Sending package");
# copy tar.gz file to remoteDir
my $cmd = "rsync -avz  ${localDir}/${tarfile} ${account}:$remoteDir/";
&CJ::my_system($cmd,$verbose);


&CJ::message("Submitting package ${date}");
my $cmd = "ssh $account 'source ~/.bashrc;cd $remoteDir; tar -xzvf ${tarfile} ; cd ${date}; bash master.sh > $remote_sep_Dir/qsub.info; sleep 2'";
&CJ::my_system($cmd,$verbose) unless ($runflag eq "deploy");
    

 
# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
my $cmd = "rsync -avz $account:$qsubfilepath  $install_dir/.info";
&CJ::my_system($cmd,$verbose) unless ($runflag eq "deploy");

    
    
    
    
    
my $job_id;
if($runflag eq "run"){
# read run info
my $local_qsub_info_file = "$install_dir/.info/"."qsub.info";
open my $FILE, '<', $local_qsub_info_file;
my $job_id_info = <$FILE>;
close $FILE;
    
chomp($job_id_info);
($job_id) = $job_id_info =~ /(\d+)/; # get the first string of integer, i.e., job_id
CJ::message("Job-id: $job_id");
    
#delete the local qsub.info after use
my $cmd = "rm $local_qsub_info_file";
&CJ::my_system($cmd,$verbose);
    
    

$history .= sprintf("%-21s%-10s%-15s%-20s%-30s",$date, $runflag, $machine, $job_id, $short_message);
&CJ::add_to_history($history);
#=================================
# store tarfile info for deletion
# when needed
#=================================

    
}else{
$job_id ="";
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
    $_ = &CJ::Matlab::uncomment_matlab_line($_);
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

    my ($idx_tag, $range) = &CJ::Matlab::read_matlab_index_set($_, $TOP,$verbose);
    
    push @idx_tags, $idx_tag;
    push @ranges, $range;
    
}

    
    
#==============================================
#        MASTER SCRIPT
#==============================================

    
    
    
    
my $nloops = $#forlines_idx_set+1;

my $counter = 0;   # counter gives the total number of jobs submited: (1..$counter)

my $master_script;
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
                    my $sh_script = make_par_shell_script($program,$date,$bqs,$counter, $remote_par_sep_dir);
                    $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
                    &CJ::writeFile($local_sh_path, $sh_script);
                
                $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$bqs,$mem,$remote_sep_Dir,$counter);
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
                my $sh_script = make_par_shell_script($program,$date,$bqs,$counter, $remote_par_sep_dir);
                $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
                &CJ::writeFile($local_sh_path, $sh_script);
                
                $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$bqs,$mem,$remote_sep_Dir,$counter);
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
                my $sh_script = make_par_shell_script($program,$date,$bqs,$counter, $remote_par_sep_dir);
                $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
                &CJ::writeFile($local_sh_path, $sh_script);
                
                
                $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$bqs,$mem,$remote_sep_Dir,$counter);
                
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
&CJ::my_system($cmd,$verbose);
    
    
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
&CJ::my_system($cmd,$verbose);


# create remote directory  using outText
my $cmd = "ssh $account 'echo `$outText` '  ";
&CJ::my_system($cmd,$verbose);


&CJ::message("Sending package");
# copy tar.gz file to remoteDir
my $cmd = "rsync -avz  ${localDir}/${tarfile} ${account}:$remoteDir/";
&CJ::my_system($cmd,$verbose);


&CJ::message("Submitting job(s)");
my $cmd = "ssh $account 'source ~/.bashrc;cd $remoteDir; tar -xzf ${tarfile} ; cd ${date}; bash -l master.sh > $remote_sep_Dir/qsub.info; sleep 2'";
&CJ::my_system($cmd,$verbose) unless ($runflag eq "pardeploy");
 

    
# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
my $cmd = "rsync -avz $account:$qsubfilepath  $install_dir/";
&CJ::my_system($cmd,$verbose) unless ($runflag eq "pardeploy");
    

    
my @job_ids;

if($runflag eq "parrun"){
    # read run info
        my $local_qsub_info_file = "$install_dir/"."qsub.info";
        open my $FILE, '<', $local_qsub_info_file;
    
    
        while(<$FILE>){
        my $job_id_info = $_;
        chomp($job_id_info);
        ($this_job_id) = $job_id_info =~/(\d+)/; # get the first string of integer, i.e., job_id
        push @job_ids, $this_job_id;
        }
        close $FILE;

$job_id = join(',', @job_ids);

    
&CJ::message("Job-ids: $job_ids[0]-$job_ids[$#job_ids]");
    
#delete the local qsub.info after use
my $cmd = "rm $local_qsub_info_file";
&CJ::my_system($cmd,$verbose);
    
    


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




    
    exit 0;
    
    
}
    
    



#====================================
#       BUILD A BASH WRAPPER
#====================================

sub make_shell_script
    {
my ($program,$date,$bqs) = @_;

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
my ($program,$date,$bqs,$counter,$remote_path) = @_;

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
        





#sub matlab_var
#{
#    my ($s) = @_;
#
#   if(&CJ::isnumeric($s)){
#        return "[$s]";
#    }else{
#        return "\'$s\'";
#    }
#
#}















