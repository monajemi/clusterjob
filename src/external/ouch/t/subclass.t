use Test::More tests => 2;
use Test::Trap;
use lib '../lib';

use_ok 'Ouch';

{
  package Subclass::Ouch;
  use parent 'Ouch';
}

eval { die Subclass::Ouch->new(42, 'welp') };
is kiss(42), 1, 'still catches subclasses';

