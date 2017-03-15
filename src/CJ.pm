package CJ;
# This is part of Clusterjob (CJ)
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)
use strict;
use warnings;
use CJ::CJVars;
use CJ::Sync;
use Term::ReadLine;
use Time::Local;
use Time::Piece;
use JSON::PP;
use Data::Dumper;
use Data::UUID;
use GetOpt::Declare;
use feature 'say';


sub version_info{
my $version_script="\n\n          This is ClusterJob (CJ) version V0.0.3";
$version_script .=  "\n          Copyright (c) 2015 Hatef Monajemi (monajemi\@stanford.edu)";
$version_script .="\n          CJ may be copied only under the terms and conditions of";
$version_script .=  "\n          the GNU General Public License, which may be found in the CJ";
$version_script .=  "\n          source code. For more info please visit";
$version_script .=  "\n          https://github.com/monajemi/clusterjob";
$version_script .=  "\n          https://clusterjob.org";

    return $version_script ;
}





sub init{


	# Generate a uuid for this installation 
	my $ug    = Data::UUID->new;
	my $UUID = $ug->create_str();   # This will be the Unique ID for this installation
	
	# check to see there is  no prior installation
	if(-d $info_dir){
		&CJ::err("Cannot initialize. Prior installation exist in this directory.")
	}else{
		&CJ::message("Initializing agent \033[32m$UUID\033[0m");
	}
	
	# Set the global variable to this UUID;
	CJ::err("There exist agent with ID $AgentID") if defined($AgentID);
	$AgentID = $UUID; #!important
	
	
	#my  $src_dir = File::Basename::dirname(File::Spec->rel2abs(__FILE__));
	#my  $CJVars_file= "$src_dir/CJ/CJVars.pm";
	
	

	#my $agent_line= "our \$AgentID= \"$AgentID\";  #\"<<AgentID>>\";";
    #my $cmd="sed -i '' 's|.*<<AgentID>>.*|$agent_line|'  $CJVars_file";
    #system($cmd);

	mkdir "$info_dir";
	&CJ::writeFile($AgentIDPATH, $AgentID);  # Record the AgentID in a file. 
	&CJ::create_info_files();
	
	if(defined($CJKEY)){
		# Add this agent to the the list of agents
		eval{
			CJ::add_agent_to_remote();
			};
		if( $@ ){
			if($@->message eq '401 Unauthorized'){
			CJ::warning("Your CJKEY is invalid. Please provide a valid one and then issue 'cj sync' ");
			}else{
			CJ::warning("Unable to connect to CJ database");	
			}
		}
		&CJ::AutoSync() unless ($@);
	}


}





sub parse_qsub_extra{
        my ($qsub_extra) = @_;

    my $specification = q{
    --partition [=] <partitions>	Partition
    -p  [=] <partitions>		[ditto]
    --qos [=] <qos>			Quality of Service
    };
    
    my $args = Getopt::Declare->new($specification,$qsub_extra);   # parse a string
    #print Dumper($args);
return $args;
}




sub max_jobs_allowed{
	my ($ssh, $qsub_extra) = @_;

    
    
    my $account  = $ssh->{account};
    my $bqs      = $ssh->{bqs};
    my $user     = $ssh->{user};

    my $qos;

if($qsub_extra ne "" && $bqs eq "SLURM"){
    
    # We need to parse it and get partitions out
    # partitions are given with flag '-p, --partition=<partition_names>'
    
    my $alloc = &CJ::parse_qsub_extra($qsub_extra);
    # print defined($alloc->{'-p'}) ? $alloc->{'-p'}->{'<partitions>'} . "\n" : "nothing\n";
    # print defined($alloc->{'--qos'}) ? $alloc->{'--qos'}->{'<qos>'} . "\n" : "nothing\n";
    
    if( defined($alloc->{'--qos'}->{'<qos>'})  ){
        $qos = $alloc->{'--qos'}->{'<qos>'};
    }elsif(  defined( $alloc->{'-p'}->{'<partitions>'})  ){
        $qos = $alloc->{'-p'}->{'<partitions>'};
    }elsif(  defined($alloc->{'--partition'}->{'<partitions>'})  ){
        $qos = $alloc->{'--partition'}->{'<partitions>'};
    }else{
        CJ::message('no partition specified. CJ is using default partition.');
        $qos = `ssh $account 'sacctmgr -n list assoc where user=$user format=defaultqos'`; chomp($qos);
    }

    $qos = (split(/,/, $qos))[0];    # if multiple get the first one

    #print "$qos\n";
}

	my $max_u_jobs;
    my $live_jobs = int(0);
    if($bqs eq "SGE"){
		$max_u_jobs = `ssh $account 'qconf -sconf | grep max_u_jobs' | awk \'{print \$2}\' `; chomp($max_u_jobs);
        $live_jobs = (`ssh ${account} 'qstat | grep $user  | wc -l'`); chomp($live_jobs);

    }elsif($bqs eq "SLURM"){
		$max_u_jobs = `ssh $account 'sacctmgr show qos -n format=Name,MaxSubmitJobs | grep $qos' | awk \'{print \$2}\' `; chomp($max_u_jobs);
        #currently live jobs
        $live_jobs = (`ssh ${account} 'qstat | grep $qos | grep $user  | wc -l'`); chomp($live_jobs);
    }else{
        &CJ::err("Unknown batch queueing system");
    }
	
    
    my $jobs_allowed = int($max_u_jobs-$live_jobs);
	return $jobs_allowed;
}






sub check_hash {
   my( $hash, $keys ) = @_;

   return unless @$keys;

   foreach my $key ( @$keys ) {
       return unless eval { exists $hash->{$key} };
       $hash = $hash->{$key};
       }

   return 1;
}


sub write2firebase
{
	my ($pid, $runinfo, $timestamp, $inform) = @_;
	
	return if not defined($CJKEY);	
	
	my $firebase = Firebase->new(firebase => $firebase_name, auth_token => $CJKEY);
	# Check to see if this agent is defined in the agents 
	# if not add it.
	&CJ::add_agent_to_remote($AgentID);
	
	
	my $exists = defined( $firebase->get("users/${CJID}/pid_list/${pid}") );
	
	my $epoch = $runinfo->{date}->{epoch};
	my $pid_head = substr($pid,0,8);  #short_pid
	
	
	if($exists){
		# This is a change
		# here timestamp may be different than epoch; 
		# for example when we clean $timestamp is going 
		# to be the time of cleaning
		my $result   = $firebase->patch("users/${CJID}/pid_list/${pid}",{"timestamp" => $timestamp, "short_pid" => $pid_head , "info" => $runinfo});

		# Update the push timestamp 
	    $result = $firebase->patch("users/${CJID}/agents/$AgentID", {"push_timestamp"=> $timestamp} ); 
		
	}else{
		
		# This is either new or hasn't been pushed before
		my $last = $firebase->get("users/${CJID}/last_instance");
		my $remote_last_epoch = defined($last) ? $last->{"epoch"} : 0;
		$firebase->patch("users/${CJID}/last_instance", {"pid" => $pid, "epoch"=> $epoch} ) if ( $epoch >  $remote_last_epoch ); 
		# Add last instance for this agentm and update push ts. 
	    my $result = $firebase->patch("users/${CJID}/agents/$AgentID", {"last_instance" => {"pid" => $pid, "epoch"=> $epoch}, "push_timestamp"=> $epoch} ); 		
		$result   = $firebase->patch("users/${CJID}/pid_list/${pid}",{"timestamp" => $timestamp, "short_pid" => $pid_head , "info" => $runinfo});
		
		
	}
	
	# Inform All other agents of this change (SyncReq) 
	&CJ::informOtherAgents($pid, $timestamp) if $inform;	
	&CJ::update_local_push_timestamp($timestamp);	

}



sub add_agent_to_remote{
	# This is the first time agent is added.
	my $firebase = Firebase->new(firebase => $firebase_name, auth_token => $CJKEY);	
	# make sure agent doesnt exist already
	return if eval {my $fb_get = $firebase->get("users/${CJID}/agents/$AgentID")};
	my $agentHash = {"SyncReq" => "null", "last_instance" => "null", "push_timestamp" =>0  ,"pull_timestamp" => 0}; 
    my $result = $firebase->patch("users/${CJID}/agents/$AgentID",  $agentHash); 	
}

sub informOtherAgents{
	my ($pid,$timestamp) = @_;
	
	my $firebase = Firebase->new(firebase => $firebase_name, auth_token => $CJKEY);
	# Get Agent List
	my $fb_get;
	return unless eval {$fb_get = $firebase->get("users/${CJID}/agents")};
	
	my @agents= keys %$fb_get;
	return unless @agents;
	
	foreach my $agent (@agents){
	 		
		if($agent ne $AgentID)	{
			
				my $todo={};
		 
				# If prior values exist
		 		if( &CJ::check_hash($fb_get->{$agent}, ["SyncReq"]) )
		 	   	{	 
						my $hash = $fb_get->{$agent}->{SyncReq};
						$todo =  $hash unless ($hash eq "null") ;	
		 		}
				$todo->{$pid} = $timestamp ;
				my $result = $firebase->patch("users/${CJID}/agents/$agent", {"SyncReq" => $todo} ); 	
			}
		
	  }	
	



}





sub sync_forced
{
	my ($status) = @_;		
	return if $status;   #if AutoSync has been done, don't sync it again.
	my $sync = CJ::Sync->new($AgentID);
	&CJ::sync($sync);
	&CJ::message("All up-to-date.");
}

sub  sync
{
	my ($sync) = @_;
	CJ::err("Input should be a CJ::Sync object") unless $sync->isa("CJ::Sync");
	&CJ::message("Syncing...");
	$sync->request() ;	# Sync changes that are requested by other agents
	$sync->pull_timestamp();  # Sync based on pull_timestamp
	$sync->push_timestamp();  # Sync based on pull_timestamp
	updateLastSync();
}

sub AutoSync{
	my $sync = CJ::Sync->new($AgentID);
	my $lastSync = getLastSync();
	return if ( lc($sync->{type}) ne "auto");
	my $diff = time - $lastSync;
	my $interval = $sync->{interval};
	#print $diff . "\n";
	#print $interval;
	return if( $diff <= $interval); 
	&CJ::sync($sync);
	return 1;
}

sub updateLastSync
{
	
	my $now = time;
	CJ::create_lastSync_file();
	&CJ::writeFile($lastSync_file, $now);
	return 1;
}

sub getLastSync
{
	    CJ::create_lastSync_file();  # if it doesnt exist. It creates one;
		
		# Get local epoch
		my $lastSync   =   `sed -n '1{p;q;}' $lastSync_file`; chomp($lastSync);
	
		if( (not defined $lastSync) || ($lastSync eq "") ){
			return 0;
		}else{
			return $lastSync;
		}

	
}




























sub rerun
{
    my ($pid,$counter,$mem,$runtime,$qsub_extra,$verbose) = @_;
   
   
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
        
    }else{
        if( &CJ::is_valid_pid($pid) ){
            # read info from $run_history_file
            $info = &CJ::retrieve_package_info($pid);
            
            if (!defined($info)){
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }
    
    
    my $short_pid = substr($pid,0,8);
    if($info->{'clean'}){
        CJ::message("Can't rerun. Package $short_pid has been cleaned on $info->{'clean'}->{'date'}->{datestr}.");
        exit 0;
    }

    
    my $account     = $info->{'account'};
    my $remote_path = $info->{'remote_path'};
    my $runflag = $info->{'runflag'};
    my $program = $info->{'program'};
    my $job_id = $info->{'job_id'};
    my $bqs = $info->{'bqs'};

    #my $programName = &CJ::remove_extension($program);
    
    my @job_ids = split(',',$job_id);

	if(! @$counter){
	   $counter = [1..($#job_ids+1)];  
	}
    
    my $date = &CJ::date();
    my $master_script;
    if ($#job_ids eq 0) { # if there is only one job
        #run
        $master_script =  &CJ::Scripts::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$mem,$runtime,$remote_path,$qsub_extra);
    }else{
        #parrun
        if(@$counter){
            foreach my $count (@$counter){
                $master_script =  &CJ::Scripts::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$mem,$runtime,$remote_path,$qsub_extra,$count);
            }
        }else{
            # Package is parrun, run the whole again!
            foreach my $i (0..$#job_ids){
               $master_script =  &CJ::Scripts::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$mem,$runtime,$remote_path,$qsub_extra,$i);
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

&CJ::message("Sending rerun script over to $account");
my $cmd = "rsync -arvz  $local_master_path ${account}:$remote_path/";
&CJ::my_system($cmd,$verbose);
    
    
    &CJ::message("Submitting job(s)");
    $cmd = "ssh $account 'source ~/.bashrc;cd $remote_path; bash -l rerun_master.sh > $remote_path/rerun_qsub.info; sleep 2'";
    &CJ::my_system($cmd,$verbose);
    
    
    
    # bring the log file
    my $qsubfilepath="$remote_path/rerun_qsub.info";
    $cmd = "rsync -avz $account:$qsubfilepath  $install_dir/.info/";
    &CJ::my_system($cmd,$verbose);

    
    
    my $rerun_qsub_info_file = "$install_dir/.info/"."rerun_qsub.info";
    my $rerun_job_ids = &CJ::read_qsub($rerun_qsub_info_file); # array ref
    #my $rerun_job_id = join(',', @{$rerun_job_ids});

   

#=======================================
# write changes to the run_history file
#=======================================
  # - replace the old job_id's by the new one
    
    if($#job_ids eq 0){
           $job_id =~ s/$job_ids[0]/$rerun_job_ids->[0]/g;
        &CJ::message("job-id: $rerun_job_ids->[0]");

    }else{
        &CJ::message("job-id: $rerun_job_ids->[0]-$rerun_job_ids->[-1]");
        foreach my $i (0..$#{$counter}){
            my $this = $counter->[$i] - 1;
            $job_id =~ s/$job_ids[$this]/$rerun_job_ids->[$i]/g;
        }
    }

    
# - Keep track of the old id in the rerun section
 my @runinfo;
    if($#job_ids eq 0){
        $runinfo[0] = "($job_ids[0])";
    }else{
        foreach my $i (0..$#{$counter}){
        $runinfo[$i] = "$counter->[$i]"."($job_ids[$i])";
        }
    }
    
my $runinfo    = join(',', @runinfo);
my $this_rerun = "$date -> $runinfo";


my $type = "rerun";
my $change = {new_job_id => $job_id,
              date       => $date, 
			  old_job_id => $runinfo
		     };

			  
my $newinfo = &CJ::add_change_to_run_history($pid, $change, $type);


&CJ::add_to_history($newinfo,$date,$type);


# write runinfo to FB as well
my $timestamp  = $date->{epoch};    
my $inform = 1;
&CJ::write2firebase($info->{'pid'},$newinfo, $timestamp, $inform);

exit 0;
}





# This is the CJ confirmation included in the
# reproducible package
sub build_cj_confirmation{
    my ($pid, $path) = @_;
    
    my $info = retrieve_package_info($pid);
    my $program = $info->{'program'};
    
    my $version_script = &CJ::version_info() ;
    
    $Data::Dumper::Sortkeys = 1;
    $Data::Dumper::Terse = 1;
    my $dumper_info = Dumper($info);
    

my $confirmation_script =<<CONFIRM;
$version_script
------------------------------------------------------------
This reproducible package is generated by Clusterjob (CJ).
To reproduce the results, please rerun
                "reproduce_$program"
    
job discription:
    
PID         = $info->{'pid'}
DATE        = $info->{'date'}->{'datestr'}
AUTHOR      = $info->{'user'}
PROGRAM     = $info->{'program'}
ACCOUNT     = $info->{'account'}
RUNFLAG     = $info->{'runflag'}
REMOTE_PATH = $info->{'remote_path'}
    
          $info->{message}

...
    
$dumper_info
    
    
------------------------------------------------------------
CONFIRM

CJ::writeFile("$path/CJ_CONFIRMATION.TXT", $confirmation_script);
my $cmd = "chmod +x $path/CJ_CONFIRMATION.TXT";
&CJ::my_system($cmd,0);

}





#=================================================================
#            CLUSTERJOB SAVE (ONLY SAVES THE OUTPUT OF 'GET')
#  ex.  clusterjob save pid
#  ex.  clusterjob save pid ~/Downloads/myDIR
#=================================================================



sub save_results{
    
    my ($pid,$save_dir,$verbose) = @_;
    

    
    if(! &CJ::is_valid_pid($pid)){
        &CJ::err("Please enter a valid package name");
    }
    
    my $info  = &CJ::retrieve_package_info($pid);
    
    
    my $save_path;
    if( !defined($save_dir)){
        # Read the deafult save directory
        $save_path= $info->{'save_path'};
        &CJ::message("Saving results in ${save_path}");
    }else{
        $save_path = "$save_dir/$info->{pid}";
    }
    
    
    
    
    if(! -d "$get_tmp_dir/$info->{'pid'}"){
        &CJ::warning("You must run 'get' before 'save'!");
        exit 0 ;
    }
    
    
    if(-d "$save_path"){
        # Ask if it needs to be overwritten
        
        CJ::message("Directory $save_path already exists. What to do: [S]ync, [O]verwrite,[C]ancel?");
        my $input =  <STDIN>; chomp($input);
        if(lc($input) eq "o" or lc($input) eq "overwrite"){
            
            my $cmd = "rm -rf $save_path/*";
            &CJ::my_system($cmd,$verbose);
            
            $cmd = "rsync -arz  $get_tmp_dir/$info->{'pid'}/ $save_path/";
            &CJ::my_system($cmd,$verbose);
            
        }elsif(lc($input) eq "s" or lc($input) eq "sync"){
            
            my $cmd = "rsync -arz  $get_tmp_dir/$info->{'pid'}/ $save_path/";
            &CJ::my_system($cmd,$verbose);
        }else{
            &CJ::message("Nothing Saved!");
            exit 0;
        }
        
        
    }else{
        
        # Create directories
        my $cmd = "mkdir -p $save_path";
        &CJ::my_system($cmd,$verbose) ;
        
        $cmd = "rsync -arz  $get_tmp_dir/$info->{'pid'}/ $save_path";
        &CJ::my_system($cmd,$verbose);
        
        
    }
    
    
    my $date = &CJ::date();
    my $flag = "save";
	# ADD THIS SAVE TO HISTRY
    &CJ::add_to_history($info,$date,$flag);

    exit 0;
}



sub show_cmd_history{
    my ($argin) = @_;

    if( (!defined $argin) || ($argin eq "") ){
        $argin= 50;
    }
    
        
    if($argin =~ m/^\-?\d*$/){
        
        $argin =~ s/\D//g;   #remove any non-digit
        my $info=`tail -n  $argin $cmd_history_file`;chomp($info);
        print "$info \n";
       
    }elsif($argin =~ m/^\-?all$/){
        my $info=`cat $cmd_history_file`;chomp($info);
        print "$info \n";
    }else{
        &CJ::err("Incorrect usage: nothing to show");
    }
    
    
    
    
    exit 0;


}



sub show_history{
    my ($history_argin) = @_;
    
    
    if( (!defined $history_argin) || ($history_argin eq "") ){
        $history_argin= "all";
    }
    
   if($history_argin =~ m/^\-?\d*$/){
        
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




sub show_log{
    my ($log_argin, $log_tag, $log_script) = @_;

    my $num_show = undef;
    
    if( (! defined $log_argin) || ($log_argin eq "") ) {
        $num_show = 10;
        $log_argin = "";
    }elsif( $log_argin =~ m/^\-?all$/ ){
		my $pid_timestamp = &CJ::read_pid_timestamp();
		$num_show = keys $pid_timestamp;
    }elsif( $log_argin =~ m/^\-?\d*$/ ){
        $log_argin =~ s/\D//g;     #remove any non-digit
        $num_show = $log_argin;
    }elsif(&CJ::is_valid_pid($log_argin)){
        if(defined(&CJ::retrieve_package_info($log_argin))){
            &CJ::print_detailed_log($log_argin);       
        }else{
            &CJ::err("No such job found in CJ database");
        }
        
        exit 0;
        
    }else{
        &CJ::err("Incorrect usage: nothing to show");
    }
    
   
    my @unique_pids;
	my ($sorted_pids, $sorted_ts) = CJ::avail_pids();

	my $maxIdx = $#{$sorted_pids};
	
    my $info_hash =  &CJ::retrieve_package_info($sorted_pids);			

        my  @to_show_idx;
        
        if(!defined($log_script)){
            #my $min = ($num_show-1, $#unique_pids)[$num_show-1 > $#unique_pids];
            #foreach my $i (0..$min){
            my $counter = 0;
            while( ($counter <= $maxIdx) & ($#to_show_idx < $num_show-1 )  ){
		 			    my $this_pid = $sorted_pids->[$maxIdx-$counter];
                        my $info =  $info_hash->{$this_pid};			
		 	    	 
                        if( $log_tag eq "showclean" ){
                            push @to_show_idx, $counter;
                        }else{
                            # only alive
                            push @to_show_idx, $counter if( ! $info->{clean} );
                        }
                $counter++;
            }
        }else{
			# full search. User required a search of script
            foreach my $i (0..$maxIdx){
                
 			   my $this_pid = $sorted_pids->[$maxIdx-$i];
               my $info =  $info_hash->{$this_pid};			
 	    	   				
				if( $log_tag eq "showclean" ){
                push @to_show_idx, $i if( $info->{program} =~ m/$log_script/);
                }else{
                push @to_show_idx, $i if( ($info->{program} =~ m/$log_script/) & (! $info->{clean}) );
                }
                    
            }
        }
            
    
       foreach my $i (reverse @to_show_idx){
			  my $this_pid = $sorted_pids->[$maxIdx-$i];
	    	  my $info =  $info_hash->{$this_pid};			
        print "\n";
        print "\033[32mpid $info->{pid}\033[0m\n";
        print "date: $info->{date}->{datestr}\n";
        print "user: $info->{user}\n";
        print "agent: $info->{agent}\n";
        print "account: $info->{account}\n";
        print "script: $info->{program}\n";
        #print "remote_path: $info->{remote_path}\n";
        print "initial_flag: $info->{runflag}\n";
        print "reruned: ", 0+keys($info->{rerun}) . " times \n" if($info->{rerun}) ;
        print "cleaned: $info->{clean}->{date}->{datestr}\n" if($info->{clean}) ;
        print "\n";
        print ' ' x 10; print "$info->{message}\n";
        print "\n";
        
		}
    
  
    
    
    
    exit 0;


}




sub  print_detailed_log{
    my ($pid) = @_;

my $info = undef;
    if((!defined $pid)  || ($pid eq "") ){
        #read the first lines of last_instance.info;
        $info =  &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
    }else{
        
        if(&CJ::is_valid_pid($pid)){
            # read info from $run_history_file
            $info =  &CJ::retrieve_package_info($pid);
            if(!defined($info)){ &CJ::err("No such job found in CJ database.")};
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
    }

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;
print "\n\033[32mpid $info->{pid}\033[0m\n";
print Dumper($info);
    
}
    
    
    
sub clean
{
    my ($pid, $verbose) = @_;
    
    
    
    
    
    my $account;
    my $local_path;
    my $remote_path;
    my $job_id;
    my $save_path;
	my $bqs ;
    
    my $info;
    if((!defined $pid)  || ($pid eq "") ){
        #read the first lines of last_instance.info;
        $info =  &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
    }else{
        
        if(&CJ::is_valid_pid($pid)){
            # read info from $run_history_file
            $info =  &CJ::retrieve_package_info($pid);
            if(!defined($info)){ &CJ::err("No such job found in CJ database.")};
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
    }
    
    
    $bqs         =   $info->{'bqs'};
    $account     =   $info->{'account'};
    $local_path  =   $info->{'local_path'};
    $remote_path =   $info->{'remote_path'};
    $job_id      =   $info->{'job_id'};
    $save_path   =   $info->{'save_path'};
    
    
    my $short_pid = substr($pid,0,8);



    if( defined($info->{'clean'})){
        CJ::message("Nothing to clean. Package $short_pid has been cleaned on $info->{'clean'}->{'date'}->{'datestr'}.");
        exit 0;
    }
    
    
    
    # make sure s/he really want a deletion
    CJ::message("Are you sure you would like to clean $short_pid? Y/N");
    my $yesno =  <STDIN>; chomp($yesno);
    
    if(lc($yesno) eq "y" or lc($yesno) eq "yes"){
    
    CJ::message("Cleaning $short_pid");
    my $local_clean     = "$local_path\*";
    my $remote_clean    = "$remote_path\*";
    my $save_clean      = "$save_path\*";
    
	
	
	my $avail_ids;
	if($bqs eq "SGE"){
		
		my $expr = "qstat -xml | tr \'\n\' \' \' | sed \'s#<job_list[^>]*>#\\\n#g\' | sed \'s#<[^>]*>##g\' | grep \" \" | column -t";
  		 $avail_ids = `ssh ${account} $expr | grep CJ_$short_pid | awk \'{print \$1}\' | tr '\n' ' ' ` ;
  	   	 #print $avail_ids  . "\n";
			
	}elsif($bqs eq "SLURM"){
		$avail_ids = `ssh ${account} ' sacct -n --format=jobid,jobname%15 | grep -v "^[0-9]*\\." | grep CJ_$short_pid ' | awk \'{print \$1}\' | tr '\n' ' '  `;
	}else{
		 &CJ::err("Unknown batch queueing system");
	}
	
	
	
    if (defined($avail_ids) && $avail_ids ne "") {
        CJ::message("Deleting jobs associated with package $short_pid");
		
        #my @job_ids = split(',',$job_id);
        #$job_id = join(' ',@job_ids);

		# make sure that all are deleted. Sometimes we dont catch a jobID locally because of a failure
		# So this really cleans the mess
		
			#print $job_id . "\n";
        my $cmd = "rm -rf $local_clean; rm -rf $save_clean; ssh ${account} 'qdel $avail_ids; rm -rf $remote_clean' " ;
        &CJ::my_system($cmd,$verbose);
			
    }else {
        my $cmd = "rm -rf $local_clean;rm -rf $save_clean; ssh ${account} 'rm -rf $remote_clean' " ;
        &CJ::my_system($cmd,$verbose);
    }
    
    
    
    
    my $date = &CJ::date();
    my $flag = "clean";
    &CJ::add_to_history($info,$date,$flag);
        
        
#    my @time_array = ( $time =~ m/../g );
#    $time = join(":",@time_array);
#    # Add the change to run_history file
#my $text =<<TEXT;
#    DATE -> $hist_date
#    TIME -> $time
#TEXT

my $change={date => $date, agent=>$AgentID};
my $newinfo = &CJ::add_change_to_run_history($pid, $change, "clean");

my $timestamp = $date->{epoch};
# Write runinfo to FB as well
my $inform = 1;
&CJ::write2firebase($info->{'pid'},$newinfo, $timestamp, $inform);
	    
}
    
    exit 0;

}







sub show
{
    my ($pid, $num, $file, $show_tag) = @_;
    
	
	
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
        
    }else{
        if( &CJ::is_valid_pid($pid) ){
            # read info from $run_history_file
            $info = &CJ::retrieve_package_info($pid);
            
            if (!defined($info)){
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }

    
    my $short_pid = substr($pid,0,8);
    if(defined($info->{clean}{date})){
        CJ::message("Nothing to show. Package $short_pid has been cleaned on $info->{clean}{date}{datestr}.");
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
    }elsif($show_tag eq "less" ){
		
	
		if(!defined($file)){
			$file=$num;
			$num = "";
		}
		
        if($num){
            $script = (`ssh ${account} 'less -C1 $remote_path/$num/$file'`) ;chomp($script);
        }else{
			
            $script = (`ssh ${account} 'less -C1 $remote_path/$file'`) ;chomp($script);
        }
    }
        
    print "$script \n";
        
    exit 0;
    
}












sub show_info
{
    my ($pid) = @_;
   
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid = $info->{'pid'};        
    }else{
        if( &CJ::is_valid_pid($pid) ){
            # read info from $run_history_file
            $info = &CJ::retrieve_package_info($pid);
            if (!defined($info)){
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }
    
    
    #print '-' x 35;print "\n";
    print "\n";
    print "\033[32mpid $info->{pid}\033[0m\n";
    print "date: $info->{date}->{datestr}\n";
    print "user: $info->{user}\n";
    print "agent: $info->{agent}\n";
    print "account: $info->{account}\n";
    print "script: $info->{program}\n";
    print "remote_path: $info->{remote_path}\n";
    print "initial_flag: $info->{runflag}\n";
    print "reruned: ", 0+keys($info->{rerun}) . " times \n" if($info->{rerun}) ;
    print "cleaned: $info->{clean}->{date}->{datestr}\n" if($info->{clean}) ;
    print "\n";
    print ' ' x 10; print "$info->{message}\n";
    print "\n";
    
    #print '-' x 35;print "\n";
    
    
    exit 0;

}













sub get_summary
{
	my ($machine) = @_;
	
	

	
	
	my $ssh      = &CJ::host($machine);
	my $account  = $ssh->{'account'};
	my $bqs  = $ssh->{'bqs'};
	
	my $user 	 = $ssh->{'user'};
	
	#my $remoteinfo  = &CJ::remote();
	
	my $live_jobs = (`ssh ${account} 'qstat | grep $user  | wc -l'`); chomp($live_jobs );


	#my 	 $REC_STATES = "";
	my 	 $REC_PIDS_STATES = "";
	
    if($bqs eq "SGE"){
        # $REC_STATES = (`ssh ${account} 'qstat -u \\${user}' | awk \'{print \$5}\'`) ;chomp($REC_STATES);
        # $REC_PIDS_STATES = (`ssh ${account} 'qstat | grep \\${user}' | awk \'{print \$2}\'`) ;chomp($REC_PIDS);

 	  # This now works for SGE 
  	  my $expr = "qstat -xml | tr \'\n\' \' \' | sed \'s#<job_list[^>]*>#\\\n#g\' | sed \'s#<[^>]*>##g\' | grep \" \" | column -t";
 	  $REC_PIDS_STATES = (`ssh ${account} $expr | awk \'{print \$3,\$5}\' `) ;chomp($REC_PIDS_STATES);
 	  #print $REC_PIDS_STATES . "\n";
 	  #print $expr . "\n";
	  
 	  #my $expr = "qstat -xml | tr \'\\n\' \' \' | sed \'s#<job_list[^>]*>#\\n#g\' | sed \'s#<[^>]*>##g\' | grep \" \" | column -t";
       #$REC_PIDS_STATES = `ssh ${account} $expr | awk \'{print \$3,\$5}\'` ;chomp($REC_PIDS_STATES);
	
		
    }elsif($bqs eq "SLURM"){
       # $REC_STATES = (`ssh ${account} 'sacct --format=state | grep -v "^[0-9]*\\."'`) ;chomp($REC_STATES);
        $REC_PIDS_STATES = (`ssh ${account} 'sacct -n --format=jobname%15,state | grep -v "^[0-9]*\\."'`);chomp($REC_PIDS_STATES);
		
    }else{
        &CJ::err("Unknown batch queueing system");
    } 
	 
	 
    my @rec_pids_states="";
	@rec_pids_states = split('\n',$REC_PIDS_STATES);
	
    my @rec_pids;
	my @rec_states;
	foreach my $i (0..$#rec_pids_states){
		my ($longpid,$state) = split(' ',$rec_pids_states[$i]);
		#print $longpid . "\n";
		if ( $longpid =~ m/^CJ\_.*/){
		push @rec_pids, substr($longpid,3,8); # remove the first 3 (CJ_), and read the firt 8 from the rest
		push @rec_states, $state;
	}
	}
 	
	# Unique PIDS
    my @unique_pids = "";
 	@unique_pids = do { my %seen; grep { !$seen{$_}++ } @rec_pids };
	
	
	
	# Unique States
    #print Dumper(@rec_states);	
	
	my @unique_states;
	#@unique_states = do { my %seen; grep { !$seen{$_}++ } @rec_states};

	my $print_states = {};
	
	my ($fb_pids, $fb_response) = CJ::avail_pids();
	
	my @available_pids = @$fb_pids;
	
	foreach my $i (0..$#unique_pids){
		my $this_pid = $unique_pids[$i];
		#print "$this_pid\n";
		
		
		if( ! grep { /$this_pid/ } @available_pids ){
			next;
		}
		
		my $this_states = &CJ::get_state($this_pid);
		my @this_states = values  %$this_states;
		my @this_unique_states = do { my %seen; grep { !$seen{$_}++ } @this_states};
		
		push @unique_states, @this_unique_states;
		
		#print $this_unique_states[0] . "\n"; 
		#my @this_unique_states;
		# foreach my $i (0..$#matches){
# 			my ($longpid,$state) = split(' ',$matches[$i]);
# 			#$state =~ s/^\s+|\s+$//g ;
# 			#print $state ;
# 			if( ! grep( /^$state$/, @this_unique_states) ){
# 				push @this_unique_states, $state;
# 			}
#
# 		}


		$print_states->{$this_pid} = join(",",@this_unique_states);
 	}


	@unique_states = do { my %seen; grep { !$seen{$_}++ } @unique_states};


    #print '-' x 35;print "\n";
    print "\n";
    print "\033[32m$user\@$machine \033[0m\n\n";
    print ' ' x 5; print "Live Jobs : ", $live_jobs . "\n";
    print ' ' x 5;print '-' x 17;print "\n";

	foreach my $i (0..$#unique_states){
			my @this_matches = grep { /$unique_states[$i]/ } @rec_states;
			my $num_this_state = 1+$#this_matches;
		 	print ' ' x 5; printf "%-10s : %-8i\n", $unique_states[$i],$num_this_state;
	}

	 print "\n";
     print ' ' x 5; print "PIDS:\n";
     print ' ' x 5; print '-' x 5;print "\n";
 	 while ( my ($key, $value) = each(%$print_states) ) {
 	 	print ' ' x 5; printf "%-10s : (%-s)\n", $key,$value;
 	 }
    print "\n\n";
	
}






sub get_state
{
    my ($pid,$num) = @_;
    
	#print "$pid\n";
	
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
        
    }else{
        if( &CJ::is_valid_pid($pid) ){
            # read info from $run_history_file
            $info = &CJ::retrieve_package_info($pid);
            
            if (!defined($info)){
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }
   
	
    my $short_pid = substr($info->{pid},0,8);
    
    my $account = $info->{'account'};
    my $job_id  = $info->{'job_id'};
    my $bqs     = $info->{'bqs'};
    my $runflag = $info->{'runflag'};
    
    my $states={};
	
if ( $runflag =~ m/^par*/ ){
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

    foreach my $i (0..$#rec_ids){
        my $key = $rec_ids[$i];
        my $val = $rec_states[$i];
        $states->{$key} = $val;		
    }
	
}else{
	    my $state;
	    if($bqs eq "SGE"){
	        $state = (`ssh ${account} 'qstat | grep $job_id' | awk \'{print \$5}\'`) ;chomp($state);
	    }elsif($bqs eq "SLURM"){
	        $state = (`ssh ${account} 'sacct | grep $job_id | grep -v "^[0-9]*\\." ' | awk \'{print \$6}\'`) ;chomp($state);
	    }else{
	        &CJ::err("Unknown batch queueing system");
	    }
    
	    if(!$state){
	    $state = "Unknown";
	    }
        my $key = $job_id;
        my $val = $state;
        $states->{$key} = $val;	
}

    return $states;
    #exit 0;
}
		
 
	
	
            
   





sub get_print_state
{
	
    my ($pid,$num) = @_;
    
	
	
	
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
        
    }else{
        if( &CJ::is_valid_pid($pid) ){
            # read info from $run_history_file
            $info = &CJ::retrieve_package_info($pid);
            
            if (!defined($info)){
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }
    
	
    my $short_pid = substr($info->{pid},0,8);
    if($info->{'clean'}){
        CJ::message("Nothing to show. Package $short_pid has been cleaned on $info->{'clean'}->{'date'}->{datestr}.");
        exit 0;
    }

    
    
    
    my $account = $info->{'account'};
    my $job_id  = $info->{'job_id'};
    my $bqs     = $info->{'bqs'};
    my $runflag = $info->{'runflag'};
	
	
	
	
	
	
	my $states = &CJ::get_state($pid,$num);
	my $size = scalar keys %$states;
 
if($size eq 1){

	my ($job_id) = keys %$states; 	
	my $state  = $states->{$job_id};chomp($state);
    print "\n";
    print "\033[32mpid $info->{'pid'}\033[0m\n";
    print "remote_account: $account\n";
    print "job_id: $job_id \n";
    print "state: $state\n";

	
}else{
    my @job_ids = split(',',$job_id);
	
	
    if((!defined $num) || ($num eq "")){
        print "\033[32mpid $info->{'pid'}\033[0m\n";
        print "remote_account: $account\n";
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
    }elsif(&CJ::isnumeric($num) && $num <= $#job_ids+1){
        print '-' x 50;print "\n";
        print "\033[32mpid $info->{'pid'}\033[0m\n";
        print "remote_account: $account\n";
        my $tmp = $num -1;
        my $val = $states->{$job_ids[$tmp]};
        if (! $val){
        $val = "unknwon";
        }
        print "$num     " . "$job_ids[$tmp]      "  . "$val" . "\n";
        
        
    }else{
        my $lim =1+$#job_ids;
        &CJ::err("incorrect entry. Input $num >= $lim.")
    }
    
    print '-' x 35;print "\n";
    
}	
    

}
	


sub grep_config_var
{
	my ($filepath, $var_pattern) = @_;
	
	return if (! -f $remote_config_file);
	
	# See if user has defined an interval of interest
	my $line = `grep -i -A 1 $var_pattern $remote_config_file` ; chomp($line);
	my ($var) = $line =~ /^$var_pattern(.*)/im;  if($var) { $var =~ s/^\s+|\s+$//g};
	return defined($var)? $var : undef ;
}

sub grep_var_line
{
    my ($pattern, $string) = @_;
    
    # go to $TOP and look for the length of the found var;
    my $this_line;
    my @lines = split /\n/, $string;
    foreach my $line (@lines) {
        if($line =~ /^\s*(?<!\%)\s*${pattern}\s*=.*/){
            $this_line = $line;
            last;
        }
    }
    if($this_line){
        return $this_line;
    }else{
        &CJ::err(" Variable '$pattern' is not declared.\n");
    }
}





#
# sub remote{
#
#     my $remote_config = {};
#
#     my $lines;
#     open(my $FILE, $remote_config_file) or  die "could not open $remote_config_file: $!";
#     local $/ = undef;
#     $lines = <$FILE>;
#     close ($FILE);
#
#
#     my ($cjid) = $lines =~ /^CJID(.*)/m;  $cjid =~ s/^\s+|\s+$//g;
#     my ($cjkey) = $lines =~/^CJKEY(.*)/m; $cjkey =~ s/^\s+|\s+$//g;
#
#
#     $remote_config->{'cjid'}   = $cjid;
#     $remote_config->{'cjkey'}  = $cjkey;
#
#     return $remote_config;
# }


sub add_record{
	my ($info) = @_;
    
	# Find the last number
	&CJ::add_to_history($info, $info->{date}, $info->{runflag});
	&CJ::add_to_run_history($info);
	&CJ::add_to_pid_timestamp( { $info->{pid} => $info->{date}{epoch} }  );
	&CJ::update_local_push_timestamp($info->{date}{epoch});
	&CJ::update_last_instance($info->{'pid'});
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
        &CJ::err(".ssh_config:: Machine $machine_name not found. ");
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
    $ssh_config->{'user'}            = $user;
    
    return $ssh_config;
}





sub retrieve_package_info{
    
    my ($pids) = @_;
    #### EVERY THING IS DONE LOCALLY NOW. 
	# From commit 87ec10b
	
	if(!$pids){
		$pids =`sed -n '1{p;q;}' $last_instance_file`; chomp($pids);
	}
	
	
	my $is_scalar = is_valid_pid($pids) ? 1 : 0;
 	$pids = [$pids] if $is_scalar;  #change the single pid to be a array ref
	
	# Make sure all PIDs are valid
	foreach my $pid (@{$pids}){
   	    &CJ::err("No valid PID detected")  unless &CJ::is_valid_pid($pid);
   	}
		
    my $records = &CJ::read_record($pids);  # pids can be a scalar or a array ref

		
	my $info_hash;   
	
	foreach my $pid ( @$pids ){
		if(defined($records->{$pid})){			
	 	   $info_hash->{$pid} = decode_json $records->{$pid};
		}else{
			&CJ::err(" \'$pid\' has not yet been found in CJ database. May be you need to force sync using 'CJ sync'");
		} 	
	}
    
	
	
	if ($is_scalar & defined($info_hash)){		
		return $info_hash->{(keys %$info_hash)[0]} ; # scalar-case;
	}
	
	
	return  defined($info_hash) ? $info_hash : undef;
	
}



sub update_last_instance
{
	my ($pid) = @_;
	&CJ::writeFile($last_instance_file, $pid);
}

sub update_local_push_timestamp
{
	my ($timestamp) = @_;
# create the file if it doesnt exist.	
&CJ::writeFile($local_push_timestamp_file, $timestamp)	
}


sub read_pid_timestamp
{
	# read file
	my $contents = &CJ::readFile($pid_timestamp_file);
	my $hash;
	$hash = decode_json $contents  if defined($contents);
	return $hash;
}

sub add_to_pid_timestamp
{
my ($timestamp_hashref) = @_;

# create the file if it doesnt exist.	
&CJ::create_pid_timestamp_file();


my $hash = &CJ::read_pid_timestamp();

# add this timestamp
while (my ($pid, $timestamp) = each (%$timestamp_hashref)){
	$hash->{$pid} = $timestamp;
	
}

# encode to json
my $contents = encode_json $hash if defined($hash);
# write it to a file
&CJ::writeFile($pid_timestamp_file, $contents) if defined($contents);

}



















sub date{


my $t = &Time::Piece::localtime;
#print $t->epoch . "\n";die;

my @month_abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
my @day_abbr = qw( Sun Mon Tue Wed Thu Fri Sat );
	
my $sec = $t->sec;
my $min = $t->min;
my $hour= $t->hour;
my $mday= $t->mday;
my $mon = $t->_mon;  #Jan=0
my $year= $t->year;
my $epoch=$t->epoch;
#print $t->tzoffset . "\n";

#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#$year 	+= 1900;
#my @t = localtime(time);
#my $gmt_offset_in_seconds = timegm(@t) - timelocal(@t);
my $gmt_offset_in_seconds = $t->tzoffset;    
my $abs_offset;
my $sign="";
if($gmt_offset_in_seconds<0){
      $abs_offset = $gmt_offset_in_seconds * (-1);
	  $sign = "-";
}else{
        $abs_offset = $gmt_offset_in_seconds ;
}
    
my ($gmt_offset_hour, $remainder_in_second) = (int($abs_offset/3600), $abs_offset%3600);
(my $gmt_offset_min, $remainder_in_second) = (int($remainder_in_second/60), $remainder_in_second%60);

my $offset = sprintf("%s%02d:%02d:%02d", $sign,$gmt_offset_hour,$gmt_offset_min,$remainder_in_second);
my $datestr = sprintf ("%04d-%03s-%02d  %02d:%02d:%02d  \(GMT %s\)", $year, $month_abbr[$mon], $mday, $hour,$min, $sec, $offset);

my $date = {
        year    	=> $t->year,
        month   	=> $month_abbr[$mon],
        day     	=> $mday,
        hour    	=> $hour,
        min     	=> $min,
        sec     	=> $sec,
        gmt_offset 	=> $offset,
        datestr  	=> $datestr,
		epoch    	=> $epoch       # This needs to be 64 bit after 2038 (Unix time problem)  
};
    
    return $date;
}

# Check the package name given is valid
sub is_valid_pid
{
my ($name) = @_;
    
if(!defined($name)){
$name = ""
}
# CJ uses a default abbreviation of SHA which has 8 first characters!
if( $name =~ m/\b[0-9a-f]{8,40}\b/){
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
    print(' ' x 5 . "CJerr::$message\n");
	exit;
}

sub warning{
    my ($msg) = @_;
    print(' ' x 5 . "CJwarning::$msg\n");
}


sub message{
    my ($msg,$noBegin) = @_;
	if($noBegin){
    print(' ' x 16 . "$msg\n");
	}else{
	print(' ' x 5 . "CJmessage::$msg\n");	
	}
}


sub my_system
{
   my($cmd,$verbose) = @_;
    if($verbose){
        print("system: ",$cmd,"\n");
        system("$cmd");
        
    }else{
		system("touch $CJlog") unless (-f $CJlog);
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
    
	
	if(!defined($content) || $content eq ""){
   	    return undef;
	}else{
	    return $content;
	}
	
	
	
}




sub add_to_history
{
    my ($info, $date, $flag) = @_;
	# create if it doesnt exist;
	&CJ::create_history_file();
	  
	my $short_message = substr($info->{message}, 0, 40);
	my $lastnum=`grep "." $history_file | tail -1  | awk \'{print \$1}\' `;
	my $hist_date = (split('\s', $date->{datestr}))[0];
	# ADD THIS RERUN TO HISTRY
	my $counter = ($lastnum =~ m/\d+/) ? $lastnum+1 : 1;
	
	
	my @change = ("clean", "rerun");
	my %changeFlags = map { $_ => 1 } @change;
	
	my $history ;
	my $short_pid= substr($info->{pid},0,8);
	if(! exists($changeFlags{$flag})){
		$history = sprintf("%-15u%-15s%-15s%-10s%-15s%-40s",$counter, $hist_date,$short_pid, $flag, $info->{machine}, $short_message);
	}else{
		$history = sprintf("%-15u%-15s%-15s%-10s",$counter, $hist_date, $short_pid, $flag);
	}
				
		
    # ADD THIS SAVE TO HISTRY
    open (my $FILE , '>>', $history_file) or die("could not open file '$history_file' $!");
    print $FILE "$history\n";
    close $FILE;
    
}











sub add_to_run_history
{
my ($runinfo) = @_;

# create the file if it doesnt exist.	
&CJ::create_run_history_file();

my $runinfo_json = encode_json $runinfo;
my $text=<<TEXT;
$runinfo_json
TEXT

    
# ADD THIS SAVE TO HISTRY
open (my $FILE , '>>', $run_history_file) or die("could not open file '$run_history_file' $!");
print $FILE "$text\n";
close $FILE;
}



sub add_change_to_run_history
{
    my ($pid, $change,$type) = @_;
    
	
	# This needs to be comuunicating with remote.
	
    my $info = &CJ::retrieve_package_info($pid);    

if(lc($type) eq "clean"){
    $info->{clean}->{date}  =  $change->{date};
	$info->{clean}->{agent} =  $change->{agent};
    #say Dumper($info);
 	
}elsif(lc($type) eq "rerun"){
    
       if($info->{'rerun'}){
           $info->{'job_id'} = $change->{new_job_id};
           $info->{rerun}->{"$change->{date}->{epoch}"} = $change->{old_job_id};
		   
		   #say Dumper($info);
       }else{
           #firt time calling rerun
           $info->{'job_id'} = $change->{new_job_id};
		   $info->{rerun} = {};
		   $info->{rerun}->{"$change->{date}->{epoch}"} = $change->{old_job_id};
           #say Dumper($info);
       }
#
#        
}else{
       &CJ::err("Change of type '$type' is  not recognized");
}
    
    &CJ::update_record($pid,$info);
	
	return $info;
}




sub update_record{
    my ($pid,$new_info) = @_;
    my $new_record = encode_json($new_info);
    my $cmd="sed -i '' 's|.*$pid.*|$new_record|'  $run_history_file";
    &CJ::my_system($cmd,0);
}


sub read_record{
    my ($pid) = @_;
		
	
	# my $record = `grep -A 1 $pid $run_history_file` ; chomp($record);
	
	my $is_scalar = is_valid_pid($pid) ? 1 : 0;
 	my $pids = $is_scalar ? [$pid] : $pid;  #change the single pid to be a array ref
	
	# get a copy of the array ref as we will destroy this copy in a for loop
	# so the input is intact;
	my @pids =  @{$pids};  
	
		 
		# Do it in perl 
		my $contents = &CJ::readFile($run_history_file);
	    my @records = split(/\n\n/,$contents) if defined($contents);  
  	
		my $regex = "(";
		$regex .= join "|", @pids;
		$regex .= ")";
		
		#print $regex . "\n";
		
	    my $remaining  = scalar @pids;		
		my $record_hash;
		# a reverse loop over the file.
		my $i=$#records;
		while ($i ge 0 & $remaining gt 0 ) {
			my $record  = $records[$i];
		  	#print $record . "\n";
		  	if ($record =~ m/$regex/){
		  		my $matched_pid = $1;
	  		    $record_hash->{$matched_pid} = $record;  # $1 is the captured PID
	  		    # delete this PID from the array
	  		    @pids = grep $_ ne $matched_pid, @pids;
			    $remaining  = scalar @pids;
			    # print "\n$remaining\n";
		  	}
			
		  $i--;  # reverse loop. The older ones are at the end of the file and usually people inqure about the older ones.	
		}
		
		#if ($is_scalar & defined($record_hash)){
		#	 my $key = (keys %$record_hash)[0];
		#	 $record_hash = $record_hash->{$key}  ; # scalar-case;
		#}
	 return defined($record_hash) ? $record_hash : undef;
	
}




sub read_qsub{
    my ($qsub_file) = @_;

    open my $FILE, '<', $qsub_file or CJ::err("Job submission failed. Try --verbose for error explanation.");

my @job_ids;
while(<$FILE>){
    my $job_id_info = $_;chomp($job_id_info);
    my ($this_job_id) = $job_id_info =~/(\d+)/; # get the first string of integer, i.e., job_id
    push @job_ids, $this_job_id;
}
close $FILE;

return \@job_ids;
}


sub remove_extension
{
    my ($program) = @_;
    
    my @program_name    = split /\./,$program;
    my $extension = pop @program_name;
    my $program_name   =   join "\_",@program_name;  # NOTE: Dots in the name are replace by \_

    return ($program_name,$extension);
    
}


sub reexecute_cmd{
    my ($cmd_num,$verbose) = @_;
    if (!$cmd_num){
        $cmd_num = `wc -l < $cmd_history_file `; chomp($cmd_num); $cmd_num =~ s/^\s+|\s+$//g;
    }
    
    my $cmd= &CJ::get_cmd($cmd_num, 0);
    #print "$cmd\n";
    system("$cmd");
}


sub get_cmd{
    my ($cmd_num, $is_interactive) = @_;

    my $cmd;
    if($is_interactive){
    $cmd=`grep '^\\b$cmd_num\\b' $cmd_history_file | awk \'{\$1=\"\";\$2=\"\";\$3=\"\"; print \$0}\' `;
    }else{
    $cmd=`grep '^\\b$cmd_num\\b' $cmd_history_file | awk \'{\$1=\"\"; print \$0}\' `;
    }
    $cmd =~ s/^\s+|\s+$//g;
    return $cmd;
}



sub avail_pids{

    # Get unsorted PIDS and epochs
	my $pid_timestamp = &CJ::read_pid_timestamp();	 
   
    if (!defined($pid_timestamp)){
	CJ::message("No PID available.");
	return;
	}
	
	# Sort hash
	my ($sorted_pids, $sorted_ts) =  &CJ::sort_hash($pid_timestamp);				
	
    #my @unique_pids = do { my %seen; grep { !$seen{$_}++ } @pidList};
	return ($sorted_pids,$sorted_ts);
}


sub sort_hash
{
	my ($hash) = @_;
	
    my @sorted_keys;
    my @sorted_values;
	
    # Sort PIDs by epoch		
	foreach my $key (sort { $hash->{"$a"} <=> $hash->{"$b"} } keys %$hash) {
		push(@sorted_keys, $key);
		push(@sorted_values, $hash->{$key});
 	}
	
	return(\@sorted_keys, \@sorted_values);
}


sub add_cmd{
    my ($cmdline) = @_;
    
	&CJ::create_cmd_file();	# create if there is none;
	
    my $lastnum=`grep "." $cmd_history_file | tail -1  | awk \'{print \$1}\' `;
    if(! $lastnum){
        $lastnum = 0;
    }

    
    
    
    my $cmd_history = sprintf("%-15u%s",$lastnum+1, $cmdline );chomp($cmd_history);
    
    open (my $FILE , '>>', $cmd_history_file) or die("could not open file '$cmd_history_file' $!");
    print $FILE "$cmd_history\n";
    close $FILE;
    
    
    
    my $records_to_keep = 5000;
    my $cmd = "tail -n $records_to_keep $cmd_history_file > /tmp/cmd_history_file.tmp; cat /tmp/cmd_history_file.tmp > $cmd_history_file; rm /tmp/cmd_history_file.tmp";
    system($cmd);
    
}

sub create_info_files{
	&CJ::create_history_file();
	&CJ::create_cmd_file();	
	&CJ::create_run_history_file();
	&CJ::create_pid_timestamp_file();
	&CJ::create_local_push_timestamp_file();
	&CJ::create_lastSync_file();
}

sub create_history_file{	
if( ! -f $history_file ){
	 &CJ::touch($history_file);
	 
		
 	#my $header = sprintf("%-15s%-15s%-21s%-10s%-15s%-20s%-30s", "count", "date", "pid", "action", "machine", "job_id", "message");
 	my $header = sprintf("%-15s%-15s%-15s%-10s%-15s%-40s", "count", "date", "pid", "action", "machine","message");
		
     # ADD THIS SAVE TO HISTRY
     open (my $FILE , '>>', $history_file) or die("could not open file '$history_file' $!");
     print $FILE "$header\n";
     close $FILE; 
	 
}
	
}

sub create_lastSync_file{
		
		if (! -f $lastSync_file) {
		&CJ::touch($lastSync_file);
		&CJ::writeFile($lastSync_file, 0);
	    }
}

sub create_local_push_timestamp_file{
		&CJ::touch($local_push_timestamp_file) unless (-f $local_push_timestamp_file) ;	
}

sub create_cmd_file{
		&CJ::touch($cmd_history_file) unless (-f $cmd_history_file) ;	
}
sub create_pid_timestamp_file{
		&CJ::touch($pid_timestamp_file) unless (-f $pid_timestamp_file) ;	
}
sub create_run_history_file{
&CJ::touch($run_history_file) unless ( -f $run_history_file);
}




1;
