#/usr/bin/perl -w
#
# Copyright (c) 2015 Hatef Monajemi (monajemi@stanford.edu)

use strict;

use lib '/Users/hatef/github_projects/clusterjob/src';  #for testing
use lib '/Users/hatef/github_projects/clusterjob/src/external/firebase/lib';  
use lib '/Users/hatef/github_projects/clusterjob/src/external/ouch/lib'; 
use Firebase; 
use Ouch;


use File::chdir;
use CJ;          # contains essential functions
use CJ::CJVars;  # contains global variables of CJ
use CJ::Matlab;  # Contains Matlab related subs
use CJ::Get;     # Contains Get related subs
use Getopt::Declare;
use Data::Dumper;
#use Term::ReadKey;
use Term::ReadLine;
use JSON::PP;
#use Term::ANSIColor qw(:constants); # for changing terminal text colors
use Digest::SHA qw(sha1_hex); # generate hexa-decimal SHA1 PID
use vars qw($message $mem $runtime $dep_folder $verbose $log_script $text_header_lines $show_tag $log_tag $qsub_extra $cmdline);  # options

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
if( (! -d "$info_dir") & ($cjcmd0 ne "init") ){
	&CJ::err(" This CJ agent is not initialized. Please initiate it by issuing 'cj init'");
}

if(-d "$info_dir"){
#=========================================
# refresh CJlog before declaring options.
# it keeps updated for each new run
&CJ::my_system("rm $CJlog") unless (! -f $CJlog);
#=========================================

if($CJKEY){	
	&CJ::AutoSync();
	# TO BE DONE: Sync Agent for PIDs that are beyond its current Epoch 
}

}

#====================================
#         READ FLAGS
#====================================
$dep_folder = ".";
$mem        = "8G";      # default memeory
$runtime    = "40:00:00";      # default memeory
$message    = "";        # default message
$verbose    = 0;	     # default - redirect to CJlog
$text_header_lines = undef;
$show_tag          = "program";
$qsub_extra        = "";
$log_tag           = "all";
$log_script        = undef;

my $spec = <<'EOSPEC';
	  init 	    initiates CJ installation [nocase]
               {defer{CJ::init}}
	  sync 	    force sync [nocase]
		                {defer{CJ::sync_forced}}
      prompt 	    opens CJ prompt command [undocumented]
                     {defer{cj_prompt}}
     -help 	  Show usage information [undocumented]
                    {defer{&CJ::add_cmd($cmdline);$self->usage(0);}}
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
     --err[or]	                                          error tag for show [nocase] [requires: show]
                                                              {$show_tag="error"}
     --less      	                                  less tag for show [nocase]  [requires: show]
                                                               {$show_tag="less";}
     --ls      	                                          list tag for show [nocase]  [requires: show]
                                                               {$show_tag="ls";}
     --clean      	                                  show cleaned packages in log [nocase]  [requires: log]
                                                               {$log_tag="showclean";}
     --script [=] <pattern>	                          shows log of specific script [requires: log]
                                                               {$log_script=$pattern;}
     --header [=] <num_lines:+i>	                  number of header lines for reducing text files [requires: reduce]
                                                               {$text_header_lines=$num_lines;}
     -dep          <dep_path>		                  dependency folder path [nocase]
                                                                {$dep_folder=$dep_path}
     -m            <msg>	                          reminder message
                                                                {$message=$msg}
     -mem          <memory>	                          memory requested [nocase]
                                                                {$mem=$memory}
     -runtime      <r_time>	                          run time requested (default=40:00:00) [nocase]
                                                                {$runtime=$r_time}
     -alloc[ate]   <resources>	                          machine specific allocation [nocase]
                                                                {$qsub_extra=$resources}
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
     -ls          [<pid> [[/] [<counter>]] ]	  	  shortcut for '--ls show' [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::show($pid,$counter,"","ls") }}
     -less        [<pid> [[/] [<counter>] [[/] <file>]] ]	  shortcut for '--less show' [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::show($pid,$counter,$file,"less") }}
     rerun        [<pid> [[/] [<counter>...]]]	          rerun certain (failed) job [nocase]
                                                                 {defer{&CJ::add_cmd($cmdline);&CJ::rerun($pid,\@counter,$mem,$runtime,$qsub_extra,$verbose) }}
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
     reduce       <filename> [<pid>] 	                  reduce results of parrun [nocase]
                                                              {defer{&CJ::add_cmd($cmdline);&CJ::Get::reduce_results($pid,$filename,$verbose,$text_header_lines)}}
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


#    print "$opts->{'-m'}\n";
#    print "$opts->{'-mem'}\n";
#    print "$text_header_lines\n";
#$opts->usage();





#==========================
#   prompt
#==========================
sub cj_prompt{
	
	local $CWD ;     # This is local to prompt. When prompt is quit, we are back to where we were. 
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
		    $input =~ s/^\s|\s$//g;
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
#  ex.  clusterjob run myScript.m sherlock -dep DepFolder
#  ex.  clusterjob run myScript.m sherlock -dep DepFolder -m  "my reminder"
#========================================================================

sub run{
    
    my ($machine,$program, $runflag,$qsub_extra) = @_;
    
    my $BASE = `pwd`;chomp($BASE);   # Base is where program lives!
    
    CJ::message("$runflag"."ing [$program] on [$machine]");
   

    
    
#===================
#  Check connection
#===================
my $ssh      = &CJ::host($machine);
my $account  = $ssh->{account};
my $bqs      = $ssh->{bqs};
my $remotePrefix    = $ssh->{remote_repo};

# create remote directory  using outText
my $sshres = `ssh $account 'mkdir /tmp/CJsshtest; rm -r /tmp/CJsshtest'  2>&1`;
&CJ::err("Cannot connect to $account: $sshres") if($sshres);
    
    
#====================================
#         DATE OF CALL
#====================================
my $date = &CJ::date();

    
# TO BE IMPLEMENTED
my $sha_expr = "$CJID:$localHostName:$program:$account:$date->{datestr}";
my $pid  = sha1_hex("$sha_expr");
my $short_pid = substr($pid, 0, 8);  # we use an 8 character abbrviation


#check to see if the file and dep folder exists
    
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
#       BY PROGRAM AND PID
#       EXAMPLE : MaxEnt/20dd3203e29ec295c50334f6082cee98aae8518e
#=======================================



my $program_name   = &CJ::remove_extention($program);
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

    
# cp dependencies
my $cmd   = "cp -r $dep_folder/* $local_sep_Dir/";
&CJ::my_system($cmd,$verbose);


    
#=====================
#  REMOTE DIRECTORIES
#=====================
my $program_name    = &CJ::remove_extention($program);
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

#============================================
#   COPY ALL NECESSARY FILES INTO THE
#    EXPERIMENT FOLDER
#============================================
   


my $cmd = "cp $BASE/$program $local_sep_Dir/";
&CJ::my_system($cmd,$verbose);
    
CJ::message("Creating reproducible script reproducible_$program");
CJ::Matlab::build_reproducible_script($program, $local_sep_Dir, $runflag);
    

    
    
    
    

#===========================================
# BUILD A BASH WRAPPER
#===========================================
    
  

my $sh_script = make_shell_script($ssh,$program,$pid,$bqs);
my $local_sh_path = "$local_sep_Dir/bashMain.sh";
&CJ::writeFile($local_sh_path, $sh_script);

# Build master-script for submission
my $master_script;
$master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$mem,$runtime,$remote_sep_Dir,$qsub_extra);
    
    

my $local_master_path="$local_sep_Dir/master.sh";
&CJ::writeFile($local_master_path, $master_script);





#==================================
#       PROPAGATE THE FILES
#       AND RUN ON CLUSTER
#==================================
my $tarfile="$pid".".tar.gz";
my $cmd="cd $localDir; tar  --exclude '.git' --exclude '*~' --exclude '*.pdf'  -czf $tarfile $pid/  ; rm -rf $local_sep_Dir  ; cd $BASE";
&CJ::my_system($cmd,$verbose);

    
# create remote directory  using outText
my $cmd = "ssh $account 'echo `ls` '  ";
&CJ::my_system($cmd, $verbose);


&CJ::message("Sending package");
# copy tar.gz file to remoteDir
my $cmd = "rsync -avz  ${localDir}/${tarfile} ${account}:$remoteDir/";
&CJ::my_system($cmd,$verbose);


&CJ::message("Submitting package $short_pid");
my $cmd = "ssh $account 'source ~/.bashrc;cd $remoteDir; tar -xzvf ${tarfile} ; cd ${pid}; bash master.sh > $remote_sep_Dir/qsub.info; sleep 2'";
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
    my $job_ids = &CJ::read_qsub($local_qsub_info_file);
    $job_id = $job_ids->[0]; # there is only one in this case
    my $numJobs = $#{$job_ids}+1;
    CJ::message("$numJobs job(s) submitted ($job_id)");
    
#delete the local qsub.info after use
my $cmd = "rm $local_qsub_info_file";
&CJ::my_system($cmd,$verbose);
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


&CJ::add_record($runinfo);

# write runinfo to FireBaee as well
&CJ::write2firebase($pid,$runinfo,$date->{epoch},0);

    
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
    open my $fh, "$scriptfile" or CJ::err("Couldn't open file: $!");
while(<$fh>){
    $_ = &CJ::Matlab::uncomment_matlab_line($_);
    if (!/^\s*$/){
        $script_lines .= $_;
    }
}
close $fh;
    
    # this includes fors on one line
my @lines = split('\n|;\s*(?=for)', $script_lines);

my @forlines_idx_set;
foreach my $i (0..$#lines){
my $line = $lines[$i];
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
my @tags_to_matlab_interpret;
my @forlines_to_matlab_interpret;
    
    
    my @forline_list = split /^/, $FOR;
   
for my $this_forline (@forline_list) {
    
    
    my ($idx_tag, $range) = &CJ::Matlab::read_matlab_index_set($this_forline, $TOP,$verbose);
    
    
    # if we can't establish range, we output undef
    if(defined($range)){
        push @idx_tags, $idx_tag;
        push @ranges, $range;
    }else{
        push @tags_to_matlab_interpret, $idx_tag;
        push @forlines_to_matlab_interpret, $this_forline;
    }
    
}


    
if ( @tags_to_matlab_interpret ) { # if we need to run matlab
    my $range_run_interpret = &CJ::Matlab::run_matlab_index_interpreter(\@tags_to_matlab_interpret,\@forlines_to_matlab_interpret, $TOP, $verbose);
    
    
    for (keys %$range_run_interpret)
    {
    push @idx_tags, $_;
    push @ranges, $range_run_interpret->{$_};
    #print"$_:$range_run_interpret->{$_} \n";
    }
}
    
    
    
#===================================================
#     Check that user has initialized for loop vars
#===================================================
&CJ::Matlab::check_initialization(\@idx_tags,$TOP,$BOT,$verbose);
    
    
    
    
    
    
    
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
                    #     BUILD EXP FOR this (v0)
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
                
                    # build reproducible script for each run
                    CJ::Matlab::build_reproducible_script($program, "$local_sep_Dir/$counter", $runflag);
                
                
                    
                    
                    # build bashMain.sh for each parallel package
                    my $remote_par_sep_dir = "$remote_sep_Dir/$counter";
                    my $sh_script = make_par_shell_script($ssh,$program,$pid,$bqs,$counter,$remote_par_sep_dir);
                    my $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
                    &CJ::writeFile($local_sh_path, $sh_script);
                
                $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$mem,$runtime,$remote_sep_Dir,$qsub_extra,$counter);
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
                # build reproducible script for each run
                CJ::Matlab::build_reproducible_script($program,  "$local_sep_Dir/$counter", $runflag);

                
                
                # build bashMain.sh for each parallel package
                my $remote_par_sep_dir = "$remote_sep_Dir/$counter";
                my $sh_script = make_par_shell_script($ssh,$program,$pid,$bqs,$counter, $remote_par_sep_dir);
                my $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
                &CJ::writeFile($local_sh_path, $sh_script);
                
                $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date, $pid,$bqs,$mem,$runtime,$remote_sep_Dir,$qsub_extra,$counter);
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
                # build reproducible script for each run
                CJ::Matlab::build_reproducible_script($program, "$local_sep_Dir/$counter", $runflag);

                
                
                # build bashMain.sh for each parallel package
                my $remote_par_sep_dir = "$remote_sep_Dir/$counter";
                my $sh_script = make_par_shell_script($ssh,$program,$pid,$bqs,$counter, $remote_par_sep_dir);
                my $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
                &CJ::writeFile($local_sh_path, $sh_script);
                
                
                $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date, $pid,$bqs,$mem,$runtime,$remote_sep_Dir,$qsub_extra,$counter);
                
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
my $cmd = "ssh $account 'source ~/.bashrc;cd $remoteDir; tar -xzf ${tarfile} ; cd ${pid}; bash -l master.sh > $remote_sep_Dir/qsub.info; sleep 2'";
&CJ::my_system($cmd,$verbose) unless ($runflag eq "pardeploy");
 

    
# bring the log file
my $qsubfilepath="$remote_sep_Dir/qsub.info";
my $cmd = "rsync -avz $account:$qsubfilepath  $info_dir/";
&CJ::my_system($cmd,$verbose) unless ($runflag eq "pardeploy");
    

    
my $job_ids;
my $job_id;
if($runflag eq "parrun"){
    # read run info
    my $local_qsub_info_file = "$info_dir/"."qsub.info";
    $job_ids = &CJ::read_qsub($local_qsub_info_file);
    $job_id = join(',', @{$job_ids});
    my $numJobs = $#{$job_ids}+1;

    CJ::message("$numJobs job(s) submitted ($job_ids->[0]-$job_ids->[-1])");
    
#delete the local qsub.info after use
my $cmd = "rm $local_qsub_info_file";
&CJ::my_system($cmd,$verbose);
    
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
#       BUILD A BASH WRAPPER
#====================================

sub make_shell_script
    {
        my ($ssh,$program,$pid,$bqs) = @_;

        
        
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
PID=<PID>;
cd $DIR;
mkdir scripts
mkdir logs
SHELLSCRIPT=${DIR}/scripts/CJrun.${PID}.sh;
LOGFILE=${DIR}/logs/CJrun.${PID}.log;
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

module load MATLAB-R2014b
unset _JAVA_OPTIONS
matlab -nosplash -nodisplay <<HERE
<MATPATH>

% make sure each run has different random number stream
myversion = version;
mydate = date;
RandStream.setGlobalStream(RandStream('mt19937ar','seed', sum(100*clock)));
globalStream = RandStream.getGlobalStream;
CJsavedState = globalStream.State;
fname = sprintf('CJrandState.mat');
save(fname,'myversion','mydate', 'CJsavedState');
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

module load matlab\/R2014b
unset _JAVA_OPTIONS
matlab -nosplash -nodisplay <<HERE
<MATPATH>
% make sure each run has different random number stream
myversion = version;
mydate = date;
RandStream.setGlobalStream(RandStream('mt19937ar','seed', sum(100*clock)));
globalStream = RandStream.getGlobalStream;
CJsavedState = globalStream.State;
fname = sprintf('CJrandState.mat');
save(fname, 'myversion' ,'mydate', 'CJsavedState');
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

        
        
my $pathText.=<<MATLAB;
        
% add user defined path
addpath $ssh->{matlib} -begin

% generate recursive path
addpath(genpath('.'));
    
try
    cvx_setup;
    cvx_quiet(true)
    % Find and add Sedumi Path for machines that have CVX installed
        cvx_path = which('cvx_setup.m');
    oldpath = textscan( cvx_path, '%s', 'Delimiter', '/');
    newpath = horzcat(oldpath{:});
    sedumi_path = [sprintf('%s/', newpath{1:end-1}) 'sedumi'];
    addpath(sedumi_path)
    
catch
    warning('CVX not enabled. Please set CVX path in .ssh_config if you need CVX for your jobs');
end

MATLAB

        
        
        
        
        
        
$sh_script =~ s|<PROGRAM>|$program|;
$sh_script =~ s|<PID>|$pid|;
$sh_script =~ s|<MATPATH>|$pathText|;
        
return $sh_script;
}
        
        

# parallel shell script
#====================================
#       BUILD A PARALLEL BASH WRAPPER
#====================================

sub make_par_shell_script
{
my ($ssh,$program,$pid,$bqs,$counter,$remote_path) = @_;

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
PID=<PID>;
COUNTER=<COUNTER>;
cd $DIR;
mkdir scripts
mkdir logs
SHELLSCRIPT=${DIR}/scripts/CJrun.${PID}.${COUNTER}.sh;
LOGFILE=${DIR}/logs/CJrun.${PID}.${COUNTER}.log;
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

module load MATLAB-R2014b
unset _JAVA_OPTIONS
matlab -nosplash -nodisplay <<HERE
<MATPATH>

    
% add path for parrun
oldpath = textscan('$DIR', '%s', 'Delimiter', '/');
newpath = horzcat(oldpath{:});
bin_path = sprintf('%s/', newpath{1:end-1});
addpath(genpath(bin_path));  % recursive path
    
    
% make sure each run has different random number stream
myversion = version;
mydate = date;
    
% To get different Randstate for different jobs
rng(${COUNTER})
seed = sum(100*clock) + randi(10^6);
RandStream.setGlobalStream(RandStream('mt19937ar','seed', seed));
globalStream = RandStream.getGlobalStream;
CJsavedState = globalStream.State;
fname = sprintf('CJrandState.mat');
save(fname, 'myversion','mydate', 'CJsavedState');
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

module load matlab\/R2014b
unset _JAVA_OPTIONS
matlab -nosplash -nodisplay <<HERE
<MATPATH>

    
% add path for parrun
oldpath = textscan('$DIR', '%s', 'Delimiter', '/');
newpath = horzcat(oldpath{:});
bin_path = sprintf('%s/', newpath{1:end-1});
addpath(genpath(bin_path));
    
    
% make sure each run has different random number stream
myversion = version;
mydate = date;
% To get different Randstate for different jobs
rng(${COUNTER})
seed = sum(100*clock) + randi(10^6);
RandStream.setGlobalStream(RandStream('mt19937ar','seed', seed));
globalStream = RandStream.getGlobalStream;
CJsavedState = globalStream.State;
fname = sprintf('CJrandState.mat');
save(fname,'myversion', 'mydate', 'CJsavedState');
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

my $pathText.=<<MATLAB;
    
% add user defined path
addpath $ssh->{matlib} -begin

% generate recursive path
addpath(genpath('.'));

try
cvx_setup;
cvx_quiet(true)
% Find and add Sedumi Path for machines that have CVX installed
    cvx_path = which('cvx_setup.m');
oldpath = textscan( cvx_path, '%s', 'Delimiter', '/');
newpath = horzcat(oldpath{:});
sedumi_path = [sprintf('%s/', newpath{1:end-1}) 'sedumi'];
addpath(sedumi_path)

catch
warning('CVX not enabled. Please set CVX path in .ssh_config if you need CVX for your jobs');
end

MATLAB




$sh_script =~ s|<PROGRAM>|$program|;
$sh_script =~ s|<PID>|$pid|;
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















