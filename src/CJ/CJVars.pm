package CJ::CJVars;
# This is part of Clusterjob 
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu) 

use strict;
use warnings;
use parent 'Exporter'; # imports and subclasses Exporter
use File::Basename qw(dirname);
use File::Spec;
use IO::Socket::INET;



my $sock = IO::Socket::INET->new(
    PeerAddr=> "example.com",
    PeerPort=> 80,
    Proto   => "tcp");
if (!defined($sock)){
	print "No internet connection!\n";exit 0;
}	
our $localIP = $sock->sockhost; chomp($localIP);




our $localUserName = `id -un`;chomp($localUserName);  # Later on add the CJusername
my  $CJ_dir			 = File::Basename::dirname(File::Spec->rel2abs(__FILE__));
my  @CJ_dir_array    = split '/',$CJ_dir;
my  $lastone 		 = pop @CJ_dir_array;
our $src_dir  		 = join '/', @CJ_dir_array;


my  $second2last  = pop @CJ_dir_array;
our $install_dir  = join '/', @CJ_dir_array;
our $info_dir     = "$install_dir/.info";

our $HOME            = $ENV{"HOME"};
our $localPrefix     = "$HOME/RunRepo_local/";
our $savePrefix      = "$HOME/Dropbox/clusterjob_saveRepo/";

our $last_instance_file = "$install_dir/.info/last_instance.info";
our $CJlog              = "$install_dir/.info/CJcall.log";
our $AgentIDPATH	 	= "$install_dir/.info/agent_id";  # The UUID of installation

our $get_tmp_dir        = "$install_dir/../CJ_get_tmp";
our $history_file       = "$info_dir/history.info";
our $cmd_history_file   = "$info_dir/cmd_history.info";
our $run_history_file   = "$info_dir/run_history.info";
our $pid_timestamp_file = "$info_dir/pid_timestamp.info";
our $local_push_timestamp_file = "$info_dir/local_push_timestamp";
our $lastSync_file      = "$info_dir/last_sync";
our $save_info_file     = "$info_dir/save.info";
our $ssh_config_file    = "$install_dir/ssh_config";
our $remote_config_file = "$install_dir/cj_config";
our $firebase_name		= "clusterjob-78552";     
# Read AgentID
our $AgentID= undef;

if(-f $AgentIDPATH){
	my $line;
	
open(my $FILE,  $AgentIDPATH) or  die "could not open $AgentIDPATH: $!";
local $/ = undef;
$line = <$FILE>;
close ($FILE);
chomp($line);
$AgentID= $line;
if($AgentID){$AgentID =~ s/^\s+|\s+$//g};
}


# Read CJID and CJKEY 
our $CJID =undef;
our $CJKEY=undef;
my $lines;
open(my $FILE, $remote_config_file) or  die "could not open $remote_config_file: $!";
local $/ = undef;
$lines = <$FILE>;
close ($FILE);

my ($ID) = $lines =~ /^CJID(.*)/im;  if($ID){$ID =~ s/^\s+|\s+$//g};
my ($KEY) = $lines =~/^CJKEY(.*)/im; if($KEY) {$KEY=~ s/^\s+|\s+$//g};

if($ID){
	$CJID = $ID;
}else{
    die(' ' x 5 . "CJerr::Please provide your CJ ID in $remote_config_file\n");
}

if($KEY){
	$CJKEY=$KEY;
}






# Export global variables
our @EXPORT = qw( $lastSync_file $local_push_timestamp_file $pid_timestamp_file $firebase_name $AgentIDPATH $AgentID $CJID $CJKEY $info_dir $src_dir $install_dir $remotePrefix $localPrefix $savePrefix $last_instance_file $get_tmp_dir $history_file $cmd_history_file $run_history_file $save_info_file $ssh_config_file $remote_config_file $CJlog $localIP $localHostName $localUserName);



1;
