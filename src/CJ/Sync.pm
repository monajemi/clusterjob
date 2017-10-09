package CJ::Sync;


use strict;
use warnings;
use CJ;
use CJ::CJVars;
use Data::Dumper;
use Firebase; 
use Ouch;


# This is a class that takes care of syncing 
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)
# Sept 22 2016

# class constructor
sub new {
 	my $class= shift;
 	my ($agent) = @_;
	
	my $default_interval = 300;  # default 5min;
	my $default_type = "auto";  # default 1min;
	my $self= bless {
		agent => $agent, 
		interval => $default_interval,
		type => $default_type,
	}, $class;
		
	$self->UserRequired();	
		
	return $self;
}

sub UserRequired
{
	my $self = shift;	
	
	my $user_type = &CJ::grep_config_var($remote_config_file, "SYNC_TYPE");
	return unless defined($user_type);
	$self->update("type", $user_type);
	
	# See if user has defined an interval of interest
	my $user_interval = &CJ::grep_config_var($remote_config_file, "SYNC_INTERVAL");
	return unless defined($user_interval);
	$self->update("interval", $user_interval) if ($user_interval =~ m/^\d+$/);
}

sub update
{
	my $self = shift;
	my ($var,$value) = @_;
	$self->{$var} = $value;
}



sub request{
	
	my $self = shift;
	my $agent = $self->{agent};
	
# Current agent should get info from 
# $fb_get->{$agent}->{SyncReq}; and if the value is not
# null,  it should update the corresponding PIDs (keys of the hashref);
# once all updates are done the agent changes the value of todo to null
# to indicate all updates are done.

my $firebase = Firebase->new(firebase => $firebase_name, auth_token => $CJKEY);
# Get todo list

my $fb_get = $firebase->get("users/${CJID}/agents/$agent") ;
return unless defined($fb_get);
my $fb_todo = $fb_get->{SyncReq};
return if ($fb_todo eq "null");

#print "OK\n";

my @pids = keys %$fb_todo;
return unless @pids;
			
		&CJ::message("Sync request...");
		
		my $timestamp_hashref = {};
		 
			foreach my $pid (@pids){
	          
			  	 my $fb_get = $firebase->get("users/${CJID}/pid_list/$pid") ;
				 next if not defined($fb_get);  # if somehow the entry doesnt exist.
				 
				  $timestamp_hashref->{$pid} = $fb_get->{timestamp};			
		           my $newinfo = $fb_get->{info};
				   my $pid_head = 	substr($pid,0,8);			   
				   if(defined(&CJ::read_record($pid))){
			       		&CJ::update_record($pid,$newinfo);
					}else{
					    &CJ::add_to_run_history($newinfo);
				   	}   
				   # If other agent cleaned the package, and if we are 
				   # on local machine that originated that package, clean
				   # local repo.	   
				   if( defined($newinfo->{clean}) &  ($newinfo->{agent} eq $agent) ){
					  
					   		&CJ::message("--- Cleaning local dir for $pid_head");
							my $local_path = $newinfo->{'local_path'};
					        my $save_path = $newinfo->{'save_path'};
						   
						   	my $local_clean     = "$local_path\*";
					       	my $save_clean      = "$save_path\*";
    
					        my $cmd = "rm -rf $local_clean;rm -rf $save_clean;" ;
							my $verbose = 0;
					        &CJ::my_system($cmd,$verbose);
				   }
				   
			
			} # Update all the PIDs	
		   #update  timestamp file;	
		   &CJ::add_to_pid_timestamp($timestamp_hashref) if defined($timestamp_hashref);		
           my $result = $firebase->patch("users/${CJID}/agents/$agent", {"SyncReq" => "null"} ) ;	
}





sub pull_timestamp{
		my $self = shift;
		my $agent = $self->{agent};

# This type of sync is a pull sync. It checkes the pull_timestamp 
# of the agent, and pulls every pid in pid_list that has a bigger 
# timestamp. This is efficient due to firebase indexing.
my $firebase = Firebase->new(firebase => $firebase_name, auth_token => $CJKEY);
my $fb_get = $firebase->get("users/${CJID}/agents/$agent");
return unless defined($fb_get);
my $pull_timestamp = $fb_get->{pull_timestamp};
return unless defined($pull_timestamp);

# update the last instance.
my $last_instance = $firebase->get("users/${CJID}/last_instance");
&CJ::writeFile($last_instance_file, $last_instance->{'pid'}) unless not defined($last_instance->{'pid'});


# get everything bigger than the $pull_timestamp  (Efficient use of Firebase indexing)
my $param_hash  = {"orderBy"=>"\"timestamp\"", "startAt"=>$pull_timestamp};
my $pid_hash = $firebase->get("users/${CJID}/pid_list", $param_hash) ;



# pull and write them locally
my $updated_pull_timestamp = $pull_timestamp;
my $timestamp_hashref = {};
while( my ($pid, $hash) = each(%$pid_hash) ){
	# startAt is inclusive. The pull_timestamp must be removed since 
	# we already have it.
	my  $timestamp  = $hash->{timestamp};
	
	if( ($timestamp ne $pull_timestamp) ){
		    $updated_pull_timestamp = $timestamp unless ($timestamp lt $updated_pull_timestamp);
			if ($hash->{info}{agent} ne $agent){ # Write locally only if this job doesnt belong to this agent.
		  		
				$timestamp_hashref->{$pid} = $timestamp;
				
				my $info = $hash->{info};
	    		my $pid_head = 	substr($pid,0,8);			   
	    		if( defined(&CJ::read_record($pid)) ){
					# This step is not really needed. This is a sanity check really
					# This wont happen if everything goes well. If an interuption happens
					# between now and updating pull_timestap, we prevent duplicate this way.
	     			&CJ::update_record($pid,$info);	
	    		}else{
	 	    		&CJ::add_to_run_history($info);
	    		}	   
			}	
	}
	
} #while
# update timestamp
&CJ::add_to_pid_timestamp($timestamp_hashref) if defined($timestamp_hashref);		

# Update the pull_timestamp
my $result = $firebase->patch("users/${CJID}/agents/$agent", {"pull_timestamp" => $updated_pull_timestamp} ) ;	

}




sub push_timestamp{   
	my $self = shift;
	my $agent = $self->{agent};
	
# This type of sync is a push sync. It checkes the push_timestamp 
# of the agent, and if the local push_timestamp is bigger 
# than the remote counterpart, it sends to the server the local info that hasnt been pushed.
my $firebase = Firebase->new(firebase => $firebase_name, auth_token => $CJKEY);
my $fb_get = $firebase->get("users/${CJID}/agents/$agent");
return unless defined($fb_get);
my $remote_push_timestamp = $fb_get->{push_timestamp};
return unless defined($remote_push_timestamp);

my $local_push_timestamp = $self->GetLocalPushTimeStamp(); 
return unless defined($local_push_timestamp);
	
return if ($remote_push_timestamp == $local_push_timestamp);	
CJ::warning("CJ is in awe! Push TimeStamp:: remote is bigger than local") if ($remote_push_timestamp > $local_push_timestamp);	 


	# comprare the two
	if( $remote_push_timestamp < $local_push_timestamp ){ # Some data are missing from Firebase
		
		&CJ::message("Sending data missing from the cloud. Please be patient...");
			# Patch all data that are available locally 
			# but missing on FB
			
			
			my $pid_timestamp = &CJ::read_pid_timestamp();
			my @filtered_pids = grep { $pid_timestamp->{$_} > $remote_push_timestamp } keys %$pid_timestamp;
			my $info_hash = &CJ::retrieve_package_info(\@filtered_pids);
			
            return if not defined($info_hash);
			my $size = keys %$info_hash;
			my $counter = 0;
			while ( my ($pid,$info) = each (%$info_hash)){
				my $timestamp = $info->{date}{epoch};
				my $inform    = 1;
				$counter++;
				CJ::message("$counter/$size: $pid",1);
		  		&CJ::write2firebase($pid,$info,$timestamp, $inform) unless ($info->{agent} ne $AgentID); # not responsible for other agnets mess. The agent might have been already deleted, etc. We only push our own!		
			}
	  				
	  }
	
	
	
}




sub GetLocalPushTimeStamp
{
	
	my $self = shift;	
	# Get local epoch
	my $local_push_timestamp   =   `sed -n '1{p;q;}' $local_push_timestamp_file`;chomp($local_push_timestamp);
	
	if( (not defined $local_push_timestamp) || ($local_push_timestamp eq "") ){
		return undef;
	}else{
		return $local_push_timestamp;
	}
	
}





1;
