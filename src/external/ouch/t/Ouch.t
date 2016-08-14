use Test::More tests => 27;
use Test::Trap;
use lib '../lib';

use_ok 'Ouch';

eval { ouch(100, 'Test', 'field_name') };
isa_ok $@, 'Ouch';

is $@->code, 100, 'fetch code';
is kiss(100), 1, 'trap an ouch';
is kiss(101), 0, 'do not trap wrong ouch';
is hug(), 1, 'hug catches ouch';
is $@->message, 'Test', 'fetch message';
is $@->data, 'field_name', 'fetch data';
like $@, qr/^Test at/, 'string overload works';
isa_ok $@->hashref, 'HASH';
ok $@->trace, 'got a stack trace';
is bleep(), 'Test', 'can get a clean message for an ouch';

# what if it's not an ouch;
eval { die 'crap' };
is kiss(100), 0, 'do not trap non-ouch';
is bleep(), 'crap', 'can get the message for a non-ouch';
is hug(), 1, 'hug catches non-ouch';

# work out the traditional stuff
use Ouch qw(:traditional);

my $e = try {
  throw 100, 'Yikes';
};
isa_ok $e, 'Ouch';
is catch(100, $e), 1, 'catch works';
is catch(101, $e), 0, 'catch works when not trapped';
is catch_all($e), 1, 'catch_all does the same as hug';

# what if there is no exception

eval { my $x = 1 };
is hug(), 0, 'hug does not catch lack of exception';
is catch_all($e), 0, 'catch_all does the same as hug';

# what if the exception code is a string
eval { ouch('missing_param', 'Email'); };
is kiss('missing_param'), 1, 'kiss works on strings';
is kiss('foo'), 0, 'kiss gives no false positives';

# barf
trap {eval { ouch(100, 'oops') } or barf() };
is $trap->exit, 100, 'exit code';
is $trap->stderr, "oops\n", 'stderr err message';

# more barf
trap { eval { die 'error' } or barf() };
is $trap->exit, 1, 'default barf exit code';
is $trap->stderr, "error\n", 'stderr err message w/o ouch';
