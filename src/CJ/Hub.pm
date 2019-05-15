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


sub create_and_upload {
    my $self = shift;
    my ($verbose) = @_;

    my $info = &CJ::retrieve_package_info($self->{pid});
    my $pid = $info->{pid};
    my $ssh = CJ::host($info->{machine});

    my ($program_name, $extension) = &CJ::remove_extension($info->{program});

    &CJ::message("$ssh->{remote_repo}");

    # Upload server_scripts/upload_script.pm to the server
    my $cmd = "scp $hub_scripts_dir/upload_script.pm $ssh->{account}:$ssh->{remote_repo}/$program_name";
    &CJ::my_system($cmd, $verbose);
    my $ssh_upload = "ssh $ssh->{account} -t '";
    my $env_var = '
        PATH="/home/ubuntu/perl5/bin${PATH:+:${PATH}}"; export PATH;
        PERL5LIB="/home/ubuntu/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
        PERL_LOCAL_LIB_ROOT="/home/ubuntu/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
        PERL_MB_OPT="--install_base \"/home/ubuntu/perl5\""; export PERL_MB_OPT;
        PERL_MM_OPT="INSTALL_BASE=/home/ubuntu/perl5"; export PERL_MM_OPT;
    ';
    # TODO FIX THIS HARDCODING
    my $run_upload = "cd $ssh->{remote_repo}/$program_name; perl $ssh->{remote_repo}/$program_name/upload_script.pm $CJID $pid $ssh->{remote_repo}/$program_name'";
    &CJ::my_system($ssh_upload.' '.$env_var.' '.$run_upload, $verbose);
}

sub send {
    my $self = shift;
    # Check that the PID hasn't been sent, should we override?
    $self->create_and_upload()
}

1;