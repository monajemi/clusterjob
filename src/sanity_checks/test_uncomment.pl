#!/usr/bin/perl 
# 

print "Enter python line to be uncommented:\n";
my $line = <STDIN>; chomp $line;
#my $line = " x = \'%3.2f%i\' %%Hatef ";

$line = uncomment_python_line($line);
print "AFTER : $line\n";

sub uncomment_python_line{
    my ($line) = @_;
    
    print "BEFORE: $line\n";

    $line =~ s/^(?:(?![\"|\']).)*\K\#(.*)//;
    


    return $line;
}
