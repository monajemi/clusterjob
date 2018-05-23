#!/usr/bin/perl 
#

use lib '../external/firebase/lib';  
use lib '../external/ouch/lib'; 
use Firebase; 
use Test::More;
use Ouch;

my $tk = '4lp5BkZFh0bEpbpoPQGChJcGCeRfq8gLDxP65E7S';
my $fb = Firebase->new(firebase => 'clusterjob-78552', auth => {secret=>$tk, data => {uid => 'hatef'}, admin => \1} );

#print $fb->firebase . "\n";

my $result = $fb->put('hatef/ea923d43', { username => 'hatef', pid => 'ea923d43' });
my $result = $fb->put('hatef/ba92fg33', { username => 'hatef', pid => 'ba92fg33' });

my $result = $fb->get('foo');
my $result = $fb->delete('foo');


 
