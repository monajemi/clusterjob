package CJ::Hub;

use strict;
use warnings;
use CJ;
use CJ::CJVars;
use Data::Dumper;


sub new{
    my $class = shift;
    my ($pid, $master_script) = @_;
    my $self = bless {
        pid => $pid,
        master_script => $master_script
	}, $class;
}


sub create_and_upload {
    $self = shift;
    my ($verbose) = @_;

    $pid = $self->{pid};

    my $info = &CJ::retrieve_package_info($pid);


     # Upload server_scripts/upload_script.pm to the server
    $cmd = "scp  $hub_scripts_dir/upload_script.pm /tmp/$pid";
    &CJ::my_system($cmd, $verbose);
    $self->{master_script} .= "perl /tmp/$pid/upload_script.pm $CJID $pid $info->{}"

}