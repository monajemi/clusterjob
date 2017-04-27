#/usr/bin/perl -w
#
# Copyright (c) 2015 Hatef Monajemi (monajemi@stanford.edu)
# visit www.clsuetrjob.org

use strict;
use FindBin qw($Bin);
use lib "$Bin";  #for testing
use lib "$Bin/external/firebase/lib";  
use lib "$Bin/external/ouch/lib"; 
use Firebase; 
use Ouch;
use File::chdir;
use CJ;          # contains essential functions
use CJ::CJVars;  # contains global variables of CJ
use CJ::Matlab;  # Contains Matlab related subs
use CJ::Get;     # Contains Get related subs
use CJ::Scripts; # Contains shell scripts
use Getopt::Declare;
use Data::Dumper;
use Term::ReadLine;
use JSON::PP;
use Digest::SHA qw(sha1_hex); # generate hexa-decimal SHA1 PID
#use Term::ANSIColor qw(:constants); # for changing terminal text colors
#use Term::ReadKey;

use vars qw( $submit_defaults $qSubmitDefault $sync_status $message $dep_folder $verbose $log_script $text_header_lines $show_tag $log_tag $force_tag $qsub_extra $cmdline);  # options


$::VERSION = &CJ::version_info();


#==========================================
#    Get the command line history
#==========================================
my $cmd    = `ps -o args $$ | grep CJ.pl`;
my @cmd = split(/\s/,$cmd);
$cmdline = "$cmd[0] "." $cmd[1]";
foreach ( @ARGV ) {
    $cmdline .= /\s/ ?   " \"" . $_ . "\"":     " "   . $_;
}
my $cjcmd0 = $cmd[2];chomp($cjcmd0);

# Send error if the agent isn't initialized
if( (!-d "$info_dir" || !defined($AgentID)) & ($cjcmd0 ne "init") ){
	&CJ::err(" This CJ agent is not initialized. Please initiate it by 'cj init'");
}



#=========================================
#         INITIALIZE VARIABLEs
#=========================================

$message           = "";
$dep_folder        = ".";
$verbose           = 0;         # default - redirect to CJlog
$text_header_lines = undef;
$show_tag          = "program";
$qsub_extra        = "";
$log_tag           = "all";
$force_tag         = 0;
$log_script        = undef;
$sync_status 	   = 0;
$qSubmitDefault    = 1;

#=========================================
#        CJ SUMBMIT DEFAULTS
#=========================================

$submit_defaults = &CJ::submit_defaults();



if( -d "$info_dir" ){
#=========================================
# refresh CJlog before declaring options.
# it keeps updated for each new run
&CJ::my_system("rm $CJlog") unless (! -f $CJlog);
#=========================================


# Dont sync if the command is one of these.
my @nosync_cmds = qw ( init who help -help -h -Help -HELP prompt version -v install-update);
my %nosync = map { $_ => 1 } @nosync_cmds;




if($CJKEY && (!exists($nosync{$cjcmd0})) ){	
		&CJ::add_agent_to_remote();  # if there is no agent, add it.
		$sync_status = &CJ::AutoSync();
}

}



my $spec = <<'EOSPEC';
      prompt 	    opens CJ prompt command [undocumented]
                     {defer{cj_prompt}}
      hi	    prints out CJ welcome [undocumented]                     
		     {defer{cj_heart}}
      nihao	    [ditto]  [undocumented]
      mimi	    print out mimi    [undocumented] 
{print $/;print $"x(15&ord), "Mimi", $/x/\D/ for'3h112a05e0n1l2j4f6b9'=~/./g; print $/;}
     -help 	      Show usage information [undocumented]
                    {defer{&CJ::add_cmd($cmdline);$self->usage(0);exit;}}
     help  	 	  [ditto]  [undocumented]

     -Help  	 	  [ditto]  [undocumented]
     -HELP		  [ditto]  [undocumented]
     -version		Show version info [undocumented]
                    {defer{&CJ::add_cmd($cmdline);$self->version(0);}}
     -Version		  [ditto] [undocumented]
      version		  [ditto] [undocumented]
      Version		  [ditto] [undocumented]
     -v 	          [ditto] [undocumented]
     --v[erbose]	                                  verbose mode [nocase]
                                                              {$verbose=1}
     --no-submit-default	                          turns off default submit parameters [nocase]
                                                              {$qSubmitDefault=0}
     --err[or]	                                          error tag for show [nocase] [requires: show]
                                                              {$show_tag="error"}
     --less      	                                  less tag for show [nocase]  [requires: show]
                                                               {$show_tag="less";}
     --ls      	                                          list tag for show [nocase]  [requires: show]
                                                               {$show_tag="ls";}
     --clean      	                                  show cleaned packages in log [nocase]  [requires: log]
                                                               {$log_tag="showclean";}
     --f[orce]     	                                  force an action [nocase]  [requires: reduce]
														       {$force_tag=1;}															   
     --script [=] <pattern>	                          shows log of specific script [requires: log]
                                                               {$log_script=$pattern;}
     --header [=] <num_lines:+i>	                  number of header lines for reducing text files [requires: reduce]
                                                               {$text_header_lines=$num_lines;}
     -dep          <dep_path>		                  dependency folder path [nocase]
                                                                {$dep_folder=$dep_path}
     -m            <msg>	                          reminder message
                                                                {$message=$msg}
     -mem          <memory>	                          memory requested [nocase]
                                                                {$submit_defaults->{'mem'}=$memory}
     -runtime      <r_time>	                          run time requested (default=48:00:00) [nocase]
                                                                {$submit_defaults->{'runtime'}=$r_time}
     -alloc[ate]   <resources>	                          machine specific allocation [nocase]
                                                                {$qsub_extra=$resources}
     init 	    					  initiates CJ installation [nocase]
               							{defer{CJ::init}}
     sync 	                                          force sync [nocase]
		                				{defer{CJ::sync_forced($sync_status)}}								
     who 	                                          prints out user and agent info [nocase]
     install-update	                                  updates installation to the most recent commit on GitHub [nocase]
     log [<argin>]	                                  log  -n|all|pid [nocase]
                                                                {defer{&CJ::add_cmd($cmdline); &CJ::show_log($argin,$log_tag,$log_script) }}
     hist[ory]    [<argin>]	                          history of runs -n|all 
                                                                {defer{&CJ::add_cmd($cmdline); &CJ::show_history($argin) }}
     cmd          [<argin>]	                          command history -n|all [nocase]
                                                                {defer{ &CJ::show_cmd_history($argin) }}
     clean        [<pid>]		                  clean certain package [nocase]
                                                                {defer{ &CJ::add_cmd($cmdline); &CJ::clean($pid,$verbose); }}
     state        [<pid> [[/] [<counter>]]]	          state of package [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::get_print_state($pid,$counter) }}
     info         [<pid>]	                          info of certain package [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::show_info($pid); }}
     show         [<pid> [[/] [<counter>] [[/] <file>]] ]	  show program/error of certain package [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::show($pid,$counter,$file,$show_tag) }}
     ls          [<pid> [[/] [<counter>]] ]	  	  shortcut for '--ls show' [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::show($pid,$counter,"","ls") }}
     less        [<pid> [[/] [<counter>] [[/] <file>]] ]	  shortcut for '--less show' [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::show($pid,$counter,$file,"less") }}
     rerun        [<pid> [[/] [<counter>...]]]	          rerun certain (failed) job [nocase]
                                                                 {defer{&CJ::add_cmd($cmdline);&CJ::rerun($pid,\@counter,$submit_defaults,$qSubmitDefault,$qsub_extra,$verbose) }}
     run          <code> <cluster>	                  run code on the cluster [nocase] [requires: -m]
                                                                 {my $runflag = "run";
                                                                 {defer{&CJ::add_cmd($cmdline); run($cluster,$code,$runflag,$qsub_extra)}}
                                                                 }
     deploy       <code> <cluster>	                  deploy code on the cluster [nocase] [requires: -m]
                                                                {my $runflag = "deploy";
                                                                {defer{&CJ::add_cmd($cmdline);run($cluster,$code,$runflag,$qsub_extra)}}
                                                                }
     parrun       <code> <cluster>	                  parrun code on the cluster [nocase] [requires: -m]
                                                                {my $runflag = "parrun";
                                                                {defer{&CJ::add_cmd($cmdline);run($cluster,$code,$runflag,$qsub_extra)}}
                                                                }
     pardeploy    <code> <cluster>	                  pardeploy code on the cluster [nocase] [requires: -m]
                                                               {my $runflag = "pardeploy";
                                                                {defer{&CJ::add_cmd($cmdline);run($cluster,$code,$runflag,$qsub_extra)}}
                                                               }
     reduce       <filename> [<pid>...] 	                  reduce results of parrun [nocase]
                                                              {defer{&CJ::add_cmd($cmdline);&CJ::Get::reduce_results(\@pid,$filename,$verbose,$text_header_lines,$force_tag)}}
     gather       <pattern>  <dir_name> [<pid>]	          gather results of parrun [nocase]
                                                              {defer{&CJ::add_cmd($cmdline);&CJ::Get::gather_results($pid,$pattern,$dir_name,$verbose)}}
     get          [<pid> [/] [<subfolder>]]	          bring results (fully/partially) back to local machine [nocase]
                                                             {defer{&CJ::add_cmd($cmdline);&CJ::Get::get_results($pid,$subfolder,$verbose)}}
     summary      <cluster>	                          gives a summary of the number of jobs on particlur cluster with their states [nocase]
                                                              {defer{&CJ::add_cmd($cmdline); &CJ::get_summary($cluster)}}
     save         <pid> [<path>]	                  save a package in path [nocase]
                                                              {defer{&CJ::add_cmd($cmdline);  &CJ::save_results($pid,$path,$verbose)}}
     @<cmd_num:+i>	                                  re-executes a previous command avaiable in command history [nocase]
                                                               {defer{&CJ::reexecute_cmd($cmd_num,$verbose) }}
     @$	                                                  re-executes the last command avaiable in command history [nocase]
                                                               {defer{&CJ::reexecute_cmd("",$verbose) }}
     <unknown>...	                                  unknown arguments will be send to bash [undocumented]
                                                               {defer{my $cmd = join(" ",@unknown); system($cmd);}}

EOSPEC

my $opts = Getopt::Declare->new($spec);

if($opts->{'install-update'}){
	my $star_line = '*' x length($install_dir);
    # make sure s/he really want a deletion
	CJ::message("This update results in cloning the newest version of ClusterJob in");
	CJ::message("$star_line",1);
	CJ::message("$install_dir",1);
	CJ::message("$star_line",1);
	CJ::message("The newest version may not be compatible with your old data structure",1);
	CJ::message("It is recommended that you backup your old installation before this action.",1);
    CJ::message("Are you sure you want to update your installation? Y/N",1);
    my $yesno =  <STDIN>; chomp($yesno);
    
	exit unless (lc($yesno) eq "y" or lc($yesno) eq "yes");
    CJ::message("Updating CJ installation...");
	my $date = CJ::date();
	my $datetag = $date->{year}-$date->{month}-$date->{day};
	# update installation
	my $cmd = "cd /tmp && curl -sL  https://github.com/monajemi/clusterjob/tarball/master | tar -zx -";  
	   $cmd .= "&& mv monajemi-clusterjob-* clusterjob-$datetag";
	   $cmd .= "&& cp -r /tmp/clusterjob-$datetag/src $install_dir/";
	   $cmd .= "&& cp -r /tmp/clusterjob-$datetag/example $install_dir/";
	   $cmd .= "&& cp -r /tmp/clusterjob-$datetag/INSTALL $install_dir/";
	   $cmd .= "&& cp -r /tmp/clusterjob-$datetag/LICENSE $install_dir/";
	   $cmd .= "&& cp -r /tmp/clusterjob-$datetag/README.md $install_dir/";
	   $cmd .= "&& rm -rf /tmp/clusterjob-$datetag";  		
	   CJ::my_system($cmd,$verbose);  
       CJ::message("Installation updated.");
	   
	   exit;	
}

if($opts->{who})
{
	print "      user : \033[32m$CJID\033[0m\n";
	print "      agent: \033[32m$AgentID\033[0m\n";
}

#    print "$opts->{'-m'}\n";
#    print "$opts->{'-mem'}\n";
#    print "$text_header_lines\n";
#$opts->usage();



sub cj_heart{
    
    my @myString = split //,'cjccjjccjcjcjcjcjcjj'	;
    my @myChr	 = split //, '4g143d07g0o1m2k4g6c8';
    
    my $counter = 0 ;
    print $/, " "x4;
    foreach my $chr (@myChr){
        
        my $space = ord($chr) % 16;
        print $" x $space , $myString[$counter];
        print $/, " "x4 if ($chr =~ /\D/);
        $counter = $counter + 1;
    }
    
    print "\n";
    print "\n";
}







#==========================
#   prompt
#==========================
sub cj_prompt{
	
	local $CWD ;     # This is local to prompt. When prompt is exited, we are back to where we were. 
    my $COLOR = "\033[47;30m";
    my $RESET = "\033[0m";
    
    #my $prompt = "${COLOR}[$localHostName:$localUserName] CJ>$RESET ";

    my $prompt = "[$localHostName:$localUserName] CJ> ";
    print  "$::VERSION\n \n \n";
    
    
    #my $promptsize = `echo -n \"$prompt\" | wc -c | tr -d " "`;
    
    #$promptsize = $promptsize+1;  # I add one white space
   

    my $term = Term::ReadLine->new('CJ shell');
    #$term->ornaments(0);  # disable ornaments.
    
    
    my $exit = 0;
    my @exitarray= qw(exit q quit end);
    my %exithash;
    $exithash{$_} = 1 for (@exitarray);
    
    while (!exists $exithash{my $input = $term->readline($prompt)}) {
        #print WHITE, ON_BLACK $prompt, RESET . " ";
        
		if($input =~ m/\bprompt\b/){
			next;
		}elsif($input =~ m/\bcd\b/){
			$input =~ s/cd//g;
		    $input =~ s/^\s*|\s*$//g;
			if (-d $input){
			$CWD = $input
			}else{
				print "Can't cd to $input: $!\n";
				next;
			} 
		}else{
	      my $perl = `which perl`; chomp($perl);
	      my $cmd = "$perl $src_dir/CJ.pl" . " $input";
	      system($cmd);
		}	
		    
      
	}
        
}



#========================================================================
#            CLUSTERJOB RUN/DEPLOY/PARRUN
#  ex.  clusterjob run myScript.m sherlock -dep DepFolder -m  "my reminder"
#========================================================================

sub run{
    
    my ($machine,$program, $runflag,$qsub_extra) = @_;	
    my $BASE = `pwd`;chomp($BASE);   # Base is where program lives!
 
#===================
#  Check connection
#===================
my $ssh      = &CJ::host($machine);
my $account  = $ssh->{account};
my $bqs      = $ssh->{bqs};
my $remotePrefix    = $ssh->{remote_repo};
my $date = &CJ::date();

# create remote directory  using outText
my $check = $date->{year}.$date->{month}.$date->{min}.$date->{sec};
my $sshres = `ssh $account 'mkdir CJsshtest_$check; rm -rf CJsshtest_$check; exit;'  2>&1`;
&CJ::err("Cannot connect to $account: $sshres") if($sshres);
    

#====================================
#         DATE OF CALL
#====================================

# PID
my $sha_expr = "$CJID:$localHostName:$program:$account:$date->{datestr}";
my $pid  = sha1_hex("$sha_expr");
my $short_pid = substr($pid, 0, 8);  # we use an 8 character abbrviation


# Check to see if the file and dep folder exists
&CJ::err("$BASE/$program not found") if(! -e "$BASE/$program" );    
&CJ::err("Dependency folder $BASE/$dep_folder not found") if(! -d "$BASE/$dep_folder" );    


#=======================================
#    BUILD DOCSTRING
#    WE NAME THE REMOTE FOLDERS
#    BY PROGRAM AND PID
#    EXAMPLE : MaxEnt/20dd3203e29ec29...
#=======================================

my ($program_name,$ext) = &CJ::remove_extension($program);

my $programType;
if(lc($ext) eq "m"){
	$programType = "matlab";
}elsif(lc($ext) eq "r"){
	$programType = "R";
}else{
	CJ::err("Code type .$ext is not recognized");
}

CJ::message("$runflag"."ing [$program] on [$machine]");
&CJ::message("Sending from: $BASE");



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
my $cmd = "cp $BASE/$program $local_sep_Dir/";
&CJ::my_system($cmd,$verbose);	
# cp dependencies
my $cmd   = "cp -r $dep_folder/* $local_sep_Dir/";
&CJ::my_system($cmd,$verbose);


    
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

    

if ($runflag eq "deploy" || $runflag eq "run"){

    
CJ::message("Creating reproducible script(s) reproduce_$program");
CJ::Scripts::build_reproducible_script($programType,$program, $local_sep_Dir, $runflag);
    
#===========================================
# BUILD A BASH WRAPPER
#===========================================
    
  

my $sh_script = &CJ::Scripts::make_shell_script($ssh,$program,$pid,$bqs);
my $local_sh_path = "$local_sep_Dir/bashMain.sh";
&CJ::writeFile($local_sh_path, $sh_script);

# Build master-script for submission
my $master_script;
$master_script =  &CJ::Scripts::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$submit_defaults,$qSubmitDefault,$remote_sep_Dir,$qsub_extra);
    
    

my $local_master_path="$local_sep_Dir/master.sh";
&CJ::writeFile($local_master_path, $master_script);


#==============================================
#    PROPAGATE THE FILES AND RUN ON CLUSTER
#==============================================
my $tarfile="$pid".".tar.gz";
my $cmd="cd $localDir; tar  --exclude '.git' --exclude '*~' --exclude '*.pdf'  -czf $tarfile $pid/  ; rm -rf $local_sep_Dir  ; cd $BASE";
&CJ::my_system($cmd,$verbose);

# create remote directory  using outText
my $cmd = "ssh $account 'echo `$outText` '  ";
&CJ::my_system($cmd,$verbose);

&CJ::message("Sending package \033[32m$short_pid\033[0m");
# copy tar.gz file to remoteDir
my $cmd = "rsync -avz  ${localDir}/${tarfile} ${account}:$remoteDir/";
&CJ::my_system($cmd,$verbose);


&CJ::message("Submitting job");
my $cmd = "ssh $account 'source ~/.bashrc;cd $remoteDir; tar -xzvf ${tarfile} ; cd ${pid}; bash -l master.sh > $remote_sep_Dir/qsub.info; sleep 3'";
&CJ::my_system($cmd,$verbose) unless ($runflag eq "deploy");
    

 
# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
my $cmd = "rsync -avz $account:$qsubfilepath  $info_dir";
&CJ::my_system($cmd,$verbose) unless ($runflag eq "deploy");

    
    
    
    
    
my $job_id="";
if($runflag eq "run"){
# read run info
my $local_qsub_info_file = "$info_dir/"."qsub.info";
    
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
    #&CJ::my_system($cmd,$verbose);
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
machine       => ${machine},
account       => ${account},
local_prefix  => ${localPrefix},
local_path    => "${localDir}/${pid}",
remote_prefix => ${remotePrefix},
remote_path   => "${remoteDir}/${pid}",
job_id        => $job_id,
bqs           => $bqs,
save_prefix   => ${savePrefix},
save_path     => "${saveDir}/${pid}",
runflag       => $runflag,
program       => $program,
message       => $message,
};	

# add_record locally
&CJ::add_record($runinfo);
# write runinfo to FireBaee as well
&CJ::write2firebase($pid,$runinfo,$date->{epoch},0);

    
}elsif($runflag eq "parrun"  || $runflag eq "pardeploy"){
#==========================================
#   clusterjob parrun myscript.m DEP
#   this implements parrallel for in perl 
#   so for each grid point, we will have 
#   one separate job
#==========================================

# read the script, parse it out and
# find the for loops
my $matlab = CJ::Matlab->new($BASE,$program);
my $parser = $matlab->parse();    
my ($idx_tags,$ranges) = $matlab->findIdxTagRange($parser,$verbose);  

# Check that number of jobs doesnt exceed Maximum jobs for user on chosen cluster
# later check all resources like mem, etc. 
my @keys  = keys %$ranges;
my $totalJobs = 1; 
foreach my $i (0..$parser->{nloop}-1){
	my @range = split(',', $ranges->{$keys[$i]}); 
    $totalJobs = (0+@range) * ($totalJobs);
}
my $max_jobs = &CJ::max_jobs_allowed($ssh, $qsub_extra);
&CJ::err("Maximum jobs allowed on $machine ($max_jobs) exceeded by your request ($totalJobs). Rewrite FOR loops to submit in smaller chunks.") unless  ($max_jobs >= $totalJobs);







#Check that user has initialized for loop vars
$matlab->check_initialization($parser,$idx_tags,$verbose);
    
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
$extra->{runflag}= $runflag;
$extra->{program}= $program;
$extra->{date}= $date;
$extra->{pid}= $pid;
$extra->{bqs}= $bqs;
$extra->{submit_defaults}=$submit_defaults;
$extra->{qsub_extra}=$qsub_extra;
$extra->{runtime}=$submit_defaults->{runtime};
$extra->{ssh}=$ssh;
$extra->{qSubmitDefault}=$qSubmitDefault;

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
my $cmd="cd $localDir; tar --exclude '.git' --exclude '*~' --exclude '*.pdf' -czf  $tarfile $pid/   ; rm -rf $local_sep_Dir  ; cd $BASE";
&CJ::my_system($cmd,$verbose);


# create remote directory  using outText
my $cmd = "ssh $account 'echo `$outText` '  ";
&CJ::my_system($cmd,$verbose);

&CJ::message("Sending package \033[32m$short_pid\033[0m");
# copy tar.gz file to remoteDir
my $cmd = "rsync -arvz  ${localDir}/${tarfile} ${account}:$remoteDir/";
&CJ::my_system($cmd,$verbose);


&CJ::message("Submitting job(s)");
my $wait = int($totalJobs/300) + 2 ; # add more wait time for large jobs so the other server finish writing.
my $cmd = "ssh $account 'source ~/.bashrc;cd $remoteDir; tar -xzf ${tarfile} ; cd ${pid}; bash -l master.sh > $remote_sep_Dir/qsub.info; sleep $wait'";
&CJ::my_system($cmd,$verbose) unless ($runflag eq "pardeploy");
 

    
# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
my $cmd = "rsync -avz $account:$qsubfilepath  $info_dir/";
&CJ::my_system($cmd,$verbose) unless ($runflag eq "pardeploy");
    

    
my $job_ids;
my $job_id;
if($runflag eq "parrun"){
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
    #&CJ::my_system($cmd,$verbose);
    
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
machine       => ${machine},
account       => ${account},
local_prefix  => ${localPrefix},
local_path    => "${localDir}/${pid}",
remote_prefix => ${remotePrefix},
remote_path   => "${remoteDir}/${pid}",
job_id        => $job_id,
bqs           => $bqs,
save_prefix   => ${savePrefix},
save_path     => "${saveDir}/${pid}",
runflag       => $runflag,
program       => $program,
message       => $message,
};
    	

&CJ::add_record($runinfo);
    
# write runinfo to FB as well
&CJ::write2firebase($pid,$runinfo, $date->{epoch},0);

}else{
&CJ::err("Runflag $runflag was not recognized");
}


exit 0;
    
    
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















