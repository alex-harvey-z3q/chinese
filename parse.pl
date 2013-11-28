#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use open ':encoding(utf8)';
binmode(STDOUT, ':utf8');

my ($chars, $pinyin, $english);
my @char_defs;
my $found_strokes = 0;
my $found_pinyin = 0;

while (<DATA>) {
    if ($. == 1) {
        chomp;
        $chars = $_;
        next;
    }
    if ($. == 2) {
        chomp;
        $pinyin = $_;
        $pinyin =~ s/\x{200b}//g;
        next;
    }
    if ($. > 2 and !defined($english)) {
        next if /^	/;
        chomp;
        $english = $_;
        $english =~ s# /#,#g;
        $english =~ s/CL: (.), (.), (.)/CL:$1\\$2\\$3/g;
        $english =~ s/CL: (.), (.)/CL:$1\\$2/g;
        next;
    }
    if (defined($english)) {
        if (/\+/) {
            $found_strokes = 1;
            next;
        }
        if (/[áāǎàèéēěíīìǐòōóǒūùǔúǚǜǘ]/) {
            $found_pinyin = 1;
            next;
        }
        if ($found_strokes and $found_pinyin and !/^	/) {
            chomp;
            s/ *$//;
            push @char_defs, $_;
            $found_strokes = 0;
            $found_pinyin = 0;
            next;
        }
    }
}

if ($#char_defs > 0) {
    print "$chars|$pinyin|$english (" . join(' / ', @char_defs) . ")\n";
} else {
    print "$chars|$pinyin|$english\n";
}

__DATA__
座
zuò​
	
	
seat / base / stand / CL: 個｜个 / classifier for buildings, mountains and similar immovable objects 
