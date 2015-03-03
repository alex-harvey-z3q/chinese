#!/usr/bin/perl

use strict;
use warnings;

my $wordlist = 'chinese';
my $grammar = 'grammar';

my %seen = ();

foreach my $file ($wordlist, $grammar) {
    open FILE, "<$file";
    my $last_seen = '';
    while (<FILE>) {
        chomp;
        if (/\|/) {
            my ($simplified, $traditional, $pinyin, $english, $section) = split /\|/;
            if (!exists $seen{$section}) {
                $seen{$section} = $.;
            } else {
                if ($last_seen ne $section) {
                    print "WARN: section $section begins at $seen{$section} and $.\n";
		}
            }
	    $last_seen = $section;
        } else {
            print "WARN: line $. has no | character\n";
        }
    }
    close FILE;
}

exit;
