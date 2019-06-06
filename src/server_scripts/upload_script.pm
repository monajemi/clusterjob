use Archive::Tar;
use LWP::UserAgent ();
use HTTP::Request::Common qw(DELETE PUT GET POST);
use JSON;
use Data::Dumper;
use File::Find;
use strict;
use warnings;

sub orchastrate_upload{
    my ($cj_id, $pid, $code) = @_; # TODO code -> path
    my $agent = LWP::UserAgent->new;
    my @files = ('EXPR', 'EXPCJ', 'RESULTS');
    compress_expr($code, $pid);
    compress_expcj($code, $pid);
    my @expcj_tree = Archive::Tar->new("EXPCJ.tar.gz")->list_files();
    compress_results($code, list_only_files(\@expcj_tree, $code) , $pid);

    foreach (@files){
        my $name = $_;
        # Go through the names
        my $zipedFile = "$name\_$pid.tar.gz";
        my $upload_url = get_upload_url($zipedFile, $cj_id, $name.'.tar.gz', $pid, $agent);
        my $status = get_status($upload_url, $agent, $zipedFile);
        my $offset = 0;

        while(!$status->is_success) {
            upload_file($zipedFile, $agent, $upload_url, $offset, $cj_id);
            do {
                $status = get_status($upload_url, $agent, $zipedFile, $cj_id);
                if($status->code == 308){
                    print "Range Header", $status->header("range");
                    if($status->header("range")){
                        $offset = $status->header("range");
                        $offset =~ s/.*[-]//;
                        print "Offset: ", $offset;
                    }
                }
                sleep 1;
            }while(!$status->is_success && $status->code != 308)
        }
    }
}


sub get_status{
    my ($upload_url, $agent, $zipedFile) = @_;

    my $file_size = -s $zipedFile;

    my $status = $agent->request(
        POST(
            $upload_url, 
            "Content-Length" => 0,
            "Content_Type" => 'application/json',
            "Content-Range" =>  "bytes */$file_size",
        )
    );
    
    print "\nLocation Link info \n\n";
    # print Dumper($status);

    return $status;
}


sub get_upload_url{
    my ($zipedFile, $cj_id, $name, $pid, $agent) = @_;
    my %payload = (
        pid => $pid,
        filename => $name,
        contentType => 'multipart/form-data',
        "Content-Length" => -s $zipedFile,
         cj_id => $cj_id,
    );

    # print("This is the UPLOAD URL Data: \n");
    # print(Dumper(encode_json(\%payload)));


    my $upload_url = $agent->request(
        POST(
            "https://us-central1-united-pier-211422.cloudfunctions.net/getSignedResUrl", 
            Content_Type => 'application/json', 
            Content => encode_json(\%payload)
        )
    );

    if($upload_url->is_success){
        return $upload_url->decoded_content;
    }else{
        die Dumper($upload_url);
    }
}

sub upload_file {
    my ($zipedFile, $agent, $upload_url, $offset, $cj_id) = @_;
    my $size = -s $zipedFile;
    my $buffer;
    my $openZiped;

    open $openZiped, $zipedFile;
    sysread($openZiped, $buffer, $size - $offset, $offset);


    # FIXME: Make sure resumability works
    my $put_request = 
        PUT(
            $upload_url, 
            Content_Type => 'form-data', 
            Content =>  $buffer,
            Header => {
                "Content-Length" => -s $buffer,
                "Content-Range" =>  "bytes $offset-$size"
            }
        );

    print "\nUploading\n";
    my $file_upload = $agent->request($put_request);

    if($file_upload->is_success){
        print "File Uploaded Successfully";
        return 200;
    }

    return $file_upload->status_line;

    return 500;

}


# Compression and File Manipulation on the Cluster

sub compress_expr{
    my ($code, $pid) = @_;	
    my $tar = Archive::Tar->new();

    # Read file for EXP Raw and add the files to archive
    my $filename = "$pid/expr.txt"; # expr.txt -> expr.cjhub
    open(my $fh, '<:encoding(UTF-8)', $filename)
    or die "Could not open file '$filename' $!";
    
    print "Code File Valid - Compressing\n";
    while (my $row = <$fh>) {
        chomp $row;
        if(-e "$pid/$row"){
            my $dir_member = $tar->add_files( "$pid/$row" );
        }else{
            print "$pid/$row - File Path Invalid\n";
        }
    }
    $tar->write("EXPR_$pid.tar");
    gzip_tar("EXPR_$pid.tar");

}

sub compress_results{
    my ($code, $excluded_code_ref, $pid) = @_;
    my @excluded_code = @{$excluded_code_ref};	
    my $tar;
    $tar = Archive::Tar->new();
    # Exclude expcj stuff
    foreach my $file (@{directory_path_list("$pid")}) {
        if(!($file ~~ @excluded_code) ){
            $tar->add_files( $file );            
        }
    }
    $tar->write("RESULTS_$pid.tar");  
    gzip_tar("RESULTS_$pid.tar");
}

sub compress_expcj{
    my ($code, $pid) = @_;	
    # Get the CJ Experiment, 
    # which is just the tar file already in the remote repo with cjrandstate.pickle added
    my $tar;
    $tar = Archive::Tar->new("./$pid.tar.gz");

    # Find and add cjrandstate.*
    # Searches through each directory and gives the relative path whenever it finds a rand
    foreach my $path (@{get_cjdir_files($pid)}){
        $tar->add_files( $path );
    }

    $tar->write("EXPCJ_$pid.tar");
    gzip_tar("EXPCJ_$pid.tar");
}

sub get_cjdir_files{
    my ($directory_name) = @_;
    my @paths;

    # # Open CJDir Files
    # my $filename = "$pid/expr.txt"; # expr.txt -> expr.cjhub
    # open(my $fh, '<:encoding(UTF-8)', $filename)
    # or die "Could not open file '$filename' $!";

    # while (my $row = <$fh>) {
    #     chomp $row;
    #     if(-e "$row"){
    #         my $dir_member = $tar->add_files( "$row" );
    #     }else{
    #         print "$row - File Path Invalid\n";
    #     }
    # }
    my $cjdir_str = "CJrandState";

    *wanted_cjrand = sub {
        if(-d $File::Find::name){
            $File::Find::prune = 1;
        }elsif (index($File::Find::name, $cjdir_str) != -1) {
            push @paths, $File::Find::name;
        } 
    };

    find( \&wanted_cjrand, $directory_name);


    print("EXPCJ: This is the directory paths for this directory $directory_name \n @paths \n\n");

    return \@paths;
}

# Get every file with it's path in a directory
sub directory_path_list{
    my ($directory_name) = @_;
    my @paths;

    # This is for File::Find
    *wanted_dir = sub{
        if(-d $File::Find::name){
            $File::Find::prune = 1;
        }else{
            push @paths, $File::Find::name;
        }
        return;
    };

    find( \&wanted_dir, $directory_name);


    print("EXPR: This is the directory paths for this directory $directory_name \n @paths \n\n");

    return \@paths;
}


# Accept regex and a directory and return the relative paths of each file fitting the regular expression
sub get_relative_path{
    my ($absolute_path, $parent_path) = @_;
    $absolute_path =~ s/$parent_path/''/g;
    return $absolute_path;
}

sub list_only_files{
    my ($tar_file_names_ref, $parent_path) = @_;
    my @tar_file_names = @{$tar_file_names_ref};
    my @cleaned_file_names;
    foreach my $file (@tar_file_names){
        # If it's not a folder we want to include it in the exclude list
        if(!(-d $file)){
            push(@cleaned_file_names, get_relative_path($file, $parent_path));
        }
    }
    return \@cleaned_file_names;
}

sub gzip_tar{
    my ($tar_file_name) = @_;
    system("gzip $tar_file_name");
}


# Start the Upload

my ($cj_id, $pid, $code) = @ARGV;
orchastrate_upload($cj_id, $pid, $code);