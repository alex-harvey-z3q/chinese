#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

my $input = 'chinese.log';
my $start = shift;
$start ||= 6617;

my %result = ();

#$result = (
#    '英俊 yīngjùn --> handsome' => 3,
#...
#);

open FIL, "<$input";
while (my $l = <FIL>) {
    next if $. < $start;
    chomp $l;
    next unless $l =~ /^  /;
    $l =~ s/^  //;
    if (grep { $_ eq $l } keys %result) {
        ++$result{"$l"};
    } else {
        $result{"$l"} = 1;
    }
}
close FIL;

foreach my $i (sort { $result{$a} <=> $result{$b} } keys %result) {
    print $result{$i}, ":$i\n";
}

# end of script
