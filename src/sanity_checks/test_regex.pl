#!/usr/bin/perl 
# 
print "Enter what needs to be matched:\n";
my $name = <STDIN>;chomp $name;
print "Enter the regexp:\n";
my $regexp = <STDIN> ; chomp $regexp;

if($name =~ /$regexp/){
  print "$name  matches  $regexp\n";
}else{
  print "$name does not match $regexp\n";
}
