use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use LWP::UserAgent ();
use HTTP::Request::Common qw(DELETE PUT GET POST);
use JSON;
use Data::Dumper;
use strict;
use warnings;

sub orchastrate_upload{
    my ($cj_id, $pid, $code) = @_;	
    my $agent = LWP::UserAgent->new;
    my $zipedFile = compress($code);
    my $upload_url = get_upload_url($zipedFile, $cj_id, $pid, $agent);
    my $status = get_status($upload_url, $agent, $zipedFile);
    my $offset = 0;

    print($upload_url);

    while(!$status->is_success) {
        upload_file($zipedFile, $agent, $upload_url, $offset, $cj_id, $pid);
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


sub get_status{
    my ($upload_url, $agent, $zipedFile, $cj_id) = @_;	
    my $file_size = -s $zipedFile;


    my $metadata = "{\"metadata\": { \"parent\": \"bekk\" } }";
    my $status = $agent->request(
        POST(
            $upload_url, 
            "Content-Length" => length("bekk"),
            "Content_Type" => 'application/json',
            "Content-Range" =>  "bytes */$file_size",
            Content => $metadata
        )
    );

    print "\nLocation Link info \n\n";
    print Dumper($status);

    return $status;
}

sub compress{
    my ($code) = @_;	
    # Get and validate the file
    my $zip;
    if(-e $code){
        print "Code File Valid - Compressing";
        # Compress the file
        $zip = Archive::Zip->new();
        my $dir_member = $zip->addTree( $code, 'experiment' );
        unless ( $zip->writeToFileNamed('someZip.zip') == AZ_OK ) {
            die 'Failed to Compress Directory - write error';
        }
        return 'someZip.zip';
    }else{
        print "File Path Invalid";
        return "";
    }
}


sub get_upload_url{
    my ($zipedFile, $cj_id, $pid, $agent) = @_;
    my %payload = (
        filename => $pid,
        contentType => 'multipart/form-data',
        "Content-Length" => -s $zipedFile,
         cj_id => $cj_id,
    );


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

sub add_meta_data{

}

sub upload_file {
    my ($zipedFile, $agent, $upload_url, $offset, $cj_id, $pid) = @_;

    my $size = -s $zipedFile;
    my $buffer;
    my $openZiped;

    open $openZiped, $zipedFile;
    sysread($openZiped, $buffer, $size - $offset, $offset);



    my $put_request = 
        PUT(
            $upload_url, 
            Content_Type => 'form-data', 
            Content => [
                file => $buffer,
                "Content-Length" => $size,
                "Content-Range" =>  "bytes $offset-$size"
            ]
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


my ($cj_id, $pid, $code) = @ARGV;
orchastrate_upload($cj_id, $pid, $code);