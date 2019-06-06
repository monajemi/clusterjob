use File::Monitor;
use Data::Dumper;

my $monitor = File::Monitor->new();
 
# Watch the results directory
$monitor->watch( {
    name        => 'somedir',
    recurse     => 1,
    callback    => {
        files_created => sub {
            my ($name, $event, $change) = @_;
            # Run the upload script
            print(Dumper($name));
        }
    }
} );

while(True){
    for my $change ($monitor->scan){
        print(Dumper($change))
    }
}

