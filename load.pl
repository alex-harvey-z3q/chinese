#!/usr/bin/perl

use strict;
use warnings;

use utf8;

binmode(STDOUT, ':utf8');
binmode(STDIN, ':utf8');

my ($simplified, $traditional, $pinyin, $english);
my @char_defs;
my $found_traditional = 0;
my $found_strokes = 0;
my $found_pinyin = 0;

my $wordlist = 'chinese';
my $lastsect = 'last_section';

my $section = get_section($lastsect);

for (;;) {

    print "Copy and paste a word here:\n";

    for (my $i=1; defined($_ = <STDIN>); ++$i) {
        if ($i == 1) {
            chomp;
            $simplified = $_;
            next;
        }
        if ($i == 2) {
            chomp;
            $pinyin = $_;
            $pinyin =~ s/\x{200b}//g;
            next;
        }
        if ($i > 2 and !defined($english)) {
            next if /^	/;
            chomp;
            $english = $_;
            $english =~ s# /#,#g;
            $english =~ s/CL: (.), (.), (.)/CL:$1\\$2\\$3/g;
            $english =~ s/CL: (.), (.)/CL:$1\\$2/g;
            $english =~ s/CL: .｜(.), .｜(.), .｜(.)/CL:$1\\$2\\$3/g;
            $english =~ s/CL: .｜(.), .｜(.)/CL:$1\\$2/g;
            $english =~ s/CL: .｜(.)/CL:$1/g;
            $english =~ s/CL: (.), .｜(.)/CL:$1\\$2/g;
            $english =~ s/CL: /CL:/g;
            next;
        }
        if (defined($english) and !$found_traditional) {
            next if /^	/;
            chomp;
            $traditional = $_;
            $found_traditional = 1;
        } 
        if (defined($english) and $found_traditional) {
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
    
    my $line;
    if ($#char_defs > 0) {
        $line = "$simplified|$traditional|$pinyin|$english (" . join(' / ', @char_defs) . ')';
    } else {
        $line = "$simplified|$traditional|$pinyin|$english";
    }

    insert_line($line, $section);

    undef $english;
    @char_defs = ();
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
