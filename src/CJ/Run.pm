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
 	my ($path,$program,$machine, $runflag,$dep_folder,$message, $qsub_extra, $qSubmitDefault, $submit_defaults, $user_submit_defaults, $verbose, $cj_id) = @_;
	
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
        user_submit_defaults => $user_submit_defaults,
        message => $message,
        cj_id => $cj_id
	}, $class;
    
    $self->_update_qsub_extra();
    
	return $self;
}


##############################################
# if user definded alloc change submit default
sub _update_qsub_extra {
    my $self = shift;
    
    my $ssh = CJ::host($self->{machine});
    if( exists($ssh->{alloc}) and defined($ssh->{alloc}) ){
        if ( $ssh->{'alloc'} !~ /^[\"\'\t\s]*$/ ){
            #print "$ssh->{alloc} exists. I will supply these to qsub\n";
        $self->{qsub_extra} = "$ssh->{alloc} $self->{qsub_extra}"; # append the user defined after default to take effect
        $self->{qSubmitDefault}=0;   # turn off CJ's default vals if users gives an alloc
        }
    }
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
CJ::message("initiating package \033[32m$short_pid\033[0m");


#  Check to see if the file and dep folder exists
&CJ::err("$self->{path}/$self->{program} not found") if(! -e "$self->{path}/$self->{program}" );
if(defined($self->{dep_folder})){
    &CJ::err("Dependency folder $self->{path}/$self->{dep_folder} not found") if(! -d "$self->{path}/$self->{dep_folder}" );
}

#=======================================
#    BUILD DOCSTRING
#    WE NAME THE REMOTE FOLDERS
#    BY PROGRAM AND PID
#    EXAMPLE : MaxEnt/20dd3203e29ec29...
#=======================================

my ($program_name,$ext) = &CJ::remove_extension($self->{program});
my $program_type = CJ::program_type($self->{program});


CJ::message("$self->{runflag}"."ing [$self->{program}] on [$self->{machine}] with:");


# whatever is in qsub_extra
&CJ::message("alloc: $self->{qsub_extra}",1);
# whatever user has asked to change in defaults
if(keys(%{$self->{user_submit_defaults}}) > 0){
    my $str="";
    while ( my ($key, $value) = each (%{$self->{user_submit_defaults}})){
        $str = $str."$key=$value ";
    }
    &CJ::message("user : $str",1);
}

# CJ will be active in determining:
if ( not (defined($ssh->{alloc}) and $ssh->{alloc} !~/^\s*$/) ) {
    my $str="";
    while ( my ($key, $value) = each (%{$self->{submit_defaults}})){
        $str = $str."$key=$value " if (!exists($self->{user_submit_defaults}->{$key}));
    }
    &CJ::message("cj   : $str",1) if ($str ne "");
}






&CJ::message("sending from: $self->{path}");



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

# Install stuff for CJ Hub in the background FIXME: Ask if this should go here
CJ::Hub->new()->setup($self->{machine});

# cp code
my $cmd = "cp $self->{path}/$self->{program} $local_sep_Dir/";
# FIXME: Get metadata of ExpRaw
&CJ::message("Meta Data For EXP RAW $local_sep_Dir\n\n\n");
&CJ::my_system($cmd,$self->{verbose});
# cp dependencies
$cmd   = "cp -r $self->{dep_folder}/* $local_sep_Dir/" unless not defined($self->{dep_folder});
my $filename = 'report.txt';
&CJ::my_system("touch $local_sep_Dir/expr.txt", $self->{verbose});
# FIXME: Implement using CJ writeFile
open(my $fh, '>', "$local_sep_Dir/expr.txt") or die "Could not open file '$local_sep_Dir/expr.txt' $!";
    print $fh "$self->{program}\n";
    print $fh "$self->{dep_folder}/*" unless not defined($self->{dep_folder});
close $fh;
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

    
    
    
    
    
## Check setup for the program:
$self->setup_conda_venv($pid,$ssh) if($program_type eq 'python');
$self->setup_R_env($pid,$ssh) if ($program_type eq 'R');
$self->check_LMOD_avail($pid,$ssh) if ($program_type eq 'matlab');
    
    
    
    
    
    
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
my $codeobj = &CJ::CodeObj($local_sep_Dir,$self->{program}, $self->{dep_folder});
$codeobj->build_reproducible_script($self->{runflag});
    
#===========================================
# BUILD A BASH WRAPPER
#===========================================
my $sh_script = &CJ::Scripts::make_shell_script($ssh, $self->{program}, $pid, $ssh->{bqs}, $remote_sep_Dir);
my $local_sh_path = "$local_sep_Dir/bashMain.sh";
&CJ::writeFile($local_sh_path, $sh_script);
    
    
# Build master-script for submission
my $tarfile="$pid".".tar.gz";
my $master_script;
    
$master_script = &CJ::Scripts::make_master_script($master_script,$self->{runflag},$self->{program},$date,$pid,$ssh,$self->{submit_defaults},$self->{qSubmitDefault},$self->{user_submit_defaults},$remote_sep_Dir,$self->{qsub_extra},$tarfile,$self->{cj_id});


my $local_master_path = "$local_sep_Dir/master.sh";
&CJ::writeFile($local_master_path, $master_script);

    
    
    

#==============================================
#    PROPAGATE THE FILES AND RUN ON CLUSTER
#==============================================
&CJ::message("compressing files to propagate...");

my $cmd="cd $localDir; tar  --exclude '.git' --exclude '*~' --exclude '*.pdf'  -czf $tarfile $pid/  ; rm -rf $local_sep_Dir  ; cd $self->{path}";
&CJ::my_system($cmd,$self->{verbose});
    
   
    
    
    my $pkgsize = CJ::getFileSize("${localDir}/${tarfile}") ;
    my $pkgsize_human=&CJ::formatFileSize($pkgsize);
    &CJ::message("sending \033[32m$pkgsize_human\033[0m to: $self->{machine}:$remoteDir");
    
# create remote directory  using outText
$cmd = "ssh $ssh->{account} 'echo `$outText` '  ";
&CJ::my_system($cmd,$self->{verbose});
    
# copy tar.gz file to remoteDir
$cmd = "rsync -avz ${localDir}/${tarfile} $ssh->{account}:$remoteDir/";
# Copy the upload script
# $cmd = "rsync -avz $localDir/server_script/upload_script.pm $ssh->{account}:$remoteDir/";
&CJ::my_system($cmd,$self->{verbose});
    
&CJ::message("extracting package...");
$cmd = "ssh $ssh->{account} 'source ~/.bashrc; cd $remoteDir; tar -xzf ${tarfile} --exclude=\"._*\";exit 0'";
&CJ::my_system($cmd,$self->{verbose});
    
    
$self->{runflag} eq "deploy" ? &CJ::message("Deployed.") : &CJ::message("Submitting job...");
$cmd = "ssh $ssh->{account} 'source ~/.bashrc && cd $remoteDir/${pid} && bash -l master.sh > $remote_sep_Dir/qsub.info && sleep 3'";
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
    
    $self->_checkSubmitSuccess($job_ids,$ssh,$local_sep_Dir,$remote_sep_Dir,$errors);
    
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
    submit_defaults => $self->{'submit_defaults'},
    user_submit_defaults => $self->{'user_submit_defaults'},
    alloc         => $self->{'qsub_extra'},
    total_jobs    => 1,
    pkgsize       => $pkgsize,
    #exp_meta      => hash with program_name and dep
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
$extra->{user_submit_defaults}=$self->{user_submit_defaults};
$extra->{qsub_extra}=$self->{qsub_extra};
#$extra->{runtime}=$self->{submit_defaults}->{runtime};
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
&CJ::message("compressing files to propagate...");
my $tarfile="$pid".".tar.gz";
my $cmd="cd $localDir; tar --exclude '.git' --exclude '*~' --exclude '*.pdf' -czf  $tarfile $pid/   ; rm -rf $local_sep_Dir  ; cd $self->{path}";
&CJ::my_system($cmd,$self->{verbose});

# create remote directory  using outText
$cmd = "ssh $ssh->{account} 'echo `$outText` '  ";
&CJ::my_system($cmd,$self->{verbose});


    
my $pkgsize = CJ::getFileSize("${localDir}/${tarfile}") ;
my $pkgsize_human=&CJ::formatFileSize($pkgsize);
&CJ::message("sending \033[32m$pkgsize_human\033[0m to: $self->{machine}:$remoteDir");
    
#&CJ::message("sending package \033[32m$short_pid\033[0m");
# copy tar.gz file to remoteDir
$cmd = "rsync -arvz  ${localDir}/${tarfile} $ssh->{account}:$remoteDir/";
&CJ::my_system($cmd,$self->{verbose});

    
&CJ::message("extracting package...");
$cmd = "ssh $ssh->{account} 'source ~/.bashrc; cd $remoteDir; tar -xzf ${tarfile} --exclude=\"._*\";exit 0'";
&CJ::my_system($cmd,$self->{verbose});
    
    

$self->{runflag} eq "pardeploy" ? &CJ::message("Deployed.") : &CJ::message("Submitting job(s)");
my $wait = int($totalJobs/300) + 2 ; # add more wait time for large jobs.
$wait = $wait > 5 ? $wait: 5;
$cmd = "ssh $ssh->{account} 'source ~/.bashrc && cd $remoteDir/${pid} && bash -l master.sh > $remote_sep_Dir/qsub.info && sleep $wait'";
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
    
    
    $self->_checkSubmitSuccess($job_ids,$ssh,$local_sep_Dir,$remote_sep_Dir,$errors);
    

    $job_id = join(',', @{$job_ids});
    my $numJobs = $#{$job_ids}+1;
    
    CJ::message("$numJobs/$totalJobs job(s) submitted ($job_ids->[0]-$job_ids->[-1])");
    
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
    submit_defaults => $self->{'submit_defaults'},
    user_submit_defaults => $self->{'user_submit_defaults'},
    alloc         => $self->{'qsub_extra'},
    total_jobs    => $totalJobs,
    pkgsize       => $pkgsize,
};


&CJ::add_record($runinfo);
&CJ::write2firebase($pid,$runinfo, $date->{epoch},0);  # send to CJ server
}




sub _checkSubmitSuccess{

    my ($self,$job_ids,$ssh,$local_sep_Dir,$remote_sep_Dir,$errors) = @_;
    
    # in case we dont get job ID
    if( !defined($job_ids->[0]) || $job_ids->[0] =~ m/^\s*$/ ){
        #print "\_$job_ids->[0]\_\n";
        
        #delete remote directories
        my $local_clean     = "$local_sep_Dir\*";
        my $remote_clean    = "$remote_sep_Dir\*";
        my $cmd = "rm -rf $local_clean; ssh $ssh->{account} 'rm -rf $remote_clean' " ;
        &CJ::my_system($cmd,$self->{verbose});
        foreach my $error (@{$errors}) {
            CJ::warning($error);
        }
        CJ::err('Job submission failed. try running with --v option for more info');
    }

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

    
    
    # for python only; check conda exists on the cluster and setup env
    $self->setup_conda_venv($pid,$ssh) if($program_type eq 'python');
    
    
  
    
    
    
    
    
    
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
    

# find max array size allowed
my $max_arraySize   = &CJ::max_slurm_arraySize($ssh);
    
#my $max_array_jobs  = &CJ::max_jobs_allowed($ssh,$self->{qsub_extra});

&CJ::err("Maximum jobs allowed in array mode on $self->{machine} ($max_arraySize) exceeded by your request ($totalJobs). Rewrite FOR loops to submit in smaller chunks.") unless  ($max_arraySize >= $totalJobs);
    
# Check that user has initialized for loop vars
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


    my $pkgsize = CJ::getFileSize("${localDir}/${tarfile}") ;
    my $pkgsize_human=&CJ::formatFileSize($pkgsize);
    &CJ::message("sending \033[32m$pkgsize_human\033[0m to: $self->{machine}:$remoteDir");
   
    
# copy tar.gz file to remoteDir
$cmd = "rsync -arvz  ${localDir}/${tarfile} $ssh->{account}:$remoteDir/";
&CJ::my_system($cmd,$self->{verbose});

&CJ::message("Extracting package...");
$cmd = "ssh $ssh->{account} 'source ~/.bashrc; cd $remoteDir; tar -xzf ${tarfile} --exclude=\"._*\";exit 0'";
&CJ::my_system($cmd,$self->{verbose});
 

$self->{runflag} eq "rdeploy" ? &CJ::message("Deployed.") : &CJ::message("Submitting jobs...");
my $wait = int($totalJobs/300) + 2 ; # add more wait time for large jobs so the other server finish writing.
$cmd = "ssh $ssh->{account} 'source ~/.bashrc && cd $remoteDir/${pid} && bash -l master.sh > $remote_sep_Dir/qsub.info && sleep $wait'";
&CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "rdeploy");



# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
$cmd = "rsync -avz $ssh->{account}:$qsubfilepath  $info_dir/";
&CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "pardeploy");


    
    
    
    
    my $array_job_id;
    if($self->{runflag} eq "rrun"){
        # read run info
        my $local_qsub_info_file = "$info_dir/"."qsub.info";
        my ($job_ids,$errors) = &CJ::read_qsub($local_qsub_info_file);
        
        
        $self->_checkSubmitSuccess($job_ids,$ssh,$local_sep_Dir,$remote_sep_Dir,$errors);
        
        
        $array_job_id = $job_ids->[0]; # there is only one in this case
        #my $numJobs = $#{$job_ids}+1;
        CJ::message("$totalJobs job(s) submitted ($array_job_id\_[1-$totalJobs])");
        foreach my $error (@{$errors}) {
            CJ::warning($error);
        }
        #delete the local qsub.info after use
        #my $cmd = "rm $local_qsub_info_file";
        #&CJ::my_system($cmd,$self->{verbose});
    }else{
       $array_job_id ="";
    }
    


my $runinfo={
pid           => ${pid},
user          => ${CJID},
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
job_id        => $array_job_id,
num_tasks     => $totalJobs,                 # This is only for array_jobs
bqs           => $ssh->{bqs},
save_prefix   => ${savePrefix},
save_path     => "${saveDir}/${pid}",
runflag       => $self->{runflag},
program       => $self->{program},
message       => $self->{message},
submit_defaults => $self->{'submit_defaults'},
user_submit_defaults => $self->{'user_submit_defaults'},
alloc         => $self->{'qsub_extra'},
total_jobs    => $totalJobs,
pkgsize       => $pkgsize,
};


&CJ::add_record($runinfo);
&CJ::write2firebase($pid,$runinfo, $date->{epoch},0);  # send to CJ server
}






#########################
sub setup_conda_venv{
#########################
    my ($self,$pid,$ssh) = @_;
    # check to see conda is installed for python jobs
    my $response =`ssh $ssh->{account} 'source ~/.bashrc ; source ~/.bash_profile; which conda' 2>$CJlog_error`;
    if (  $response !~ m/^.*\/bin\/conda$/ ) {
        
        my $app = 'miniconda';
        CJ::message("No conda found on this machine. Do you want me to install '$app' on '$self->{'machine'}'?");
        my $yesno = <STDIN>; chomp($yesno);
        
        if(lc($yesno) eq "y" or lc($yesno) eq "yes"){
            my $force_tag = 1;
            my $q_yesno = 0;# anythin other than 1 will avoid asking the same yesno again
            &CJ::install_software($app,$self->{'machine'}, $force_tag, $q_yesno)
        }elsif(lc($yesno) eq "n" or lc($yesno) eq "no"){
            &CJ::err("CJ cannot find conda required for Python jobs. use 'cj install miniconda $self->{machine}'");
        }else{
            &CJ::message("Unknown response. Please answer by typing Yes/No");
            exit 0;
        }
        
    }
    
    
    # create conda env for python
    
    &CJ::message("Creating/checking conda venv. This may take a while the first time...");

    
    # Build conda-venv-script
    my $conda_venv = "${pid}_conda_venv.sh";
    my  $conda_venv_script = &CJ::Scripts::build_conda_venv_bash($ssh);
    &CJ::writeFile("/tmp/$conda_venv", $conda_venv_script);
    
    
    my $cmd = "scp /tmp/$conda_venv $ssh->{account}:.";
    &CJ::my_system($cmd,$self->{verbose});
    $cmd = "ssh $ssh->{account} 'source ~/.bashrc; bash -l $conda_venv > /tmp/${pid}_conda_env.txt 2>&1; rm $conda_venv'";
    &CJ::my_system($cmd,$self->{verbose}) unless ($self->{runflag} eq "deploy");
    
    # check that installation has been successful
    my $venv = 'CJ_python_venv';
    $response =`ssh $ssh->{account} 'source ~/.bashrc ; source ~/.bash_profile;conda info --envs | grep  $venv' 2>$CJlog_error`;chomp($response);
    if ($response !~ m/$venv/ ){
        &CJ::message("CJ failed to create $venv on $self->{machine}");
        &CJ::message("*********************************************");
        
        $cmd = "ssh $ssh->{account} 'cat /tmp/${pid}_conda_env.txt' ";
        system($cmd);
        exit 1;
    }
    
}





#########################
sub setup_R_env{
    #####################
    my ($self,$pid,$ssh) = @_;
    # check to see wether R exists
    
    # if successful, it will return 'function'
    my $response =`ssh $ssh->{account} "bash -l -c 'type -t module'" 2>$CJlog_error`;
    
    
    if (  $response !~ m/^function$/ ) {
        
        my $app = 'R';
        CJ::message("No LMOD module found on $self->{'machine'} to load '$app'. Do you want CJ to install '$app' on '$self->{'machine'}'?");
        my $yesno = <STDIN>; chomp($yesno);
        
        if(lc($yesno) eq "y" or lc($yesno) eq "yes"){
            my $force_tag = 1;
            my $q_yesno = 0;    # anythin other than 1 will avoid asking the same yesno again
            &CJ::install_software($app, $self->{'machine'}, $force_tag, $q_yesno)
        }elsif(lc($yesno) eq "n" or lc($yesno) eq "no"){
            &CJ::err("CJ cannot find R required for R jobs. use 'cj install R $self->{machine}'");
        }else{
            &CJ::message("Unknown response. Please answer by typing Yes/No");
            exit 0;
        }
        
    }else{
    
        CJ::message("LMOD module found on $self->{'machine'}");
        CJ::message("Testing if module $ssh->{r} is available via LMOD:");
        my $response =`ssh $ssh->{account} 'source ~/.bashrc; source ~/.bash_profile; module load $ssh->{r}' 2>$CJlog_error`;
        if($response =~ /^$/ ){
            CJ::message("$ssh->{r} available.",1);
            CJ::message("Creating personal Rlib dir on remote");
            my $ssh = CJ::host($self->{'machine'});
            my $libpath  = &CJ::r_lib_path($ssh);
            my $outText="[[ ! -d  \"$libpath\"  ]] && mkdir -p $libpath";
            my $cmd = "ssh $ssh->{account} 'echo `$outText` '  ";
            &CJ::my_system($cmd,$self->{verbose});
        }else{
            CJ::message("$ssh->{r} NOT available.",1);
            
            
            my $app = 'R';
            CJ::message("Do you want CJ to install '$app' on '$self->{'machine'}'?",1);
            my $yesno = <STDIN>; chomp($yesno);
            
            if(lc($yesno) eq "y" or lc($yesno) eq "yes"){
                my $force_tag = 1;
                my $q_yesno = 0;    # anythin other than 1 will avoid asking the same yesno again
                &CJ::install_software($app, $self->{'machine'}, $force_tag, $q_yesno)
            }elsif(lc($yesno) eq "n" or lc($yesno) eq "no"){
                &CJ::err("CJ cannot find R required for R jobs. use 'cj install R $self->{machine}'");
            }else{
                &CJ::message("Unknown response. Please answer by typing Yes/No");
                exit 0;
            }

            
        }
        
    
    }
  
return 1;
    
}



########################
sub check_LMOD_avail{
    #####################
    my ($self,$pid,$ssh) = @_;
    
    
    # get app
    my $app = &CJ::program_type($self->{program});
    
    my $module;
    if($app eq 'matlab'){
        $module = $ssh->{'mat'};
    }elsif($app eq 'R'){
        $module = $ssh->{'r'};
    }elsif($app eq 'python'){
        $module = $ssh->{'py'};
    }
    
    
    
    # check to see wether program_type exists on machine
    
    # checking LMOD if successful, it will return 'function'
    my $response =`ssh $ssh->{account} 'source ~/.bashrc; source ~/.bash_profile; type -t module' 2>$CJlog_error`;
    
    
    if (  $response !~ m/^function$/ ) {
        
        CJ::err("No LMOD module found on $self->{'machine'} to load '$app'.");
        
    }else{
        
        CJ::message("LMOD module found on $self->{'machine'}");
        
        CJ::message("Testing if module $module is availbale via LMOD:");
        my $response =`ssh $ssh->{account} 'source ~/.bashrc; source ~/.bash_profile; module load $module' 2>$CJlog_error`;
        if($response =~ /^$/ ){
            CJ::message("$module avilable.",1);
        }else{
            CJ::err("$module NOT avilable.",1);
        }
        
        
    }
    
}



1;
