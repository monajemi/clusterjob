#!perl
use 5.006;
use strict;
use lib '../lib';
use lib '../../ouch/lib'; 

use warnings FATAL => 'all';
use Test::More;
use JSON::XS;
use MIME::Base64;

BEGIN {
    use_ok( 'Firebase::Auth' ) || print "Bail out!\n";
}

my $tk = 'aca98axPOec';

my $firebase= Firebase::Auth->new ( secret =>$tk, admin => 'true', data => { uid => 1 } );

isa_ok($firebase, 'Firebase::Auth');

is ($firebase->secret , $tk, 'secret token added');


my $custom_data = {'auth_data', 'foo', 'other_auth_data', 'bar', uid => 2 };

my $token = $firebase->create_token ( $custom_data );
diag $token;

my @fragments = split(/\./, $token);

is scalar(@fragments), 3, 'encoded the data properly';

is decode_json(decode_base64($fragments[1]))->{admin}, 'true', 'claims encoded properly';

my $fba = Firebase::Auth->new ( secret =>$tk, admin => 'true' );

ok $fba->create_token, "don't need a uid if you're an admin";



done_testing();
