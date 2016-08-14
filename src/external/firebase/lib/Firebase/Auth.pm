package Firebase::Auth;

use strict;
use warnings;
use Digest::SHA qw(hmac_sha256);
use JSON::XS;
use POSIX;
use MIME::Base64;
use Moo;
use Ouch;


has token_version => (
    is      => 'rw',
    default => sub { 0 },
);

has secret => (
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

sub create_token {
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
    $claims{exp} = $self->expires if $self->has_expires;
    $claims{nbf} = $self->not_before if $self->has_not_before;
    $claims{debug} = $self->debug if $self->has_debug;
    return \%claims;
}

sub encode_token {
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
