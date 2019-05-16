package CJ::Hub;

use strict;
use warnings;
use CJ;
use CJ::CJVars;
use CJ::Install;
use Data::Dumper;
use LWP::Simple;
use JSON;



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
    my $run_upload = "cd $ssh->{remote_repo}/$program_name; perl $ssh->{remote_repo}/$program_name/upload_script.pm $CJID $pid $ssh->{remote_repo}/$program_name > ~/upload_log.txt'";
    &CJ::my_system($ssh_upload.' '.$env_var.' '.$run_upload, $verbose);
}

sub send {
    my $self = shift;
    $self->create_and_upload()
}

# sub share{
#     my $self = shift;
#     my ($shared_with) = @_;
#     my $url = 'https://us-central1-united-pier-211422.cloudfunctions.net/share';
    
#     my %payload = (
#         "cjid" => CJID,
#         "cjpass" => CJKEY,
#         "pid" => $self->{pid},
#         "permission" => 1111,
#         "shared_with" => $shared_with
#     );
    
#     my $call = POST($url, Content => encode_json(\%payload), Content_Type => 'JSON(application/json)');
# }

sub receive{
    my $self = shift;

    system("mkdir $install_dir/receive");
    my $url = "https://firebasestorage.googleapis.com/v0/b/united-pier-211422.appspot.com/o/$self->{pid}%2FEXPCJ.tar.gz?alt=media";
    
    my $efile = "$install_dir/receive/EXPCJ.tar.gz";

    getstore($url, $efile);

    $url = "https://firebasestorage.googleapis.com/v0/b/united-pier-211422.appspot.com/o/$self->{pid}%2FRESULTS.tar.gz?alt=media";

    my $rfile = "$install_dir/receive/RESULTS.tar.gz";

    getstore($url, $rfile);

    system("mkdir $install_dir/receive/$self->{pid}");
    system("tar -C $install_dir/receive -xvf $efile");
    system("tar -C $install_dir/receive -xvf $rfile");
    system("cd $install_dir/receive/; tar -zcvf $self->{pid}.tar.gz $self->{pid}");
    system("rm $rfile $efile");

}

1;