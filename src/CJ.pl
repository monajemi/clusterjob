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
use CJ::Run;     # Contains run object and methods
use Getopt::Declare;
use Data::Dumper;
use Term::ReadLine;
use JSON::PP;
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
&CJ::my_system("rm $CJlog_out") unless (! -f $CJlog_out);
&CJ::my_system("rm $CJlog_error") unless (! -f $CJlog_error);

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
      prompt 	      opens CJ prompt command [undocumented]
                      {defer{cj_prompt}}
      hi	      prints out CJ welcome [undocumented]                     
		      {defer{cj_heart}}
      nihao	      [ditto]  [undocumented]
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
     --clean      	                                  show cleaned packages in log [nocase]  [requires: log]
                                                               {$log_tag="showclean";}
     --err[or]	                                          error tag for show [nocase] [requires: show]
                                                              {$show_tag="error"}
     --no-submit-default	                          turns off default submit parameters [nocase]
                                                              {$qSubmitDefault=0}
     --less      	                                  less tag for show [nocase]  [requires: show]
                                                               {$show_tag="less";}
     --ls      	                                          list tag for show [nocase]  [requires: show]
                                                               {$show_tag="ls";}
     --script [=]  <pattern>	                          shows log of specific script [requires: log]
                                                               {$log_script=$pattern;}
     --header [=]  <num_lines:+i>	                  number of header lines for reducing text files [requires: reduce]
                                                               {$text_header_lines=$num_lines;}
     -alloc[ate]   <resources>	                          machine specific allocation [nocase]
                                                                {$qsub_extra=$resources}
     -dep          <dep_path>		                  dependency folder path [nocase]
                                                                {$dep_folder=$dep_path}
     -m            <msg>	                          reminder message
                                                                {$message=$msg}
     -mem          <memory>	                          memory requested [nocase]
                                                                {$submit_defaults->{'mem'}=$memory}
     -runtime      <r_time>	                          run time requested (default=48:00:00) [nocase]
  	                                                          {$submit_defaults->{'runtime'}=$r_time}
     avail         <tag> 		                  list available resources <tag> = cluster|app
								  { defer{ &CJ::avail($tag) } }
     sync 	                                          force sync [nocase]
		                				{defer{&CJ::sync_forced($sync_status)}}								
     who 	                                          prints out user and agent info [nocase]
     update                                               updates installation to the most recent commit on GitHub [nocase]
     config       [<cluster>] 				  list cluster configuration
                                                    {defer{  &CJ::add_cmd($cmdline) ;&CJ::show_cluster_config($cluster)}}
     connect       <cluster:/\S+/>	                  connect to a cluster
     log          [<argin>]	                          log  -n|all|pid [nocase]
                                                                {defer{&CJ::add_cmd($cmdline); &CJ::show_log($argin,$log_tag,$log_script) }}
     hist[ory]    [<argin>]	                          history of runs -n|all 
                                                                {defer{&CJ::add_cmd($cmdline); &CJ::show_history($argin) }}
     clean        [<pid>]		                  clean certain package [nocase]
                                                                {defer{ &CJ::add_cmd($cmdline); &CJ::clean($pid,$verbose); }}
     cmd          [<argin>]	                          command history -n|all [nocase]
                                                                {defer{ &CJ::show_cmd_history($argin) }}
     deploy       <code:/\S+/> <cluster:/\S*/>	          deploy code on the cluster [nocase] [requires: -m]
                                                                {my $runflag = "deploy";
                                                                {defer{&CJ::add_cmd($cmdline);run($cluster,$code,$runflag,$qsub_extra)}}
                                                                }
     gather       <pattern>  <dir_name> [<pid>]	          gather results of parrun [nocase]
                                                              {defer{&CJ::add_cmd($cmdline);&CJ::Get::gather_results($pid,$pattern,$dir_name,$verbose)}}
     get          [<pid> [/] [<subfolder>]]	          bring results (fully/partially) back to local machine [nocase]
                                                             {defer{&CJ::add_cmd($cmdline);&CJ::Get::get_results($pid,$subfolder,$verbose)}}
     info         [<pid>]	                          info of certain package [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::show_info($pid); }}
     init 	    					  initiates CJ installation [nocase]
              							{defer{CJ::init}}
     install      <app:/\S+/> <cluster:/\S*/>	          install app on a remote machine
								{&CJ::add_cmd($cmdline);defer{&CJ::install_software($app,$cluster)} }
     ls           [<pid> [[/] [<counter>]] ]	  	  shortcut for '--ls show' [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::show($pid,$counter,"","ls") }}
     less         [<pid> [[/] [<counter>] [[/] <file>]] ]	  shortcut for '--less show' [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::show($pid,$counter,$file,"less") }}
     rerun        [<pid> [[/] [<counter>...]]]	          rerun certain (failed) job [nocase]
                                                                 {defer{&CJ::add_cmd($cmdline);
								  &CJ::rerun($pid,\@counter,$submit_defaults,$qSubmitDefault,$qsub_extra,$verbose) }}
     run          <code> <cluster>	                  run code on the cluster [nocase] [requires: -m]
                                                                 {my $runflag = "run";
                                                               {defer{&CJ::add_cmd($cmdline); run($cluster,$code,$runflag,$qsub_extra)}}
                                                                 }
     pardeploy    <code> <cluster>	                  pardeploy code on the cluster [nocase] [requires: -m]
                                                               {my $runflag = "pardeploy";
                                                                {defer{&CJ::add_cmd($cmdline);run($cluster,$code,$runflag,$qsub_extra)}}
                                                               }
     parrun       <code> <cluster>	                  parrun code on the cluster [nocase] [requires: -m]
                                                                {my $runflag = "parrun";
                                                                {defer{&CJ::add_cmd($cmdline);run($cluster,$code,$runflag,$qsub_extra)}}
                                                                }
     reduce       [-f[<orce>]] <filename> [<pid>...] 	  reduce results of parrun [nocase]
     rrun         <code> <cluster>	                  array run code on the cluster [nocase] [requires: -m][undocumented]
                                                                {my $runflag = "rrun";
                                                                {defer{&CJ::add_cmd($cmdline);run($cluster,$code,$runflag,$qsub_extra)}}
                                                                }
     save         <pid> [<path>]	                  save a package in path [nocase]
                                                              {defer{&CJ::add_cmd($cmdline);  &CJ::save_results($pid,$path,$verbose)}}
     show         [<pid> [[/] [<counter>] [[/] <file>]] ]	  show program/error of certain package [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::show($pid,$counter,$file,$show_tag) }}
     state        [<pid> [[/] [<counter>]]]	          state of package [nocase]
                                                                 {defer{ &CJ::add_cmd($cmdline);&CJ::get_print_state($pid,$counter) }}
     summary      <cluster>	                          gives a summary of the number of jobs on particlur cluster with their states [nocase]
                                                        {defer{&CJ::add_cmd($cmdline); &CJ::CheckConnection($cluster);&CJ::get_summary($cluster)}}
     @<cmd_num:+i>	                                  re-executes a previous command avaiable in command history [nocase]
                                                               {defer{&CJ::reexecute_cmd($cmd_num,$verbose) }}
     @$	                                                  re-executes the last command avaiable in command history [nocase]
                                                               {defer{&CJ::reexecute_cmd("",$verbose) }}
     <unknown>...	                                  unknown arguments will be send to bash [undocumented]
                                                               {defer{my $cmd = join(" ",@unknown); system($cmd);}}

EOSPEC

my $opts = Getopt::Declare->new($spec);


if($opts->{'connect'}){
    CJ::message("connecting to $opts->{'connect'}");
    &CJ::connect2cluster($opts->{'connect'});
}

if($opts->{'update'}){
	my $star_line = '*' x length($install_dir);
    # make sure s/he really want a deletion
	CJ::message("This update results in cloning the newest version of ClusterJob in");
	CJ::message("$star_line",1);
	CJ::message("$install_dir",1);
	CJ::message("$star_line",1);
	CJ::message("The newest version may not be compatible with your old data structure",1);
	CJ::message("It is recommended that you backup your old installation before this action.",1);
    CJ::yesno("Are you sure you want to update your installation? Y/N",1);
    
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

#mimi	    print out mimi    [undocumented]
#{print $/;print $"x(15&ord), "Mimi", $/x/\D/ for'3h112a05e0n1l2j4f6b9'=~/./g; print $/;}



if($opts->{'reduce'})
{
    &CJ::add_cmd($cmdline);
    my $force_tag = defined($opts->{'reduce'}{'-f'}) ? 1 : 0;
    &CJ::Get::reduce_results($opts->{'reduce'}{'<pid>'},$opts->{'reduce'}{'<filename>'},$verbose,$text_header_lines, $force_tag);
}




        












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
    
    #my $prompt = "${COLOR}[$localUserName] CJ>$RESET ";

    my $prompt = "[$localUserName] CJ> ";
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
    my $run = CJ::Run->new($BASE,$program,$machine,$runflag,$dep_folder,$message,$qsub_extra,$qSubmitDefault, $submit_defaults,$verbose);

    if ($runflag eq "deploy" || $runflag eq "run"){
        $run->SERIAL_DEPLOY_RUN();
    }elsif($runflag eq "parrun"  || $runflag eq "pardeploy"){
        $run->PAR_DEPLOY_RUN();
    }elsif($runflag eq "rrun"  || $runflag eq "rdeploy"){
        $run->SLURM_ARRAY_DEPLOY_RUN();
    }else{
        &CJ::err("Runflag $runflag was not recognized");
    }
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
