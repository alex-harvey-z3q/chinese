#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use open ':encoding(utf8)';
binmode(STDOUT, ":utf8");

use Time::HiRes qw(gettimeofday);
use Getopt::Long qw(:config no_ignore_case);

my $logfile = 'chinese.log';
my $wordlist = 'chinese';
my $register = 'chinese.reg';
my $character_register = 'chinese_char.reg';
my $classifier_register = 'chinese_class.reg';
my $threshold = 5;
my $skip = 20;

my $got_to_main = 0;
my $attempted = 0;
my $presented = 0;
my $correct = 0;
my $average_correct = 0;
my $average_time = 0;
my @incorrect = ();
my @stack = ();
my $no_repeats = 1;

$SIG{INT} = \&on_exit;

# count lines.
my $lines = 0;
open FILE, "<$wordlist";
$lines++ while (<FILE>);
close FILE;

# input options.
my $start_at = 0;
my $finish_at = $lines;
my ($help, $choose_section, $section,
    $list_mode, $list_dups_mode, $character_mode,
    $honesty_mode, $chinese_mode, $english_mode,
    $classifier_mode, $fixreg_mode,
    $list_words_mode);
GetOptions(
    'help|h' => \$help,
    'start|t=s'  => \$start_at,
    'finish|f=s' => \$finish_at,
    'choose-section|H' => \$choose_section,
    'section|s=s' => \$section,
    'list|L' => \$list_mode,
    'list-words|l' => \$list_words_mode,
    'list-dups|d' => \$list_dups_mode,
    'character|C' => \$character_mode,
    'honesty|O' => \$honesty_mode,
    'chinese|c' => \$chinese_mode,
    'english|e' => \$english_mode,
    'classifier|i' =>\$classifier_mode,
    'fixreg|F' =>\$fixreg_mode,
    'threshold|T=s' => \$threshold,
    'skip|K=s' => \$skip,
);

sub usage {
    print <<EOF;
Usage: $0 {-h|-l|-d}
    --help|-h      - show this help
    --list|-L      - list sections
    --list-dups|-d - list duplicates
    --fixreg|-F    - fix the register

Usage: $0 [-t <start_line> -f <finish_line> | -s <section> | -H ] [-lOcCeiT]
    --start|-t / --finish|-f - start/finish lines
    --section|-s <section> - specify the section number
    --choose-section|-H - choose section from a menu
    --list-words|-l - list words mode
    --honesty|-O    - honesty mode
    --chinese|-c    - chinese mode
    --character|-C  - chinese character mode
    --english|-e    - english mode
    --classifier|-i - classifier mode
    --threshold|-T <threshold> - set number correct threshold
      -T 100   - only consider skipping if this word is right 100 times in a row
      -T 1     - consider skipping if this word was right last time
    --skip|-K <skip>           - set skip threshold
      -K 100   - never skip a word
      -K 0     - always skip, if threshold is met
EOF
    exit;
}

# process help.
$help and usage();

# process $list_dups_mode.
$list_dups_mode and process_dups();

# process $fixreg_mode.
$fixreg_mode and fix_register([$register, $character_register, $classifier_register]);

# in character mode use a different register.
$character_mode and $register = $character_register;

# process $list_mode.
if ($list_mode) {
    system "cut -f4 -d'|' $wordlist |sort -u";
    exit;
}

# process $choose_section.
my $section_length = $lines;
if ($list_words_mode or $choose_section or $section) {
    ($section, $section_length, $start_at, $finish_at)
        = process_section($lines, $section);
}

# list words mode.
$list_words_mode and list_words($start_at, $finish_at, $register);

# seed the randomiser.
srand;

# classifier flag.
my $classifier = '';

# main loop.
for (;;) {

    # set got to main for use in on_exit.
    $got_to_main = 1;

    # finished if $#stack = section length.
    last if ($#stack == $section_length);

    # get a random line
    my ($random, $line) = get_line($start_at, $finish_at);

    # get another one if it's already on the stack.
    next if (grep {$_ == $random} @stack) and $no_repeats;

    # if we get here, this word gets presented.
    ++$presented;

    # question message.
    my $mes = "[$presented of " . ($section_length+1) . ']';

    # push this number onto the stack.
    push @stack, $random;

    # get the chinese word
    my ($chars, $pinyin, $english, $sect) = split /\|/, $line;

    # hid_cl used to hide the classifier in classifer_mode.
    my $hid_cl = $english;

    # formatted string used in log and register.
    my $log_text = "$chars $pinyin --> $english";

    # string of history on this word.
    my $hist_str = '[' . get_hist($log_text, $register) . ']';

    # get another number if we got this word right $threshold times.
    next if check_register($log_text, $register);

    # in classifer mode figure out the classifier where applicable.
    my ($cl_char, $cl_pinyin, $rest) = $classifier_mode ? get_classifier($english, $hid_cl) : (undef, undef, undef);
    
    # start timer.
    my ($ssec, $smil) = gettimeofday();

    # now, either print a Chinese or an English word.
    my ($response, $resp_piny, $resp_engl);
    my $coin_toss = int(rand(2));
    if ($character_mode) {
        print "$chars $hist_str $mes\n";
        print 'ANSWER> ';
        $response = <STDIN>;
        ($resp_piny, $resp_engl) = break_up_response($response, $pinyin);
        print "$pinyin $hid_cl";
    } elsif ($chinese_mode or (!$english_mode and $coin_toss)) {
        print "$chars $pinyin $hist_str $mes\n";
        print 'ANSWER> ';
        $response = <STDIN>;
        print "$hid_cl";
    } elsif ($english_mode or (!$chinese_mode and !$coin_toss)) {
        print "$hid_cl $hist_str $mes\n";
        print 'ANSWER> ';
        $response = <STDIN>;
        print "$chars $pinyin";
    }

    # also add section unless we're in section mode.
    if (defined $section) {
        print "\n";
    } else {
        print " [$sect]\n";
    }
        
    # stop timer and compute elapsed time.
    my ($fsec, $fmil) = gettimeofday();
    my $elapsed = elapsed($ssec, $smil, $fsec, $fmil);

    # figure out if the answer was correct.
    my $am_correct;
    if ($honesty_mode) {
        print "correct? (y/n) ";
        my $input = <STDIN>;
        $am_correct = 1 if $input =~ /^y/i;
    } elsif ($character_mode) {
        $am_correct =
            pinyin_compare($resp_piny, $pinyin) &&
            pinyin_compare($resp_engl, $english);
    } elsif ($chinese_mode or (!$english_mode and $coin_toss)) {
        $am_correct = pinyin_compare($response, $english);
    } elsif ($english_mode or (!$chinese_mode and !$coin_toss)) {
        $am_correct = pinyin_compare($response, $pinyin);
    }

    # if correct, so far, also check the classifier in classifier mode.
    if ($classifier and $am_correct) {
        print 'CLASSIFIER> ';
        my $cl_response = <STDIN>;
        $cl_response ||= '';
        print "$cl_char $cl_pinyin\n";
        if (pinyin_compare($cl_response, $cl_pinyin)) {
            update_register($log_text, '+', $classifier_register);
        } else {
            update_register($log_text, '-', $classifier_register);
        }
    }
 
    # update the register.
    if ($am_correct) {  
        ++$correct;
        update_register($log_text, '+', $register);
    } else {
        push @incorrect, $log_text;
        update_register($log_text, '-', $register);
    }

    # update counters.
    ++$attempted;
    $average_correct = ($correct / $attempted) * 100;
    $average_time = ((($average_time * ($attempted - 1)) + $elapsed) / $attempted);

    $classifier = '';
    print "\n";
}

on_exit();

sub get_line {
    my ($start_at, $finish_at) = @_;

    # get a random line.
    my $random;
    for (;;) {
        $random = int(rand($lines)) + 1;
        last if ($random >= $start_at
             and $random <= $finish_at);
    }

    # get that line
    my $line;
    open FILE, "<$wordlist";
    while (<FILE>) {
        if ($. >= $random) {
            chomp;
            $line = $_;
            last;
        }
    }
    close FILE;
    return ($random, $line);
}

sub process_dups {
    my %dups = ();
    open FILE, "<$wordlist";
    while (<FILE>) {
        chomp;
        my ($char, $pinyin, $english, $section) = split /\|/;
        $section ||= '';
        push @{ $dups{"$char|$pinyin"} }, "$.|$section";
    }
    close FILE;
    my $f = 0;
    foreach my $key (keys %dups) {
        if ($#{ $dups{$key} } > 0) {
            if (!$f) {
                print "DUPLICATES FOUND:\n";
                ++$f;
            }
            foreach my $el (@{ $dups{$key} }) {
                my ($char, $pinyin) = split /\|/, $key;
                my ($line, $section) = split /\|/, $el;
                print "$line:$char|$pinyin|$section\n";
            }
        }
    }
    $f = 0;
    foreach my $key (keys %dups) {
        foreach my $el (@{ $dups{$key} }) {
            my ($char, $pinyin) = split /\|/, $key;
            my ($line, $section) = split /\|/, $el;
            if (!$section) {
                if (!$f) {
                    print "MISSING SECTIONS FOUND:\n";
                    ++$f;
                }
                print "$line:$char|$pinyin\n";
            }
        }
    }
    exit;
}

sub process_section {
    my ($lines, $section_number) = @_;
    $section_number ||= '';
    my $section_length = $lines;

    # choose section.
    my @sections;
    open FILE, "<$wordlist";
    while (<FILE>) {
        chomp;
        my ($a, $b, $c, $s) = split /\|/;
        push @sections, $s unless grep { $_ eq $s } @sections;
    }
    close FILE;

    # sorted.
    my @sorted = sort @sections;
    
    # print a selection.
    unless ($section_number) {
        for (my $i=0; $i <= $#sorted; ++$i) {
            print "$i. ", $sorted[$i], "\n";
        }
        print 'SELECTION> ';
        $section_number = <STDIN>;
    }
    my ($start_section, $finish_section);
    if ($section_number =~ /-/) {
        my ($start_number, $finish_number) = split /-/, $section_number;
        $start_section = $sorted[$start_number];
        $finish_section = $sorted[$finish_number];
    } else {
        $start_section = $sorted[$section_number];
        $finish_section = $sorted[$section_number];
    }
    usage() if (!$start_section or !$finish_section);

    # find $start_at and $finish_at
    my $f = 0;
    my $g = 0;
    open FILE, "<$wordlist";
    while (my $line = <FILE>) {
        if ($line =~ /\|.*\|.*\|.*$start_section$/ and !$f) {
            ++$f;
            $start_at = $.;
        }
        if ($f and $line =~ /\|.*\|.*\|.*$finish_section$/ and !$g) {
            ++$g;
        }
        if ($g and $line !~ /\|.*\|.*\|.*$finish_section$/) {
            $finish_at = $. - 1;
            last;
        }
    }
    close FILE;
    $section_length = $finish_at - $start_at;
    return ($section, $section_length, $start_at, $finish_at);
}

sub list_words {
    my ($start_at, $finish_at, $register) = @_;
    open FILE, "<$wordlist";
    while (<FILE>) {
        chomp;
        next if $. < $start_at;
        last if $. > $finish_at;
        my ($char, $pinyin, $english, $section) = split /\|/;
        next if check_register("$char $pinyin --> $english", $register, 'check_only');
        printf "%-5s %-10s %-20s\n", $char, $pinyin, $english;
    }
    close FILE;
    exit;
}

sub get_classifier {
    my ($english, $hid_cl) = @_;
    my ($cl_char, $cl_pinyin, $rest);
    if ($english =~ /CL:/) {
        $classifier = $english;
        $classifier =~ s/^.*CL:(.).*$/$1/;
        $hid_cl =~ s/,? *CL:[^ ]+ / /g;  # one Chinese char matched by /.../
        open FILE, "<$wordlist";
        while (<FILE>) {
    	if (/^$classifier\|/) {
    	    chomp;
    	    ($cl_char, $cl_pinyin, $rest) = split /\|/;
    	    last;
    	}
        }
        close FILE;
    }
    return ($cl_char, $cl_pinyin, $rest);
}

sub elapsed {
    my ($ssec, $smil, $fsec, $fmil) = @_;
    my ($esec, $emil, $elapsed);
    if ($fmil >= $smil) {
        $esec = $fsec - $ssec;
        $emil = $fmil - $smil;
    } else {
        $esec = $fsec - $ssec + 1;
        $emil = $fmil + 1000000 - $smil;
    }
    $emil = $emil / 1000000;
    $elapsed = $esec + $emil;
    #print "computed elapsed $elapsed sec\n";
    return $elapsed;
}

sub pinyin_compare {
    my ($response, $pinyin) = @_;
    $response ||= '';
    chomp $response;
    if ($response !~ /[a-zA-Z']/) {
        return 0;
    }
    foreach my $i ('á', 'ā', 'ǎ', 'à') {
        $pinyin =~ s/$i/a/g;
    }
    foreach my $i ('è', 'é', 'ē', 'ě') {
        $pinyin =~ s/$i/e/g;
    }
    foreach my $i ('í', 'ī', 'ì', 'ǐ') {
        $pinyin =~ s/$i/i/g;
    }
    foreach my $i ('ò', 'ō', 'ó', 'ǒ') {
        $pinyin =~ s/$i/o/g;
    }
    foreach my $i ('ū', 'ù', 'ǔ', 'ú') {
        $pinyin =~ s/$i/u/g;
    }
    foreach my $i ('ǚ', 'ǜ', 'ǘ') {
        $pinyin =~ s/$i/v/g;
    }
    if ($pinyin =~ /\b$response\b/i) {
        return 1;
    } else {
        return 0;
    }
}

sub break_up_response {
    my ($response, $pinyin) = @_;
    chomp $response;
    $response =~ s/^ *//;
    $response =~ s/ *$//;
    $response =~ s/ +/ /g;
    my ($resp_piny, $resp_engl);
    # (\w|')+ - allow for words like qin'ai
    if ($pinyin =~ /^(\w|')+ (\w|')+$/) {
        ($resp_piny, $resp_engl) = ($response =~ /^((\w|')+ (\w|')+) (.*)$/);
    } elsif ($pinyin =~ /^(\w|')+ (\w|')+ (\w|')+$/) {
        ($resp_piny, $resp_engl) = ($response =~ /^((\w|')+ (\w|')+ (\w|')+) (.*)$/);
    } elsif ($pinyin =~ /^(\w|')+ (\w|')+ (\w|')+ (\w|')+$/) {
        ($resp_piny, $resp_engl) = ($response =~ /^((\w|')+ (\w|')+ (\w|')+ (\w|')+) (.*)$/);
    } else {
        if ($response =~ / /) {
            ($resp_piny, $resp_engl) = ($response =~ /^((?:\w|')+) (.*)$/);
        } else {
            $resp_piny = $response;
            if ($resp_piny) {
                print "ENGLISH> ";
                $resp_engl = <STDIN>;
                chomp $resp_engl;
            } else {
                $resp_engl = '';
            }
        }
    }
    return ($resp_piny, $resp_engl);
}

sub update_register {
    my ($words, $correct, $register) = @_;
    my $modified = 0;
    open REG, "<$register";
    open TMPREG, ">$register.tmp";
    while (<REG>) {
        if (/^\Q$words\E/) {
            chomp;
            print TMPREG $_, $correct, "\n";
            ++$modified;
        } else {
            print TMPREG $_;
        }
    }
    if (!$modified) {
        printf TMPREG "$words $correct\n";
    }
    close REG;
    close TMPREG;
    rename "$register.tmp", "$register";
}

sub check_register {
    my ($words, $register, $check_only) = @_;
    $check_only ||= '';
    my $status = 0;
    open REG, "<$register";
    while (<REG>) {
        chomp;
        if (/^\Q$words\E/ and /\+{$threshold}$/) {
            if ($check_only) {
                $status = 1;
            } else {
                my $random = int(rand(100)) + 1;
                if ($random > $skip) {
                    $status = 1;
                    my ($word, $hist) = /^(.*) ([+-]+)$/;
                    print "    [$word] [$hist]\n";
                }
            }
        }
    }
    close REG;
    return $status;
}

sub get_hist {
    my ($words, $register) = @_;
    my $str = '';
    open REG, "<$register";
    while (<REG>) {
        chomp;
        if (/^\Q$words\E/) {
            s/^\Q$words\E +//;
            $str = $_;
            last;
        }
    }
    close REG;
    return $str;
}

sub fix_register {
    my $ref = shift;
    foreach my $register (@$ref) {
        print "fixing register $register ...\n";
        open FILE, "<$wordlist";
        while (<FILE>) {
            chomp;
            my ($chars, $pinyin, $english, $section) = split /\|/;
            open REGTMP, ">$register.tmp";
            open REG, "<$register";
            while (<REG>) {
                chomp;
                if (/\Q$chars $pinyin\E/ and !/\Q--> $english\E/) {
                    /^.* ([+-]*)$/;
                    print "CORRECTING:$chars|$pinyin\n";
                    print REGTMP "$chars $pinyin --> $english $1\n";
                } else {
                    print REGTMP "$_\n";
                }
            }
            close REG;
            close REGTMP;
            rename "$register.tmp", "$register";
        }
        close FILE;
    }
    exit;
}

sub on_exit {
    !$got_to_main and exit;
    my $now = localtime(time);
    open LOG, ">>$logfile";
    $average_correct =~ s/^(.*\.\d\d).*$/$1/;
    $average_time =~ s/^(.*\.\d\d).*$/$1/;
    print "attempted $attempted, correct $correct ($average_correct %), average time $average_time seconds.\n";
    print LOG "$now: attempted $attempted, correct $correct ($average_correct %), average time $average_time seconds.\n";
    foreach my $word (@incorrect) {
        print LOG "  $word\n";
    }
    close LOG;
    exit 0;
}

# end of script
