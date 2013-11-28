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
        $english =~ s/CL: /CL:/g;
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

print "$chars|$pinyin|$english (" . join(' / ', @char_defs) . ")\n";

__DATA__
咖啡馆
kā​fēi​guǎn​
	
	
café / coffee shop / CL: 家
	
咖啡館
Character		Tot Str
Rad / Str	Mandarin
Pīnyīn	Unihan Definition
standalone and in compounds
	Jyutping
Cantonese	Variant
Four corner
Cangjie
咖
	
	
8画
口 + 5
	
kā, gā
	
coffee; a phonetic
	
gaa1, gaa3, kaa1
	
6600.0
RKSR
啡
	
	
11画
口 + 8
	
fēi, pēi
	
morphine; coffee
	
fe1, fei1
	
6101.1
RLMY
馆
	
	
11画
饣 + 8
	
guǎn
	
public building 
