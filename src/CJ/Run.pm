package CJ::Run;
# This is the Matlab class of CJ 
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu) 

use strict;
use warnings;
use CJ;
use CJ::CJVars;
use Data::Dumper;
use feature 'say';
use Digest::SHA qw(sha1_hex); # generate hexa-decimal SHA1 PID



####################
# class constructor
sub new {
####################
 	my $class= shift;
 	my ($path,$program,$machine, $runflag,$dep_folder,$message,$qsub_extra, $qSubmitDefault, $submit_defaults,  $verbose) = @_;
	
	my $self = bless {
		path    => $path,
		program => $program,
        machine => $machine,
        runflag => $runflag,
        dep_folder => $dep_folder,
        qsub_extra => $qsub_extra,
        verbose    => $verbose,
        qSubmitDefault => $qSubmitDefault,
        submit_defaults => $submit_defaults,
        message => $message
	}, $class;
	return $self;
}





###########################################
# This should be called at the beginning of
# run for all run options. Common to all
sub run_common{
###########################################
    my ($self) = @_;

#  Check connection
&CJ::CheckConnection($self->{machine});

#  CREATE PID
my $ssh             = &CJ::host($self->{machine});
my $date = &CJ::date();

#  PID
my $sha_expr = "$CJID:$localIP:$self->{program}:$ssh->{account}:$date->{datestr}";
my $pid  = sha1_hex("$sha_expr");
my $short_pid = &CJ::short_pid($pid);  # we use an 8 character abbrviation


#  Check to see if the file and dep folder exists
&CJ::err("$self->{path}/$self->{program} not found") if(! -e "$self->{path}/$self->{program}" );
&CJ::err("Dependency folder $self->{path}/$self->{dep_folder} not found") if(! -d "$self->{path}/$self->{dep_folder}" );


#=======================================
#    BUILD DOCSTRING
#    WE NAME THE REMOTE FOLDERS
#    BY PROGRAM AND PID
#    EXAMPLE : MaxEnt/20dd3203e29ec29...
#=======================================

my ($program_name,$ext) = &CJ::remove_extension($self->{program});
my $program_type = CJ::program_type($self->{program});

CJ::message("$self->{runflag}"."ing [$self->{program}] on [$self->{machine}]");
&CJ::message("Sending from: $self->{path}");



my $localDir       = "$localPrefix/"."$program_name";
my $local_sep_Dir  = "$localDir/" . "$pid"  ;
my $saveDir        = "$savePrefix"."$program_name";


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


# cp code
my $cmd = "cp $self->{path}/$self->{program} $local_sep_Dir/";
&CJ::my_system($cmd,$self->{verbose});
# cp dependencies
$cmd   = "cp -r $self->{dep_folder}/* $local_sep_Dir/";
&CJ::my_system($cmd,$self->{verbose});


#=====================
#  REMOTE DIRECTORIES
#=====================
my $remoteDir       = "$ssh->{remote_repo}/"."$program_name";
my $remote_sep_Dir  = "$remoteDir/" . "$pid"  ;

# for creating remote directory
my $outText;
if($ssh->{bqs} eq "SLURM"){
$outText=<<TEXT;
#!/bin/bash -l
if [ ! -d "$ssh->{remote_repo}" ]; then
mkdir $ssh->{remote_repo}
fi
mkdir $remoteDir
TEXT
}elsif($ssh->{bqs} eq "SGE"){
$outText=<<TEXT;
#!/bin/bash
#\$ -cwd
#\$ -S /bin/bash
if [ ! -d "$ssh->{remote_repo}" ]; then
mkdir $ssh->{remote_repo}
fi
mkdir $remoteDir
TEXT
}else{
&CJ::err("unknown BQS");
}

return ($date,$ssh,$pid,$short_pid,$program_type,$localDir,$local_sep_Dir,$remoteDir,$remote_sep_Dir,$saveDir,$outText);
}











#########################################################
#   clusterjob run myscript.m -dep DEP -m "message"
#   Serial run
sub SERIAL_DEPLOY_RUN{
#########################################################

my $self = shift;
    
# create directories etc.
my ($date,$ssh,$pid,$short_pid,$program_type,$localDir,$local_sep_Dir,$remoteDir,$remote_sep_Dir,$saveDir,$outText)  = run_common($self);

&CJ::message("Creating reproducible script(s) reproduce_$self->{program}");
    &CJ::CodeObj($local_sep_Dir,$self->{program},$self->{dep_folder})->build_reproducible_script($self->{runflag});

#===========================================
# BUILD A BASH WRAPPER
#===========================================
my $sh_script = &CJ::Scripts::make_shell_script($ssh,$self->{program},$pid,$ssh->{bqs}, $remote_sep_Dir);
my $local_sh_path = "$local_sep_Dir/bashMain.sh";
&CJ::writeFile($local_sh_path, $sh_script);

# Build master-script for submission
my $master_script;
    
# Add installation of anaconda to beginning of master
    #my $master_script = &CJ::insatll_anaconda()
    
    
$master_script = &CJ::Scripts::make_master_script($master_script,$self->{runflag},$self->{program},$date,$pid,$ssh->{bqs},$self->{submit_defaults},$self->{qSubmitDefault},$remote_sep_Dir,$self->{qsub_extra});

my $local_master_path="$local_sep_Dir/master.sh";
&CJ::writeFile($local_master_path, $master_script);


#==============================================
#    PROPAGATE THE FILES AND RUN ON CLUSTER
#==============================================
&CJ::message("Compressing files to propagate...");
    
my $tarfile="$pid".".tar.gz";
my $cmd="cd $localDir; tar  --exclude '.git' --exclude '*~' --exclude '*.pdf'  -czf $tarfile $pid/  ; rm -rf $local_sep_Dir  ; cd $self->{path}";
&CJ::my_system($cmd,$self->{verbose});

# create remote directory  using outText
$cmd = "ssh $ssh->{account} 'echo `$outText` '  ";
&CJ::my_system($cmd,$self->{verbose});

    
    
    
&CJ::message("Sending package \033[32m$short_pid\033[0m");
# copy tar.gz file to remoteDir
$cmd = "rsync -avz  ${localDir}/${tarfile} $ssh->{account}:$remoteDir/";
&CJ::my_system($cmd,$self->{verbose});


&CJ::message("Submitting job");
$cmd = "ssh $ssh->{account} 'source ~/.bashrc; cd $remoteDir; tar -xzvf ${tarfile} ; cd ${pid}; bash -l master.sh > $remote_sep_Dir/qsub.info; sleep 3'";
&CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "deploy");



# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
$cmd = "rsync -avz $ssh->{account}:$qsubfilepath  $info_dir";
&CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "deploy");






my $job_id="";
if($self->{runflag} eq "run"){
    # read run info
    my $local_qsub_info_file = "$info_dir/"."qsub.info";
    my ($job_ids,$errors) = &CJ::read_qsub($local_qsub_info_file);
    $job_id = $job_ids->[0]; # there is only one in this case
    my $numJobs = $#{$job_ids}+1;
    CJ::message("$numJobs job(s) submitted ($job_id)");
    
    foreach my $error (@{$errors}) {
        CJ::warning($error);
    }
    
    #delete the local qsub.info after use
    #my $cmd = "rm $local_qsub_info_file";
    #&CJ::my_system($cmd,$self->{verbose});
}else{
    $job_id ="";
}



my $runinfo={
    pid           => ${pid},
    agent		  => ${AgentID},
    user          => ${CJID},
    local_ip      => ${localIP},
    local_un      => ${localUserName},
    date          => ${date},
    machine       => $self->{machine},
    account       => $ssh->{account},
    local_prefix  => ${localPrefix},
    local_path    => "${localDir}/${pid}",
    remote_prefix => $ssh->{remote_repo},
    remote_path   => "${remoteDir}/${pid}",
    job_id        => $job_id,
    bqs           => $ssh->{bqs},
    save_prefix   => ${savePrefix},
    save_path     => "${saveDir}/${pid}",
    runflag       => $self->{runflag},
    program       => $self->{program},
    message       => $self->{message},
};	

# add_record locally
&CJ::add_record($runinfo);
# write runinfo to FireBaee as well
&CJ::write2firebase($pid,$runinfo,$date->{epoch},0);
}



#========================================================
#   clusterjob parrun myscript.m -dep DEP -m "message"
#   this implements parrallel for in perl
#   so for each grid point, we will have
#   one separate job
#========================================================
sub PAR_DEPLOY_RUN{
my $self = shift;

# create directories etc.
my ($date,$ssh,$pid,$short_pid,$program_type,$localDir,$local_sep_Dir,$remoteDir,$remote_sep_Dir,$saveDir,$outText)  = run_common($self);


    
    
# read the script, parse it out and
# find the for loops
my $codeobj            = &CJ::CodeObj($self->{path},$self->{program},$self->{dep_folder});
my $parser             = $codeobj->parse();
my ($idx_tags,$ranges) = $codeobj->findIdxTagRange($parser,$self->{verbose});

    
# Check that number of jobs doesnt exceed Maximum jobs for user on chosen cluster
# later check all resources like mem, etc.
my @keys  = keys %$ranges;
my $totalJobs = 1;
foreach my $i (0..$parser->{nloop}-1){
    my @range = split(',', $ranges->{$keys[$i]});
    $totalJobs = (0+@range) * ($totalJobs);
}
    
    
my $max_jobs = &CJ::max_jobs_allowed($ssh,$self->{qsub_extra});
&CJ::err("Maximum jobs allowed on $self->{machine} ($max_jobs) exceeded by your request ($totalJobs). Rewrite FOR loops to submit in smaller chunks.") unless  ($max_jobs >= $totalJobs);


#Check that user has initialized for loop vars
$codeobj->check_initialization($parser,$idx_tags,$self->{verbose});

#==============================================
#        MASTER SCRIPT
#==============================================

my $nloops = $parser->{nloop};
my $counter = 0;   # counter gives the total number of jobs submited: (1..$counter)
my $extra={};
$extra->{TOP}= $parser->{TOP};
$extra->{FOR}= $parser->{FOR};
$extra->{BOT}= $parser->{BOT};
$extra->{local_sep_Dir}= $local_sep_Dir;
$extra->{remote_sep_Dir}= $remote_sep_Dir;
$extra->{runflag}= $self->{runflag};
$extra->{path}   = $self->{path};  #This is directory from which the code is being called
$extra->{program}= $self->{program};
$extra->{date}= $date;
$extra->{pid}= $pid;
$extra->{bqs}= $ssh->{bqs};
$extra->{submit_defaults}=$self->{submit_defaults};
$extra->{qsub_extra}=$self->{qsub_extra};
$extra->{runtime}=$self->{submit_defaults}->{runtime};
$extra->{ssh}=$ssh;
$extra->{qSubmitDefault}=$self->{qSubmitDefault};

# Recursive loop for arbitrary number of loops.
my $master_script = &CJ::Scripts::build_nloop_master_script($nloops, $idx_tags,$ranges,$extra);

#===================================
# write out master_script
#===================================
my $local_master_path="$local_sep_Dir/master.sh";
&CJ::writeFile($local_master_path, $master_script);


#==================================
#       PROPAGATE THE FILES
#       AND RUN ON CLUSTER
#==================================
&CJ::message("Compressing files to propagate...");
my $tarfile="$pid".".tar.gz";
my $cmd="cd $localDir; tar --exclude '.git' --exclude '*~' --exclude '*.pdf' -czf  $tarfile $pid/   ; rm -rf $local_sep_Dir  ; cd $self->{path}";
&CJ::my_system($cmd,$self->{verbose});

# create remote directory  using outText
$cmd = "ssh $ssh->{account} 'echo `$outText` '  ";
&CJ::my_system($cmd,$self->{verbose});

&CJ::message("Sending package \033[32m$short_pid\033[0m");
# copy tar.gz file to remoteDir
$cmd = "rsync -arvz  ${localDir}/${tarfile} $ssh->{account}:$remoteDir/";
&CJ::my_system($cmd,$self->{verbose});


$self->{runflag} eq "pardeploy" ? &CJ::message("Deployed.") : &CJ::message("Submitting job(s)");
my $wait = int($totalJobs/300) + 2 ; # add more wait time for large jobs.
$wait = $wait > 5 ? $wait: 5;
$cmd = "ssh $ssh->{account} 'source ~/.bashrc;cd $remoteDir; tar -xzf ${tarfile} ; cd ${pid}; bash -l master.sh > $remote_sep_Dir/qsub.info; sleep $wait'";
&CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "pardeploy");



# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
$cmd = "rsync -avz $ssh->{account}:$qsubfilepath  $info_dir/";
&CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "pardeploy");



my $job_ids;
my $job_id;
if($self->{runflag} eq "parrun"){
    # read run info
    my $errors;
    my $local_qsub_info_file = "$info_dir/"."qsub.info";
    ($job_ids,$errors) = &CJ::read_qsub($local_qsub_info_file);
    $job_id = join(',', @{$job_ids});
    my $numJobs = $#{$job_ids}+1;
    
    CJ::message("$numJobs job(s) submitted ($job_ids->[0]-$job_ids->[-1])");
    
    foreach my $error (@{$errors}) {
        CJ::warning($error);
    }
    
    
    #delete the local qsub.info after use
    #my $cmd = "rm $local_qsub_info_file";
    #&CJ::my_system($cmd,$self->{verbose});
    
}else{
    $job_ids = "";
    $job_id = "";
}




my $runinfo={
    pid           => ${pid},
    user          => ${CJID},  # will be changed to CJusername later
    agent		  => ${AgentID},
    local_ip      => ${localIP},
    local_un      => ${localUserName},
    date          => ${date},
    machine       => $self->{machine},
    account       => $ssh->{account},
    local_prefix  => ${localPrefix},
    local_path    => "${localDir}/${pid}",
    remote_prefix => $ssh->{remote_repo},
    remote_path   => "${remoteDir}/${pid}",
    job_id        => $job_id,
    bqs           => $ssh->{bqs},
    save_prefix   => ${savePrefix},
    save_path     => "${saveDir}/${pid}",
    runflag       => $self->{runflag},
    program       => $self->{program},
    message       => $self->{message},
};


&CJ::add_record($runinfo);
&CJ::write2firebase($pid,$runinfo, $date->{epoch},0);  # send to CJ server
}




















#========================================================
#   clusterjob rrun myscript.m -dep DEP -m "message"
#   this implements parrallel for using SLUMR array
#   so for each grid point, we will have
#   one separate job
#   This is very fast in submission as there will be only
#   one submission for multiple jobs
#   This only works in SLURM.
#
#    THIS IS INCOMPLETE. NEED TO ADD
#    compatible ARRAY_BASHMAIN and MASTER
#========================================================
sub SLURM_ARRAY_DEPLOY_RUN{
my $self = shift;

# create directories etc.
my ($date,$ssh,$pid,$short_pid,$program_type,$localDir,$local_sep_Dir,$remoteDir,$remote_sep_Dir,$saveDir,$outText)  = run_common($self);

&CJ::err("RRUN works for SLURM batch queueing system only. Use parrun instead.") unless ($ssh->{bqs} eq "SLURM");
    

# Check max allowable jobs
# read the script, parse it out and
# find the for loops
my $matlab = CJ::Matlab->new($self->{path},$self->{program});
my $parser = $matlab->parse();
my ($idx_tags,$ranges) = $matlab->findIdxTagRange($parser,$self->{verbose});

#  Check that number of jobs doesnt exceed Maximum jobs for user on chosen cluster
#  later check all resources like mem, etc.
my @keys  = keys %$ranges;
my $totalJobs = 1;
foreach my $i (0..$parser->{nloop}-1){
my @range = split(',', $ranges->{$keys[$i]});
$totalJobs = (0+@range) * ($totalJobs);
}
    

# find max array size allowed
my $max_arraySize   = &CJ::max_slurm_arraySize($ssh);
    
#my $max_array_jobs  = &CJ::max_jobs_allowed($ssh,$self->{qsub_extra});

&CJ::err("Maximum jobs allowed in array mode on $self->{machine} ($max_arraySize) exceeded by your request ($totalJobs). Rewrite FOR loops to submit in smaller chunks.") unless  ($max_arraySize >= $totalJobs);
    
# Check that user has initialized for loop vars
$matlab->check_initialization($parser,$idx_tags,$self->{verbose});


    
    
    
#==============================================
#        MASTER SCRIPT
#==============================================

my $nloops = $parser->{nloop};
my $counter = 0;   # counter gives the total number of jobs submited: (1..$counter)
my $extra={};
$extra->{TOP}= $parser->{TOP};
$extra->{FOR}= $parser->{FOR};
$extra->{BOT}= $parser->{BOT};
$extra->{local_sep_Dir}= $local_sep_Dir;
$extra->{remote_sep_Dir}= $remote_sep_Dir;
$extra->{runflag}= $self->{runflag};
$extra->{program}= $self->{program};
$extra->{date}= $date;
$extra->{pid}= $pid;
$extra->{bqs}= $ssh->{bqs};
$extra->{submit_defaults}=$self->{submit_defaults};
$extra->{qsub_extra}=$self->{qsub_extra};
$extra->{runtime}=$self->{submit_defaults}->{runtime};
$extra->{ssh}=$ssh;
$extra->{qSubmitDefault}=$self->{qSubmitDefault};
$extra->{totalJobs}=$totalJobs;
# Recursive loop for arbitrary number of loops.
my $master_script = &CJ::Scripts::build_rrun_master_script($nloops, $idx_tags,$ranges,$extra);
#print $master_script . "\n";
 
#===================================
# write out master_script
#===================================
my $local_master_path="$local_sep_Dir/master.sh";
&CJ::writeFile($local_master_path, $master_script);

#===================================
# write out array_bashMain
#===================================
my $array_bashMain_script = &CJ::Scripts::build_rrun_bashMain_script($extra);
&CJ::writeFile("$local_sep_Dir/array_bashMain.sh", $array_bashMain_script);
#==================================
#       PROPAGATE THE FILES
#       AND RUN ON CLUSTER
#==================================
&CJ::message("Compressing files to propagate...");
    
my $tarfile="$pid".".tar.gz";
my $cmd="cd $localDir; tar --exclude '.git' --exclude '*~' --exclude '*.pdf' -czf  $tarfile $pid/   ; rm -rf $local_sep_Dir  ; cd $self->{path}";
&CJ::my_system($cmd,$self->{verbose});

# create remote directory  using outText
$cmd = "ssh $ssh->{account} 'echo `$outText` '  ";
&CJ::my_system($cmd,$self->{verbose});

&CJ::message("Sending package \033[32m$short_pid\033[0m");
# copy tar.gz file to remoteDir
$cmd = "rsync -arvz  ${localDir}/${tarfile} $ssh->{account}:$remoteDir/";
&CJ::my_system($cmd,$self->{verbose});


&CJ::message("Submitting job(s)");
my $wait = int($totalJobs/300) + 2 ; # add more wait time for large jobs so the other server finish writing.
$cmd = "ssh $ssh->{account} 'source ~/.bashrc;cd $remoteDir; tar -xzf ${tarfile} ; cd ${pid}; bash -l master.sh > $remote_sep_Dir/qsub.info; sleep $wait'";
&CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "pardeploy");



# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
$cmd = "rsync -avz $ssh->{account}:$qsubfilepath  $info_dir/";
&CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "pardeploy");



my $job_ids;
my $job_id;
if($self->{runflag} eq "parrun"){
# read run info
my $errors;
my $local_qsub_info_file = "$info_dir/"."qsub.info";
($job_ids,$errors) = &CJ::read_qsub($local_qsub_info_file);
$job_id = join(',', @{$job_ids});
my $numJobs = $#{$job_ids}+1;

CJ::message("$numJobs job(s) submitted ($job_ids->[0]-$job_ids->[-1])");

foreach my $error (@{$errors}) {
    CJ::warning($error);
}


#delete the local qsub.info after use
#my $cmd = "rm $local_qsub_info_file";
#&CJ::my_system($cmd,$self->{verbose});

}else{
$job_ids = "";
$job_id = "";
}




my $runinfo={
pid           => ${pid},
user          => ${CJID},  # will be changed to CJusername later
agent		  => ${AgentID},
local_ip      => ${localIP},
local_un      => ${localUserName},
date          => ${date},
machine       => $self->{machine},
account       => $ssh->{account},
local_prefix  => ${localPrefix},
local_path    => "${localDir}/${pid}",
remote_prefix => $ssh->{remote_repo},
remote_path   => "${remoteDir}/${pid}",
job_id        => $job_id,
bqs           => $ssh->{bqs},
save_prefix   => ${savePrefix},
save_path     => "${saveDir}/${pid}",
runflag       => $self->{runflag},
program       => $self->{program},
message       => $self->{message},
};


&CJ::add_record($runinfo);
&CJ::write2firebase($pid,$runinfo, $date->{epoch},0);  # send to CJ server
}

















1;
