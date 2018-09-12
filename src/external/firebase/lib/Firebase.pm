package Firebase;

use Moo;
use Firebase::Auth;
use HTTP::Thin;
use HTTP::Request::Common qw(DELETE PUT GET POST);
use Ouch;
use JSON;
use URI;
use Data::Dumper;



has firebase => (
    is          => 'ro',
    required    => 1,
);

has auth => (
    is          => 'ro',
    predicate   => 'has_auth',
);

has jwt => (
    is          => 'ro',
    predicate   => 'has_jwt',
);

has api_key => (
    is          => 'ro',
    predicate   => 'has_api_key',
);

has authobj        => (
    is          => 'rw',
    lazy        => 1,
    predicate   => 'has_authobj',
    default     => sub {
        my ($self) = @_;
        Firebase::Auth->new(firebase => $self->firebase, secret => $self->jwt, api_key => $self->api_key);
    },
);

has debug => (
    is          => 'rw',
    default     => sub { '' },
);

has agent => (
    is          => 'ro',
    required    => 0,
    lazy        => 1,
    default     => sub { HTTP::Thin->new() },
);

sub get {
    my ($self, $path, $param_hash) = @_;
    my $uri = $self->create_uri($path);

	my $req  = $uri->as_string;

	if(defined($param_hash)){
		while(my ($key, $value) = each (%$param_hash)){
			$req .= "\&".$key."=$value";
		}
	}
	#print "$req\n";
	my $request = GET($req);
	return $self->process_request($request);
}

sub delete {
    my ($self, $path) = @_;
    my $uri = $self->create_uri($path);
    return $self->process_request( DELETE $uri );
}

sub put {
    my ($self, $path, $params) = @_;

	#print $path . "\n";

    my $uri = $self->create_uri($path);
	#print $uri . "\n";
    my $request = POST($uri->as_string, Content_Type => 'form-data', Content => to_json($params));


    $request->method('PUT'); # because HTTP::Request::Common treats PUT as GET rather than POST
    return $self->process_request( $request );
}

sub patch {
    my ($self, $path, $params) = @_;

    my $uri = $self->create_uri($path);
    my $request = POST($uri->as_string, Content_Type => 'form-data', Content => to_json($params));
    $request->method('PATCH'); # because HTTP::Request::Common treats PUT as GET rather than POST
    return $self->process_request( $request );
}

sub post {
    my ($self, $path, $params) = @_;
    my $uri = $self->create_uri($path);
    my $request = POST($uri->as_string, Content_Type => 'form-data', Content => to_json($params));
    return $self->process_request( $request );
}

sub create_uri {
  my ($self, $path,$param) = @_;

    my $token=$self->authobj->get_token;
    print $token ."\n";
    die;
  my $url = 'https://'.$self->firebase.'.firebaseio.com/'.$path.'.json';
    $url .= '?auth='.$token;
	my $uri = URI->new($url);
    return $uri;
}

sub process_request {
    my $self = shift;
    $self->process_response($self->agent->request( @_ ));
}

sub process_response {
    my ($self, $response) = @_;

	$self->debug($response->header('X-Firebase-Auth-Debug'));

	if ($response->is_success) {
        if ($response->decoded_content eq 'null') {
            return undef;
        }
        else {
            my $result = eval { from_json($response->decoded_content) };
            if ($@) {
 				warn $response->decoded_content;
                ouch 500, 'Server returned unparsable content.';#, { error => $@, content => $response->decoded_content };
            }
            return $result;
        }
    }
    else {
		print Dumper($response);
        ouch 500, $response->status_line, $response->decoded_content;
    }
}

=head1 NAME

Firebase - An interface to firebase.com.

=head1 SYNOPSIS

 use Firebase;

 my $fb = Firebase->new(firebase => 'myfirebase', auth => { secret => 'xxxxxxx', data => { uid => 'xxx', username => 'fred' }, admin => \1 } );

 my $result = $fb->put('foo', { this => 'that' });
 my $result = $fb->get('foo'); # or $fb->get('foo/this');
 my $result = $fb->delete('foo');

=head1 DESCRIPTION

This is a light-weight wrapper around the Firebase REST API. Firebase is a real-time web service that acts as both a queue and a datastore. It's used for building real-time web apps and web services.

More info at L<https://www.firebase.com/docs/rest-api-quickstart.html>.

=head1 METHODS


=head2 new

Constructor

=over

=item firebase

Required. The name of your firebase.

=item auth

The parameters you'd pass to create a C<Firebase::Auth> object. This is a shortcut for constructing the object yourself and passing it into C<authobj>.

=item authobj

A L<Firebase::Auth> object. Will be generated for you automatically if you don't supply one, but do supply C<auth>.

=item agent

A user agent. An L<HTTP::Thin> object will be generated for you automatically if you don't supply one.

=back


=head2 get

Fetch some data from firebase.

=over

=item path

The path to the info you want to fetch.

=back


=head2 put

Put some data into a firebase.

=over

=item path

The path where the info should be stored.

=item params

A hash reference of parameters to be stored at this location.

B<Warning:> Firebase doesn't work with arrays, so you can nest scalars and hashes here, but not arrays.

=back

=head2 patch

Partial update of data in a location

=over

=item path

The path where the info should be stored.

=item params

A hash reference of parameters to be updated at this location.

=back


=head2 post

Adds data to an existing location, creating a hash of objects below the path.

=over

=item path

The path where the info should be stored.

=item params

A hash reference of parameters to be stored at this location.

B<Warning:> Firebase doesn't work with arrays, so you can nest scalars and hashes here, but not arrays.

=back


=head2 delete

Delete some data from a firebase.

=over

=item path

The path where the info is that you want deleted.

=back



=head2 debug

If C<debug> has been set to a true value in C<Firebase::Auth>, this will return the debug message returned with the previous response.




=head2 create_uri

Creates a URI to a firebase data segment. You almost certainly want to use C<get>, C<put> or C<delete> instead.

=over

=item path

The path to the data.

=item params

Any parameters you need to pass for any reason.

=back


=head2 process_request

Requests data and runs it through C<process_response>. You almost certainly want to use C<get>, C<put> or C<delete> instead.

=over

=item request

An L<HTTP::Request> object.

=back

=head2 process_response

Checks for errors, decodes json, and returns a result. You almost certainly want to use C<get>, C<put> or C<delete> instead.

=over

=item response

An L<HTTP::Response> object.

=back


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

Copyright 2013  Plain Black Corporation

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

1;
