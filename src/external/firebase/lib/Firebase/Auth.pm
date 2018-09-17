package Firebase::Auth;

use strict;
use warnings;
use Digest::SHA qw(hmac_sha256);
use JSON::XS;
use POSIX;
use MIME::Base64;
use Moo;
use HTTP::Thin;
use Ouch;
use JSON;
use HTTP::Request::Common qw(POST GET);
use DateTime;
use Data::Dumper;
#use Crypt::JWT qw(decode_jwt);


has token_version => (
    is      => 'rw',
    default => sub { 0 },
);

has firebase => (
    is          => 'ro',
    required    => 1,
);

has secret => (
    is       => 'rw',
    required => 1,
);

has custom_token => (
    is       => 'rw',
    required => 0,
    predicate => 'has_custom_token'
);

has api_key => (
    is       => 'rw',
    required => 1,
);

has data => (
    is          => 'rw',
    predicate   => 'has_data',
);

has token_seperator => (
    is      => 'rw',
    default => sub { '.' },
);

has expires => (
    is          => 'rw',
    predicate   => 'has_expires',
);

has custom_expires => (
    is          => 'rw',
    predicate   => 'has_custom_expires',
);

has not_before => (
    is          => 'rw',
    predicate   => 'has_not_before',
);

has admin => (
    is          => 'rw',
    predicate   => 'has_admin',
);

has debug => (
    is          => 'rw',
    predicate   => 'has_debug',
);

has token_provider => (
    is          => 'ro',
    required    => 0,
    lazy        => 1,
    default     => sub { HTTP::Thin->new() },
);

has id_token => (
    is          => 'rw',
    required => 0,
    predicate => 'has_id_token'
);

has id_token_path => (
    is => 'ro',
    required => 1,
    default=> sub{'./.id_token'}
);

# Check if the current authentication token is expired
# if so create a new one and return it
sub create_token {
  my ($self) = @_;
    # we are expired. get a new custom token and exchange for an id_token
    ouch("Token is not expired yet. Method called by mistake.") if (! $self->has_expires);
    
    $self->get_custom_token(); # This sets the custom token attr
    my $cred = $self->get_id_token();
    my $json=encode_json($cred);
    writeFile($self->id_token_path,$json);
    return $cred->{'token'};
}
    
    
sub read_id_token {
    
    my ($self) = @_;
    
    my $cred= eval{decode_json( readFile( $self->id_token_path ) ) };
    if ($@) {
        $cred = undef;
    }
    return $cred;
}



sub get_id_token{
    
    my ($self) = @_;
    
    ouch("no custom token generated") if (!$self->has_custom_token);
    
    # make a call to google for an exchange
    my $url = 'https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyCustomToken?key=';
    $url .= $self->api_key;
    
    my %payload = (
        token => $self->custom_token,
        returnSecureToken => 'true'
     );
    
    my $call = POST($url, Content => encode_json(\%payload), Content_Type => 'JSON(application/json)');
    
    my $expires = DateTime->now(time_zone=>'local')->add(seconds => 3600);
    my $id_token=decode_json($self->token_provider->request($call)->decoded_content)->{idToken};
    
    return {'token'=>$id_token,'exp'=>$expires->epoch()};
}

    
    
sub get_custom_token {
    
  my ($self) = @_;
    
  my $url = 'https://us-central1-clusterjob-78552.cloudfunctions.net/customToken?cjkey=';
  $url .= $self->secret;
  my $call = GET($url, Content_Type => 'JSON(application/json)');
  $self->custom_expires(DateTime->now(time_zone=>'local')->add(seconds => 3600));
  my $result=$self->token_provider->request($call)->decoded_content;
  $self->custom_token(decode_json($result)->{token});
}


sub get_token {
  my ($self) = @_;
    
    #read the id_token is it exists
    my $cred = $self->read_id_token();
    
    # set the expires if the token's are expired.
    if(!defined($cred)){
        # no file detected
        $self->expires( DateTime->now(time_zone=>'local') );
    }else{
        # there exists an id_token, check to see whethere it expired.
        # my $id_token=$cred->{'token'};
        # my $expiration_epoch = #decode_jwt(token => $id_token, ignore_signature=>1)->{exp}; # we can infer too if we want
        # if the token has expired set the expires slot;
        my $exp = DateTime->from_epoch( epoch => ($cred->{'exp'}-120)   );  # compare with two min before actual expiration
        $self->expires( $exp ) if ( DateTime->compare( $exp, DateTime->now(time_zone=>'local')) < 0 );
    }
  
    my $token = $self->expires ? $self->create_token : $cred->{'token'};
    return $token;
}




sub create_jwt {
    my ($self, $data) = @_;
    return $self->encode_token($self->create_claims($data || $self->data));
}

sub create_claims {
    my ($self, $data) = @_;
    if (! exists $data->{uid}) {
        ouch('missing param', 'Data payload must contain a "uid" key that must be a string.', 'uid') unless $self->admin;
    }
    elsif ($data->{uid} eq '') {
        ouch('param out of range', 'Data payload must contain a "uid" key that must not be empty or null.', 'uid');
    }
    elsif (length $data->{uid} > 256) {
        ouch('param out of range', 'Data payload must contain a "uid" key that must not be longer than 256 characters.', 'uid');
    }
    my %claims = (
        v       => $self->token_version,
        iat     => mktime(localtime(time)),
        d       => $data,
    );
    $claims{admin} = $self->admin if $self->has_admin;
    $claims{exp}   = $self->expires if $self->has_expires;
    $claims{nbf}   = $self->not_before if $self->has_not_before;
    $claims{debug} = $self->debug if $self->has_debug;
    return \%claims;
}

sub encode_jwt {
    my ($self, $claims) = @_;
    my $ejsn = JSON::XS->new->utf8->space_after->encode ({'typ'=> 'JWT', 'alg'=> 'HS256'}) ;
    my $encoded_header = $self->urlbase64_encode( $ejsn);
    my $eclm = JSON::XS->new->utf8->space_after->encode ($claims);
    my $encoded_claims = $self->urlbase64_encode( $eclm );
    my $secure_bits = $encoded_header . $self->token_seperator . $encoded_claims;
    return $secure_bits . $self->token_seperator . $self->urlbase64_encode($self->sign($secure_bits));
}



sub urlbase64_encode {
    my ($self, $data) = @_;
    $data = encode_base64($data, '');
    $data =~ tr|+/=|\-_|d;
    return $data;
}

sub sign {
    my ($self, $bits) = @_;
    return hmac_sha256($bits, $self->secret);
}


sub escape {
    my $string = shift;
    $string =~ s{([\x00-\x29\x2C\x3A-\x40\x5B-\x5E\x60\x7B-\x7F])}
    {'%' . uc(unpack('H2', $1))}eg; # XXX JavaScript compatible
    $string = encode('ascii', $string, sub { sprintf '%%u%04X', $_[0] });
    return $string;
}







# helper functions
sub writeFile
{
    # it should generate a bak up later!
    my ($path, $contents, $flag) = @_;
    
    if( -e "$path" ){
        #bak up
        my $bak= "$path" . ".bak";
        my $cmd="cp $path $bak";
        system($cmd);
    }
    
    my $fh;
    open ( $fh , '>', "$path" ) or die "can't create file $path" if not defined($flag);
    
    if(defined($flag) && $flag eq '-a'){
        open( $fh ,'>>',"$path") or die "can't create file $path";
    }
    
    print $fh $contents;
    close $fh ;
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










=head1 NAME

Firebase::Auth - Auth token generation for firebase.com.

=head1 SYNOPSIS

 use Firebase::Auth;

 my $token = Firebase::Auth->new(token => 'xxxxxxxxx', admin => 'true', data => { uid => '1' } )->create_token();


=head1 DESCRIPTION

This module provides a Perl class to generate auth tokens for L<http://www.firebase.com>. See L<https://www.firebase.com/docs/security/custom-login.html> for details on the spec.


=head1 METHODS


=head2 new

Constructor.

=over

=item data

Optional. If you don't specify this, then you need to specify it when you call create_token(). This should be a hash reference of all the data you want to pass for user data. This data will be available as the C<auth> object in Firebase's security rules. If you do specify it, then it must have a C<uid> key that contain's the users unique user id, which must be a non-null string that is no longer than 256 characters.

=item secret

Required. The api secret token provided by firebase.com.

=item admin

Defaults to C<\0>. If set to C<\1> (a reference to zero or one) then full access will be granted for this token.

=item debug

Defaults to C<\0>. If set to C<\1> (a reference to zero or one) then verbose error messages will be returned from service calls.

B<NOTE:> To access debug info, call C<debug> on the L<Firebase> object after making a request.

=item expires

An epoch date. Defaults to expiring 24 hours from the issued date.

=item not_before

An epoch date. The opposite of C<expires>. Defaults to now. The token will not be valid until after this date.

=item token_version

Defaults to C<0>.

=item token_separator

Defaults to C<.>

=back


=head2 urlbase64_encode

URL base-64 encodes a string, and then does some minor translation on it to make it compatible with Firebase.

=over

=item string

The string to encode.

=back




=head2 create_token

Generates a signed token. This is probably the only method you'll ever need to call besides the constructor.

=over

=item data

Required if not specified in constructor. Defaults to the C<data> element in the constructor. A hash reference of parameters you wish to pass to the service. If specified it must have a C<uid> key that contain's the users unique user id, which must be a non-null string that is no longer than 256 characters.

=back



=head2 create_claims

Generates a list of claims based upon the options provided to the constructor.

=over

=item data

Required. A hash reference of user data you wish to pass to the service. It must have a C<uid> key that contain's the users unique user id, which must be a non-null string that is no longer than 256 characters.

=back



=head2 encode_token

Encodes, signs, and formats the data into a token.

=over

=item claims

Required. A list of claims as created by C<create_claims>

=back


=head2 sign

Generates a signature based upon a string of data.

=over

=item string

A string to sign.

=back



=head1 EXCEPTIONS

This module may L<Ouch> exceptions.

=head2 missing param

This will be thrown if a required parameter was not set. For example the C<uid> key in the C<data> payload.

=head2 param out of range

This will be thrown if a parameter is outside it's acceptable range. For example the C<uid> key in the C<data> payload.



=head1 AUTHOR

=over

=item *

Kiran Kumar, C<< <kiran at brainturk.com> >>

=item *

JT Smith, C<< <jt at plainblack.com> >>

=back



=head1 SUPPORT

=over

=item Source Code Repository

L<https://github.com/rizen/Firebase>

=item Issue Tracker

L<https://github.com/rizen/Firebase/issues>

=back




=head1 LICENSE AND COPYRIGHT

Copyright 2013  Kiran Kumar.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of WWW::Firebase
