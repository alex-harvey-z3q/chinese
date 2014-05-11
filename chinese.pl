#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use open ':encoding(utf8)';
binmode(STDOUT, ':utf8');
binmode(STDIN, ':utf8');

use Getopt::Long qw(:config no_ignore_case);
use Term::ANSIColor;
use List::Util 'shuffle';

# global constants.
my $wordlist = 'chinese';
my $register = 'chinese.reg';
my $logfile = 'chinese.log';
my $characters = 'characters';
my $grammar = 'grammar';
my $grammar_reg = 'grammar.reg';
my $lessons = 'lessons';

my $threshold = 5;
my $skip = 20;

# seed the randomiser.
srand;

# handle CTRL-C.
$SIG{INT} = \&on_exit;

my $date = localtime(time);
my ($section, %mode) = process_options({
    'mode' => 'vocabulary', 'selection' => 'random'});

##
## main section.
##

my @selection = get_selection($section, \%mode);

#[
#  {
#    'question' => [ '纸', '帋', 'zhǐ' 'paper, classifier for documents ...', 'Rapid Chinese' ],
#    'response' => 'paper',
#    'selection' => 'C->E',
#    'result' => 1
#  },
#  {
#     'question' => [ '多少', '', 'duōshao', 'how much, how many, ...', 'Rapid Chinese' ],
#  },
#]

ask_questions(\@selection, \%mode);

on_exit();

sub on_exit {
    log_results(\@selection, \%mode, $date, $logfile);
    exit 0;
}

##
## subroutines.
##

sub ask_questions {
    my ($s, $m) = @_;
    my $length_of_selection = $#{ $s };
    my %mode = %{ $m };
    for (my $i=0; $i <= $length_of_selection; ++$i) {

        # get the question data from @selection structure.
        my ($simplified, $traditional, $pinyin, $english, $section) = @{ ${ ${ $s }[$i] }{'question'} };

        # set variables.
        my $presented = $i+1;
        my ($chinese_chars_in_question, $history_reg);
        if ($mode{'mode'} eq 'grammar') {
             $chinese_chars_in_question = $simplified;
             $history_reg = $grammar_reg;
        } elsif ($mode{'mode'} eq 'vocabulary') {
             $chinese_chars_in_question = $traditional ? "$simplified/$traditional" : $simplified;
             $history_reg = $register;
        }
        my ($question_line, $answer_line);
        my $chars = $traditional ? "$simplified/$traditional" : $simplified;
        my ($status, $hist_str) = check_register($simplified, $history_reg);
        my $coin_toss = int(rand(2));

        if ($mode{'selection'} eq 'chinese' or
           ($mode{'selection'} eq 'random' and $coin_toss == 0)) {

            ${ ${ $s }[$i] }{'selection'} = 'C->E';
            $question_line = "$chinese_chars_in_question [$presented of $length_of_selection] [$hist_str]\n";
            $answer_line = "$chars, $pinyin, $english [$section]\n";

        } elsif ($mode{'selection'} eq 'english' or
           ($mode{'selection'} eq 'random' and $coin_toss == 1)) {

            ${ ${ $s }[$i] }{'selection'} = 'E->C';
            $question_line = "$english [$presented of $length_of_selection] [$hist_str]\n";
            $answer_line = "$chars, $pinyin [$section]\n";
        }

        # check the register and drop out here for words we already know.
        if (!$status) {
            print color('cyan'), "    $hist_str:$chars, $pinyin, $english\n", color('reset');
            next;
        }

        # get a response from the user.
        my $response;
        while (!defined $response) {
            print $question_line;
            print 'ANSWER> ';
            $response = <STDIN>;
            chomp($response);
            process_command(\$response);
        }

        # save the response in the @selection structure.
        ${ ${ $s }[$i] }{'response'} = $response;

        # if appropriate, show the character breakdown from character dictionary.
        lookup_chars($simplified)
            if ($mode{'mode'} ne 'grammar' and
                ($mode{'selection'} eq 'chinese' or
                    ($mode{'selection'} eq 'random' and $coin_toss == 0)));
        print "\n";

        # show the answer.
        print $answer_line;

        # determine if the answer is correct.
        my $am_correct = check_answer($response, $simplified, $pinyin, $english,
            ${ ${ $s }[$i] }{'selection'}, $mode{'mode'});

        print "\n";
        print $am_correct ? "CORRECT\n" : "INCORRECT\n";
        ${ ${ $s }[$i] }{'result'} = $am_correct;
        print "\n";

        update_register($simplified, $am_correct, $history_reg);
    }
}

sub check_answer {
    my ($response, $simplified, $pinyin, $english, $selection, $mode) = @_;
    my $am_correct;
    if ($selection eq 'E->C') {
        $am_correct = ($response eq $simplified);
    } elsif ($selection eq 'C->E' and $mode eq 'vocabulary') {
        my ($resp_piny, $resp_engl) = split /, */, $response;
        $am_correct = pinyin_compare($resp_piny, $pinyin) && ($english =~ $resp_engl);
    } elsif ($selection eq 'C->E' and $mode eq 'grammar') {
        $response =~ s/  */ /g;
        $am_correct = ($response eq $english);
    }
    return $am_correct;
}

sub check_register {
    my ($simplified, $register) = @_;
    my $status = 1;
    my $hist_str = '';
    open FILE, "<$register";
    while (<FILE>) {
        chomp;
        if (/^$simplified/) {
            s/^$simplified//;
            $hist_str = $_;
            if (/\+{$threshold}$/) {
                my $random = int(rand(100)) + 1;
                $status = 0 if $random > $skip;
            }
            last;
        }
    }
    close FILE;
    return ($status, $hist_str);
}

sub command_help {
    print <<EOF;
LK <word> - look up <word> in the word dictionary
CR <word> - look up <word> in the character dictionary
PR        - print the question again
LS        - list all grammar sections
GL <sect> - print the grammar lesson relating to <sect>; use LS to get <sect>
HELP      - show this help
EOF
}

sub get_selection {
    my ($sect, $m) = @_;
    my @sections;
    my @seen_sections;
    my @selection;
    my $file = ${ $m }{'mode'} eq 'grammar' ? $grammar : $wordlist;

    # build an array of alphabetically sorted sections.
    my @named_sections;
    open FILE, "<$file";
    while (<FILE>) {
        chomp;
        my ($a, $b, $c, $d, $s) = split /\|/;
        push @named_sections, $s unless grep {$_ eq $s} @named_sections;
    }
    close FILE;
    my @sorted_named_sections = sort {lc $a cmp lc $b} @named_sections;

    # build the corresponding array of named sections chosen by the user.
    if ($sect) {
        my @bits = split /,/, $section;
        foreach my $bit (@bits) {
            if ($bit =~ /-/) {
                my ($low, $high) = split /-/, $bit;
                for (my $i=$low; $i <= $high; ++$i) {
                    push @sections, $sorted_named_sections[$i-1];
                }
            } else {
                push @sections, $sorted_named_sections[$bit-1];
            }
        }
    }

    # find all words specified by those sections.
    open FILE, "<$file";
    while (<FILE>) {
        chomp;
        my ($simplified, $traditional, $pinyin, $english, $section) = split /\|/;
        if ($sect) {
            push @selection,
                {'question' => [$simplified, $traditional, $pinyin, $english, $section]}
                    if grep {$_ eq $section} @sections;
        } else {
            push @selection,
                {'question' => [$simplified, $traditional, $pinyin, $english, $section]};
        }
    }
    close FILE;

    # return them in random order.
    return shuffle(@selection);
}

sub grammar_lookup {
    my $section = shift;
    open FILE, "<$lessons";
    while (<FILE>) {
        my ($sect, $lesson) = split /\|/;
        if ($sect eq $section) {
            $lesson =~ s/"/\\"/g;
            eval "print \"$lesson\";";
        }
    }
    close FILE;
}

sub list_sections {
    my $mode = shift;
    my @sections;

    my $file = $mode eq 'grammar' ? $grammar : $wordlist;
    open FILE, "<$file";
    while (<FILE>) {
        chomp;
        my ($a, $b, $c, $d, $s) = split /\|/;
        push @sections, $s unless grep {$_ eq $s} @sections;
    }
    close FILE;

    my @sorted = sort {lc $a cmp lc $b} @sections;

    for (my $i=1; $i <= $#sorted + 1; ++$i) {
        print "$i. ", $sorted[$i-1], "\n";
    }
}

sub log_results {
    my ($s, $m, $date, $logfile) = @_;
    my $length_of_selection = $#{ $s };
    my %mode = %{ $m };

    # open logfile.
    open FILE, ">>$logfile";
    print FILE "$date:\n";

    # calculate number correct.
    my $presented = 0;
    my $total_correct = 0;
    for (my $i=0; $i <= $length_of_selection; ++$i) {
        ++$presented if (exists ${ ${ $s }[$i] }{'selection'});
        ++$total_correct if (${ ${ $s }[$i] }{'response'});
    }
    my $average_correct = ($total_correct / $presented) * 100;
    $average_correct =~ s/^(.*\.\d\d).*$/$1/;
    print "attempted $presented, correct $total_correct ($average_correct %)\n";
    print FILE "attempted $presented, correct $total_correct ($average_correct %)\n";

    # log results.
    for (my $i=0; $i <= $length_of_selection; ++$i) {
        if (exists ${ ${ $s }[$i] }{'response'}) {
            my $selection = ${ ${ $s }[$i] }{'selection'};
            my $response = ${ ${ $s }[$i] }{'response'};
            my $result = ${ ${ $s }[$i] }{'result'};
            my ($simplified, $traditional, $pinyin, $english, $section) = @{ ${ ${ $s }[$i] }{'question'} };
            my $chars = $traditional ? "$simplified/$traditional" : $simplified;
            if (!$result) {
                if ($selection eq 'C->E') {
                    print FILE "  $chars: $response (should be: $pinyin, $english)\n";
                } elsif ($selection eq 'E->C') {
                    print FILE "  $english: $response (should be $chars)\n"
                }
            }
        }
    }

    # close logfile.
    close FILE;
}

sub lookup_chars {
    my $chars = shift;
    my @chars = split '', $chars;
    foreach my $c (@chars) {
        print color('bold red'), $c, color('reset'), ":\n";
        open FILE, "<$characters";
        while (<FILE>) {
            chomp;
            next if !/\+\d+ $c/;
            my @bit = split /$c/;
            print '  ';
            print color('cyan'), $bit[0];
            for (my $i=1; $i<=$#bit; $i++) {
                print color('bold red'), $c, color('reset');
                print color('cyan'), $bit[$i], color('reset');
            }
            print "\n";
        }
        close FILE;
    }
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

sub process_command {
    my $command = shift;
    if ($$command =~ /^HELP/) {
        command_help();
        print "\n";
        $$command = undef;
    } elsif ($$command =~ /^LK/) {
        chomp $$command;
        my ($word) = ($$command =~ /LK +(.*)/);
        system("awk -F'\|' '{print \"  \"\$1\"   \"\$2\"   \"\$3}' $wordlist |grep --color=auto '$word'");
        print "\n";
        $$command = undef; # tells calling function that response contained a command.
    } elsif ($$command =~ /^CR/) {
        chomp $$command;
        my ($word) = ($$command =~ /CR +(.*)/);
        system("grep -w '$word' $characters |grep --color=auto '^.*$word'");
        print "\n";
        $$command = undef;
    } elsif ($$command =~ /^PR/) {
        print "\n";
        $$command = undef;
    } elsif ($$command =~ /^LS/) {
        print "\n";
        list_sections('grammar');
        print "\n";
        $$command = undef;
    } elsif ($$command =~ /^GL/) {
        print "\n";
        my ($section) = ($$command =~ /GL +(.*)/);
        grammar_lookup($section);
        print "\n";
        $$command = undef;
    }
}

sub process_options {
    my $default = shift;
    my %mode = %{ $default };
    my $section = 0;
    my ($help, $list_mode,
        $chinese_mode, $english_mode, $grammar_mode,
        $threshold, $skip);
    GetOptions(
        'help|h' => \$help,
        'section|s=s' => \$section,
        'list|L' => \$list_mode,
        'chinese|C' => \$chinese_mode,
        'english|e' => \$english_mode,
        'grammar|G' => \$grammar_mode,
        'threshold|T=s' => \$threshold,
        'skip|K=s' => \$skip,
    );
    usage() if $help;
    if (($chinese_mode and $english_mode) or
        ($chinese_mode and $grammar_mode) or
        ($english_mode and $grammar_mode)) {
        print "incompatible use of modes\n";
        usage();
    }
    $mode{'mode'} = 'grammar' if $grammar_mode;
    $mode{'selection'} = 'chinese' if $chinese_mode;
    $mode{'selection'} = 'english' if $english_mode;
    list_sections($mode{'mode'}) and exit if $list_mode;
    return ($section, %mode);
}

sub update_register {
    my ($simplified, $am_correct, $register) = @_;
    my $plus_or_minus = $am_correct ? '+' : '-';
    my $modified = 0;
    open REG, "<$register";
    open TMPREG, ">$register.tmp";
    while (<REG>) {
        if (/^$simplified\b/) {
            chomp;
            print TMPREG $_, $plus_or_minus, "\n";
            ++$modified;
        } else {
            print TMPREG $_;
        }
    }
    if (!$modified) {
        printf TMPREG "${simplified}${plus_or_minus}\n";
    }
    close REG;
    close TMPREG;
    rename "$register.tmp", "$register";
}

sub usage {
    print <<EOF;
Usage: $0 {-h|-l|-d}
    --help|-h      - show this help
    --list|-L      - list sections

Usage: $0
    --chinese|-C    - chinese character mode
    --english|-e    - english mode
    --grammar|-G    - grammar mode
    --threshold|-T <threshold> - set number correct threshold
      -T 100   - only consider skipping if this word is right 100 times in a row
      -T 1     - consider skipping if this word was right last time
    --skip|-K <skip>           - set skip threshold
      -K 100   - never skip a word
      -K 0     - always skip, if threshold is met

Answers to Chinese questions are expected to be comma-separated, e.g.
Question: 什么
Answer: shenme, what
EOF
    exit;
}

# end of script
