#!/usr/bin/perl

use strict;
use warnings;

my $wordlist = 'chinese';
my $grammar = 'grammar';

my %dups = ();

foreach my $file ($wordlist, $grammar) {
    open FILE, "<$file";
    while (<FILE>) {
        chomp;
        my ($simplified, $traditional, $pinyin, $english, $section) = split /\|/;
        $section ||= '';
        push @{ $dups{"$simplified|$traditional|$pinyin"} }, "$.|$file|$section";
    }
    close FILE;
}

my $f = 0;
foreach my $key (keys %dups) {
    if ($#{ $dups{$key} } > 0) {
        if (!$f) {
            print "DUPLICATES FOUND:\n";
            ++$f;
        }
        foreach my $el (@{ $dups{$key} }) {
            my ($simplified, $traditional, $pinyin) = split /\|/, $key;
            my ($line, $section) = split /\|/, $el;
            print "$line:$simplified|$traditional|$pinyin|$section\n";
        }
    }
}

$f = 0;
foreach my $key (keys %dups) {
    foreach my $el (@{ $dups{$key} }) {
        my ($simplified, $traditional, $pinyin) = split /\|/, $key;
        my ($line, $file, $section) = split /\|/, $el;
        if (!$section) {
            if (!$f) {
                print "MISSING SECTIONS FOUND:\n";
                ++$f;
            }
            print "$line:$simplified|$traditional|$pinyin\n";
        }
    }
}

exit;
