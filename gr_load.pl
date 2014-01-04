#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use open ':encoding(utf8)';

use Data::Dumper;

binmode(STDOUT, ':utf8');
binmode(STDIN, ':utf8');

my ($simplified, $traditional, $pinyin, $english);

my $wordlist = 'grammar';
my $lastsect = '.last_section_grammar';

my $section = get_section($lastsect);

for (;;) {

    my ($trad_c, $piny_c);

    print 'Enter simplified Chinese: ';
    my $simplified = <STDIN>;
    chomp $simplified;

    my @chars = split //, $simplified;

    my @trad = ();
    my @piny_c = ();
    for (my $c=0; $c <= $#chars; ++$c) {
        if ($chars[$c] eq '？') {
            push @trad, '？';
            push @piny_c, '?';
            next;
        } elsif ($chars[$c] eq '，') {
            push @trad, '，';
            push @piny_c, ',';
            next;
        } elsif ($chars[$c] eq ' ') {
            push @trad, ' ';
            push @piny_c, ' ';
            next;
        }
        my $j=0;
        if ($c+3 <= $#chars) { 
            ($trad_c, $piny_c) = get_trad_and_pinyin([$chars[$c], $chars[$c+1], $chars[$c+2], $chars[$c+3]]);
            $j=3 if $piny_c;
        }
        if (!$j and $c+2 <= $#chars) { 
            ($trad_c, $piny_c) = get_trad_and_pinyin([$chars[$c], $chars[$c+1], $chars[$c+2]]);
            $j=2 if $piny_c;
        }
        if (!$j and $c+1 <= $#chars) { 
            ($trad_c, $piny_c) = get_trad_and_pinyin([$chars[$c], $chars[$c+1]]);
            $j=1 if $piny_c;
        }
        ($trad_c, $piny_c) = get_trad_and_pinyin([$chars[$c]]) if !$j;
        $trad_c = join('', @chars[$c..($c+$j)]) if !$trad_c;
        print "error loading at '$chars[$c]'!\n" and die if !$piny_c;
        push @trad, $trad_c;
        push @piny_c, $piny_c;
        $c += $j; 
    }

    my $traditional = join('', @trad);
    $traditional = ($traditional eq $simplified) ? '' : $traditional;

    my $pinyin = join(' ', @piny_c);
    $pinyin =~ s/ \?/?/g;
    $pinyin =~ s/ ,/,/g;

    print 'Enter English translation: ';
    my $english = <STDIN>;
    chomp $english;

    insert_line("$simplified|$traditional|$pinyin|$english", $section);
    print "\n";
}

# subroutines.

sub get_section {
    my $lastsect = shift;

    # get the default section from $lastsect.
    open FILE, "<$lastsect";
    my $default_section = <FILE>;
    chomp $default_section;
    close FILE;

    # ask the user for desired section.
    print "Section? (Type 'list' to list sections.) [$default_section] ";

    my $section;
    while ($section = <STDIN>) {
        chomp($section);
        if ($section eq 'list') {
            list_sections();
            print "\n";
            print "Section? [$default_section] ";
        } elsif ($section) {
            open FILE, ">$lastsect";
            print FILE $section;
            close FILE;
            last;
        } else {
            $section = $default_section;
            last;
        }
    }

    # check that the section exists.
    if (no_such_section($section)) {
        print "No such section '$section'\n";
        exit;
    } else {
        print "Adding to section '$section'\n";
    }

    return $section;
}

sub get_trad_and_pinyin {
    my $chars = shift;
    return (undef, undef) if grep {$_ eq '？'} @{ $chars };
    return (undef, undef) if grep {$_ eq '，'} @{ $chars };
    my ($traditional, $pinyin);
    my $chinese = 'chinese';
    my $simplified = join('', @{ $chars });
    open FILE, "<$chinese";
    while (<FILE>) {
        my ($s, $t, $p, $e, $sect) = split /\|/;
        if ($s eq $simplified) {
            $traditional = $t;
            $pinyin = $p;
            last;
        }
    }
    close FILE;
    return ($traditional, $pinyin);
}

sub insert_line {
    my ($line, $section) = @_;
    my $flag = 0;
    my $printed = 0;
    open FILE, "<:encoding(utf8)", $wordlist;
    open TMP, ">:encoding(utf8)", "$wordlist.tmp";
    while (<FILE>) {
        chomp;
        my ($a, $b, $c, $d, $s) = split /\|/;
        if ($s eq $section) {
            $flag = 1;
        }
        if ($flag and $s eq $section) {
            print TMP "$_\n";
        } elsif ($flag and $s ne $section) {
            print TMP "$line|$section\n";
            print TMP "$_\n";
            $flag = 0;
            $printed = 1;
        } else {
            print TMP "$_\n";
        }
    }
    if (!$printed) {
        print TMP "$line|$section\n";
    }
    close TMP;
    close FILE;
    system("mv $wordlist.tmp $wordlist");
}

sub list_sections {
    my @sections = ();
    open FILE, "<$wordlist";
    while (<FILE>) {
        chomp;
        my ($a, $b, $c, $d, $s) = split /\|/;
        push @sections, $s unless grep { $_ eq $s } @sections;
    }
    print "$_\n" foreach (sort {lc $a cmp lc $b} @sections);
}

sub no_such_section {
    my $section = shift;
    my @sections;
    open FILE, "<$wordlist";
    while (<FILE>) {
        chomp;
        my ($a, $b, $c, $d, $s) = split /\|/;
        push @sections, $s unless grep { $_ eq $s } @sections;
    }
    close FILE;
    return !grep { $_ eq $section } @sections;
}

# end of script
