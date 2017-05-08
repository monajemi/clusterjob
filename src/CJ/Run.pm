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




# class constructor
sub new {
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





sub SERIAL_DEPLOY_RUN{

my $self = shift;
    
#===================
#  Check connection
#===================
    &CJ::CheckConnection($self->{machine});

#====================================
#        CREATE PID
#====================================
my $ssh             = &CJ::host($self->{machine});
my $account         = $ssh->{account};
my $bqs             = $ssh->{bqs};
my $remotePrefix    = $ssh->{remote_repo};
my $date = &CJ::date();

# PID
my $sha_expr = "$CJID:$localHostName:$self->{program}:$account:$date->{datestr}";
my $pid  = sha1_hex("$sha_expr");
my $short_pid = substr($pid, 0, 8);  # we use an 8 character abbrviation


# Check to see if the file and dep folder exists
&CJ::err("$self->{path}/$self->{program} not found") if(! -e "$self->{path}/$self->{program}" );
&CJ::err("Dependency folder $self->{path}/$self->{dep_folder} not found") if(! -d "$self->{path}/$self->{dep_folder}" );


#=======================================
#    BUILD DOCSTRING
#    WE NAME THE REMOTE FOLDERS
#    BY PROGRAM AND PID
#    EXAMPLE : MaxEnt/20dd3203e29ec29...
#=======================================

my ($program_name,$ext) = &CJ::remove_extension($self->{program});

my $programType;
if(lc($ext) eq "m"){
    $programType = "matlab";
}elsif(lc($ext) eq "r"){
    $programType = "R";
}else{
    CJ::err("Code type .$ext is not recognized");
}

CJ::message("$self->{runflag}"."ing [$self->{program}] on [$self->{machine}]");
&CJ::message("Sending from: $self->{path}");



my $localDir       = "$localPrefix/"."$program_name";
my $local_sep_Dir = "$localDir/" . "$pid"  ;
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


# cp code
my $cmd = "cp $self->{path}/$self->{program} $local_sep_Dir/";
    &CJ::my_system($cmd,$self->{verbose});
# cp dependencies
$cmd   = "cp -r $self->{dep_folder}/* $local_sep_Dir/";
&CJ::my_system($cmd,$self->{verbose});



#=====================
#  REMOTE DIRECTORIES
#=====================
my $remoteDir       = "$remotePrefix/"."$program_name";
my $remote_sep_Dir = "$remoteDir/" . "$pid"  ;

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



############# Specific to runSerial
CJ::message("Creating reproducible script(s) reproduce_$self->{program}");
CJ::Scripts::build_reproducible_script($programType,$self->{program}, $local_sep_Dir,$self->{runflag});

#===========================================
# BUILD A BASH WRAPPER
#===========================================



my $sh_script = &CJ::Scripts::make_shell_script($ssh,$self->{program},$pid,$bqs);
my $local_sh_path = "$local_sep_Dir/bashMain.sh";
&CJ::writeFile($local_sh_path, $sh_script);

# Build master-script for submission
my $master_script;
    $master_script =  &CJ::Scripts::make_master_script($master_script,$self->{runflag},$self->{program},$date,$pid,$bqs,$self->{submit_defaults},$self->{qSubmitDefault},$remote_sep_Dir,$self->{qsub_extra});



my $local_master_path="$local_sep_Dir/master.sh";
&CJ::writeFile($local_master_path, $master_script);


#==============================================
#    PROPAGATE THE FILES AND RUN ON CLUSTER
#==============================================
my $tarfile="$pid".".tar.gz";
$cmd="cd $localDir; tar  --exclude '.git' --exclude '*~' --exclude '*.pdf'  -czf $tarfile $pid/  ; rm -rf $local_sep_Dir  ; cd $self->{path}";
&CJ::my_system($cmd,$self->{verbose});

# create remote directory  using outText
$cmd = "ssh $account 'echo `$outText` '  ";
&CJ::my_system($cmd,$self->{verbose});

&CJ::message("Sending package \033[32m$short_pid\033[0m");
# copy tar.gz file to remoteDir
$cmd = "rsync -avz  ${localDir}/${tarfile} ${account}:$remoteDir/";
&CJ::my_system($cmd,$self->{verbose});


&CJ::message("Submitting job");
$cmd = "ssh $account 'source ~/.bashrc;cd $remoteDir; tar -xzvf ${tarfile} ; cd ${pid}; bash -l master.sh > $remote_sep_Dir/qsub.info; sleep 3'";
&CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "deploy");



# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
$cmd = "rsync -avz $account:$qsubfilepath  $info_dir";
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
    local_host    => ${localHostName},
    date          => ${date},
    machine       => $self->{machine},
    account       => ${account},
    local_prefix  => ${localPrefix},
    local_path    => "${localDir}/${pid}",
    remote_prefix => ${remotePrefix},
    remote_path   => "${remoteDir}/${pid}",
    job_id        => $job_id,
    bqs           => $bqs,
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

#===================
#  Check connection
#===================
&CJ::CheckConnection($self->{machine});

#====================================
#        CREATE PID
#====================================
my $ssh             = &CJ::host($self->{machine});
my $account         = $ssh->{account};
my $bqs             = $ssh->{bqs};
my $remotePrefix    = $ssh->{remote_repo};
my $date = &CJ::date();

# PID
my $sha_expr = "$CJID:$localHostName:$self->{program}:$account:$date->{datestr}";   #####FIX
my $pid  = sha1_hex("$sha_expr");
my $short_pid = substr($pid, 0, 8);  # we use an 8 character abbrviation


# Check to see if the file and dep folder exists
&CJ::err("$self->{path}/$self->{program} not found") if(! -e "$self->{path}/$self->{program}" );
&CJ::err("Dependency folder $self->{path}/$self->{dep_folder} not found") if(! -d "$self->{path}/$self->{dep_folder}" );


#=======================================
#    BUILD DOCSTRING
#    WE NAME THE REMOTE FOLDERS
#    BY PROGRAM AND PID
#    EXAMPLE : MaxEnt/20dd3203e29ec29...
#=======================================

my ($program_name,$ext) = &CJ::remove_extension($self->{program});

my $programType;
if(lc($ext) eq "m"){
    $programType = "matlab";
}elsif(lc($ext) eq "r"){
    $programType = "R";
}else{
    CJ::err("Code type .$ext is not recognized");
}

CJ::message("$self->{runflag}"."ing [$self->{program}] on [$self->{machine}]");
&CJ::message("Sending from: $self->{path}");



my $localDir       = "$localPrefix/"."$program_name";
my $local_sep_Dir = "$localDir/" . "$pid"  ;
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


# cp code
my $cmd = "cp $self->{path}/$self->{program} $local_sep_Dir/";
&CJ::my_system($cmd,$self->{verbose});
# cp dependencies
$cmd   = "cp -r $self->{dep_folder}/* $local_sep_Dir/";
&CJ::my_system($cmd,$self->{verbose});



#=====================
#  REMOTE DIRECTORIES
#=====================
my $remoteDir       = "$remotePrefix/"."$program_name";
my $remote_sep_Dir = "$remoteDir/" . "$pid"  ;

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



############# Specific to Parrrun
# read the script, parse it out and
# find the for loops
my $matlab = CJ::Matlab->new($self->{path},$self->{program});
my $parser = $matlab->parse();
my ($idx_tags,$ranges) = $matlab->findIdxTagRange($parser,$self->{verbose});

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
$extra->{bqs}= $bqs;
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
my $tarfile="$pid".".tar.gz";
$cmd="cd $localDir; tar --exclude '.git' --exclude '*~' --exclude '*.pdf' -czf  $tarfile $pid/   ; rm -rf $local_sep_Dir  ; cd $self->{path}";
&CJ::my_system($cmd,$self->{verbose});


# create remote directory  using outText
$cmd = "ssh $account 'echo `$outText` '  ";
&CJ::my_system($cmd,$self->{verbose});

&CJ::message("Sending package \033[32m$short_pid\033[0m");
# copy tar.gz file to remoteDir
$cmd = "rsync -arvz  ${localDir}/${tarfile} ${account}:$remoteDir/";
&CJ::my_system($cmd,$self->{verbose});


&CJ::message("Submitting job(s)");
my $wait = int($totalJobs/300) + 2 ; # add more wait time for large jobs so the other server finish writing.
$cmd = "ssh $account 'source ~/.bashrc;cd $remoteDir; tar -xzf ${tarfile} ; cd ${pid}; bash -l master.sh > $remote_sep_Dir/qsub.info; sleep $wait'";
&CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "pardeploy");



# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
$cmd = "rsync -avz $account:$qsubfilepath  $info_dir/";
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
    local_host    => ${localHostName},
    date          => ${date},
    machine       => $self->{machine},
    account       => ${account},
    local_prefix  => ${localPrefix},
    local_path    => "${localDir}/${pid}",
    remote_prefix => ${remotePrefix},
    remote_path   => "${remoteDir}/${pid}",
    job_id        => $job_id,
    bqs           => $bqs,
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
