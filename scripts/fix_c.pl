#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use open ':encoding(utf8)';
binmode(STDOUT, ':utf8');

open FILE, "<chinese";
while (<FILE>) {
    chomp;
    my ($simplified, $pinyin, $english, $section) = split /\|/;
    my $traditional = `awk -F' ' '\$2 == \"$simplified\" {print \$1}' cedict_ts.u8 |head -1`;
    chomp $traditional;
    if ($simplified eq $traditional) {
        print "$simplified||$pinyin|$english|$section\n";
    } else {
        print "$simplified|$traditional|$pinyin|$english|$section\n";
    }
}
close FILE;
