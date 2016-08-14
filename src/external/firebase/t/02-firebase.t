use lib '../lib';
use lib '../../ouch/lib'; 

use Firebase;
use Test::More;
use Ouch;

my $firebase_server = 'perlfirebase'; # $ENV{FIREBASE};
my $firebase_token = 'UZkyzoI8Vukeus941PCEAZB6PmoZfVfXAqfHGoZr'; #$ENV{FIREBASE_TOKEN};

my $firebase = Firebase->new(auth => { secret => $firebase_token, admin => \1, data => { uid => 'hatef' } }, firebase => $firebase_server);

isa_ok($firebase, 'Firebase');

is $firebase->firebase, $firebase_server, 'set the firebase';
isa_ok $firebase->authobj, 'Firebase::Auth';
is $firebase->authobj->secret, $firebase_token, 'set the secret token';

my $result = $firebase->put('test', { foo => 'bar' });
is $result->{foo}, 'bar', 'created object';

$result = $firebase->get('test');
is $result->{foo}, 'bar', 'authenticate read object';

$result = Firebase->new(firebase => $firebase_server)->get('test');
is $result->{foo}, 'bar', 'anonymous read object';

$result = $firebase->delete('test');
is $result, undef, 'delete object';


my $firebase2 = Firebase->new(auth => { secret => $firebase_token, debug => \1, data => { uid => 'abc' } }, firebase => $firebase_server);
my $data = $firebase2->put('status/abc/xxx', { type => 'info', message => 'this is a test' });
is $data->{type}, 'info', 'can write to authorized location';
$data = $firebase2->put('status/abc/yyy', { type => 'info2', message => 'brother test' });
is $data->{type}, 'info2', 'Wrote additional data';

eval { $firebase2->delete('status/abc/yyy'); };
ok !hug(), 'No exception thrown for deleting something';

$data = $firebase2->get('status/abc/yyy');
is $data, undef, 'Nothing at the location we just deleted';

$data = $firebase2->post('status/abc', { fire => 'base', base => 'fire', });
ok exists $data->{name}, "PUSHed to status with name: ". $data->{name};

$data = $firebase2->patch('status/abc/'. $data->{name}, { base => 'jumping', jumping => 'jack flash', });
is $data->{base}, 'jumping', 'data overwritten via PATCH';
is $data->{jumping}, 'jack flash', 'data added via PATCH';

$firebase2->delete('status/abc');

eval { $firebase2->put('somewhere', { foo => 'bar' }); };

is $@->message, '401 Unauthorized', 'Cannot just write willy nilly.';

ok $firebase2->debug =~ m/^Attempt to write/, 'Debug message returned.';

done_testing();

1;
