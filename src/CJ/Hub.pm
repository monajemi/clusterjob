package CJ::Hub;

use strict;
use warnings;
use CJ;
use CJ::CJVars;
use CJ::Install;
use Data::Dumper;
use LWP::Simple;
use HTTP::Request::Common qw(POST);
use JSON;
use HTTP::Thin;




sub new{
    my $class = shift;
    my ($pid) = @_;
    my $self = bless {
        pid => $pid
	}, $class;

    return $self;
}


sub create_and_upload {
    my $self = shift;
    my ($verbose) = @_;

    my $info = &CJ::get_info($self->{pid});
    my $pid = $info->{pid};
    my $ssh = CJ::host($info->{machine});

    my ($program_name, $extension) = &CJ::remove_extension($info->{program});

    &CJ::message("Uploading to CJHub");

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
    my $run_upload = "cd $ssh->{remote_repo}/$program_name; perl $ssh->{remote_repo}/$program_name/upload_script.pm $CJID $pid $ssh->{remote_repo}/$program_name > ~/upload_log.txt'";
    &CJ::my_system($ssh_upload.' '.$env_var.' '.$run_upload, $verbose);
}

sub send {
    my $self = shift;
    my $info = &CJ::retrieve_package_info($self->{pid});
    my $cj_install = CJ::Install->new("perl_modules", $info->{machine}, undef);
    $cj_install->__libssl();
    $cj_install->__setup_cj_hub('0');
    $self->create_and_upload()
}

sub share{
    my $self = shift;
    my ($shared_with) = @_;
    my $url = 'https://us-central1-united-pier-211422.cloudfunctions.net/sharePID';
    
    if(!&CJ::is_valid_pid($self->{pid})){
        &CJ::err("$self->{pid} is not a valid PID");
    };

    my $info = &CJ::get_info($self->{pid});

    # The first digit of permission is extra 
    # The second is download EXPCJ and RESULTS
    # The third is replicate
    # The forth is reproduce

    my %payload = (
        "cjid" => $CJID,
        "cjpass" => $CJKEY,
        "pid" => $info->{pid},
        "permission_val" => '0111', 
        "shared_with" => $shared_with
    );
    
    my $call = POST($url, Content => encode_json(\%payload), Content_Type => 'application/json');
    print Dumper(HTTP::Thin->new()->request($call)->decoded_content);
}

sub receive{
    my $self = shift;

    &CJ::message("Verifying Permissions", 1);


    my %payload = (
        cjid => $CJID,
        pid => $self->{pid}
     );
    
    my $call = POST("https://us-central1-united-pier-211422.cloudfunctions.net/receivePerms", Content => encode_json(\%payload), Content_Type => 'application/json');
    
    my $response = HTTP::Thin->new()->request($call);
    if($response->{"_rc"} != 200){
        &CJ::message("Permission Denied Or Error", 1);
        print(Dumper($response));
        die;
    }
    my $token = $response->decoded_content;

    &CJ::message("Getting EXPCJ and RESULTS from CJHub", 1);
    system("mkdir $install_dir/receive &> /dev/null");

    # FIXME: Shouldn't be hard coding united-pier-211422 should be using CJ Var
    my $url = "https://firebasestorage.googleapis.com/v0/b/united-pier-211422.appspot.com/o/$self->{pid}%2FEXPCJ.tar.gz?alt=media&token=$token";
    
    my $efile = "$install_dir/receive/EXPCJ.tar.gz";

    # FIXME: Pipe the output of this to /dev/null
    system("curl '$url' > $efile");

    $url = "https://firebasestorage.googleapis.com/v0/b/united-pier-211422.appspot.com/o/$self->{pid}%2FRESULTS.tar.gz?alt=media&token=$token";

    # ("curl '$url' > $efile &> /dev/null");
    my $rfile = "$install_dir/receive/RESULTS.tar.gz";

    system("curl '$url' > $rfile");

    &CJ::message("Creating $install_dir/receive/$self->{pid}", 1);


    system("mkdir $install_dir/receive/$self->{pid}");
    system("tar -C $install_dir/receive -xvf $efile &> /dev/null");
    system("tar -C $install_dir/receive -xvf $rfile &> /dev/null");
    system("rm $rfile $efile &> /dev/null");
    
    &CJ::message("Package $self->{pid} available at $install_dir/receive/", 1);

}


## Helper Functions
#################
sub setup{
#################    
    my $self = shift;
    my ($machine) = @_;

    my $cj_install = CJ::Install->new("perl_modules", $machine, undef);
    $cj_install->__libssl();
    $cj_install->__setup_cj_hub();
}

1;