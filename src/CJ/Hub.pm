package CJ::Hub;

use strict;
use warnings;
use CJ;
use CJ::CJVars;
use CJ::Install;
use Data::Dumper;


sub new{
    my $class = shift;
    my ($pid, $master_script) = @_;
    my $self = bless {
        pid => $pid,
        master_script => $master_script
	}, $class;

    return $self;
}

sub install_requirements {
    my $self = shift;
    my ($ssh, $verbose) = @_;
    # Setup local::lib
    # Install LWP::UserAgent, JSON
    # my $install_local_lib = 
    # &CJ::my_system($install_local_lib, $verbose);
}

sub create_and_upload {
    my $self = shift;
    my ($verbose) = @_;

    my $pid = $self->{pid};

    print("Testing");
    my $info = &CJ::retrieve_package_info($pid);
    my $ssh = CJ::host($info->{machine});
    my $cj_install = CJ::Install->new("perl_modules",$info->{machine},undef);
    $cj_install->__local_lib();
    $cj_install->__libssl();
    $cj_install->__lwp_useragent();
    $cj_install->__json();

    # $self->install_requirements($ssh, $verbose);

    # Upload server_scripts/upload_script.pm to the server
    my $cmd = "scp $hub_scripts_dir/upload_script.pm $ssh->{account}:/tmp";
    &CJ::my_system($cmd, $verbose);
    my $ssh_upload = "ssh $ssh->{account} -t '";
    my $env_var = '
        PATH="/home/ubuntu/perl5/bin${PATH:+:${PATH}}"; export PATH;
        PERL5LIB="/home/ubuntu/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
        PERL_LOCAL_LIB_ROOT="/home/ubuntu/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
        PERL_MB_OPT="--install_base \"/home/ubuntu/perl5\""; export PERL_MB_OPT;
        PERL_MM_OPT="INSTALL_BASE=/home/ubuntu/perl5"; export PERL_MM_OPT;
    ';
    my $run_upload = "perl /tmp/upload_script.pm $CJID $pid $ssh->{remote_repo} > uploadLog.txt'";
    &CJ::my_system($ssh_upload.' '.$env_var.' '.$run_upload, $verbose);
#     $self->{"master_script"} .= "perl /tmp/$pid/upload_script.pm $CJID $pid $info > uploadLog.txt";
}

sub send {
    my $self = shift;
    # Check that the PID hasn't been sent, should we override?
    $self->create_and_upload()
}

1;