#!/usr/bin/perl

use strict;
use warnings;

my $wordlist = 'chinese';
my $grammar = 'grammar';
my $chinese_reg = 'chinese.reg';
my $grammar_reg = 'grammar.reg';

my %dups = ();

foreach my $file ($wordlist, $grammar, $chinese_reg, $grammar_reg) {
    open FILE, "<$file";
    while (<FILE>) {
        chomp;
        if (/\|/) {
            my ($simplified, $traditional, $pinyin, $english, $section) = split /\|/;
            $section ||= '';
            push @{ $dups{"$simplified|$file"} }, "$file:$.:$simplified|$traditional|$pinyin|$english|$section";
        } else {
            my ($simplified, $plus_and_minuses) = /^([^-\+]*)([-\+]+)$/;
            push @{ $dups{"$simplified|$file"} }, "$plus_and_minuses $file:$.";
        }
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
            my $key_mod = $key;
            $key_mod =~ s/\|.*//;
            print "$key_mod|$el\n";
        }
    }
}

$f = 0;
foreach my $key (keys %dups) {
    foreach my $el (@{ $dups{$key} }) {
        next if $key =~ /chinese.reg/;
        next if $key =~ /grammar.reg/;
        my ($stuff, $section) = ($el =~ /^(.*:.*:.*\|.*\|.*\|.*)\|(.*)$/);
        if (!$section) {
            if (!$f) {
                print "MISSING SECTIONS FOUND:\n";
                ++$f;
            }
            print "$el\n";
        }
    }
}

exit;
