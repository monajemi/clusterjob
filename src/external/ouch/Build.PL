use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
	'module_name' => 'Ouch',
	'license' => 'perl',
	'dist_author' => 'JT Smith',
	'build_requires' => {
		'Test::More' => 0
	},
	'create_makefile_pl' => 'traditional'
);

$builder->create_build_script();