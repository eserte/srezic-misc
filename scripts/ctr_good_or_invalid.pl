#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008-2010,2012,2013,2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use File::Copy qw(move);
use Tk;
use Tk::Balloon;
use Tk::More;
use Tk::ErrorDialog;
use Getopt::Long;
use POSIX qw(strftime);

# Patterns for report analysis
my $v_version_qr = qr{v[\d\.]+};
my $at_source_without_dot_qr = qr{at (?:\(eval \d+\)|\S+) line \d+(?:, <[^>]+> line \d+)?};
my $at_source_qr = qr{$at_source_without_dot_qr\.};

my $the_ct_states_rx = qr{(?:pass|unknown|na|fail)};

my $c_ext_qr = qr{\.(?:h|c|hh|cc|xs|cpp|hpp|cxx)};

my @common_analysis_button_config =
    (
     -padx => 0,
     -pady => 0,
     -borderwidth => 1,
     -relief => 'raised',
    );

my $only_good;
my $auto_good = 1;
my $only_pass_is_good;
my $sort_by_date;
my $reversed;
my $geometry;
my $quit_at_end = 1;
my $do_xterm_title = 1;
my $show_recent_states = 1;
my $do_check_screensaver = 1;
GetOptions("good" => \$only_good,
	   "auto-good!" => \$auto_good,
	   "only-pass-is-good" => \$only_pass_is_good,
	   "sort=s" => sub {
	       if ($_[1] eq 'date') {
		   $sort_by_date = 1;
	       } else {
		   die "-sort only takes the date value currently";
	       }
	   },
	   "r" => \$reversed,
	   "geometry=s" => \$geometry,
	   "quit-at-end!" => \$quit_at_end,
	   "xterm-title!" => \$do_xterm_title,
	   "recent-states!" => \$show_recent_states,
	   "check-screensaver!" => \$do_check_screensaver,
	  )
    or die <<EOF;
usage: $0 [-good] [-[no]auto-good] [-sort date] [-r] [-geometry x11geom]
          [-noquit-at-end] [-[no]xterm-title]
          [-[no]recent-states] [-[no]check-screesaver] [directory [file ...]]
EOF

my $reportdir = shift || "$ENV{HOME}/var/cpansmoker";

if ($auto_good) {
    # just to check if X11::Protocol etc. is available
    is_user_at_computer();
}

if ($do_xterm_title) {
    check_term_title();
}

my @files = @ARGV;
if (@files == 1 && -d $files[0]) {
    $reportdir = $files[0];
    @files = ();
}
if (!@files) {
    @files = glob("$reportdir/new/*.rpt");
}
if (!@files) {
    my $msg = "No files given or found";
    set_term_title("report sender: $msg");
    die "$msg.\n";
}

my $good_directory = "$reportdir/sync";
if (!-d $good_directory) {
    mkdir $good_directory or die "While creating $good_directory: $!";
}
my $invalid_directory = "$reportdir/invalid";
if (!-d $invalid_directory) {
    mkdir $invalid_directory or die "While creating $invalid_directory: $!";
}
my $undecided_directory = "$reportdir/undecided";
if (!-d $undecided_directory) {
    mkdir $undecided_directory or die "While creating $undecided_directory: $!";
}
my $done_directory = "$reportdir/done";
my @recent_done_directories;
if (-d $done_directory) {
    my $add_done_directory = sub {
	my $month = shift;
	my $check_directory = "$done_directory/$month";
	push @recent_done_directories, $check_directory
	    if -d $check_directory;
    };

    my @l = localtime;
    my $this_month = strftime "%Y-%m", @l;
    $add_done_directory->($this_month);

    for (1..1) { # XXX make number of prev months configurable?
	$l[4]--;
	if ($l[4] < 0) { $l[4] = 11; $l[5]-- }
	my $month = strftime "%Y-%m", @l;
	$add_done_directory->($month);
    }
}

my $good_rx = $only_pass_is_good ? qr{/(pass)\.} : qr{/(pass|unknown|na)\.};

my @new_files;
# pass, na, unknown are always good:
for my $file (@files) {
    if ($file =~ $good_rx) {
	move $file, $good_directory
	    or die "Cannot move $file to $good_directory: $!";
    } else {
	push @new_files, $file;
    }
}
@files = @new_files;
if (!@files) {
    my $msg = "No file needs to be checked manually";
    warn "$msg, finishing.\n";
    set_term_title("report sender: $msg");
    exit;
}
if ($auto_good) {
    if (!is_user_at_computer()) {
	my $msg = scalar(@files) . " distribution(s) with FAILs (inactive user)";
	warn "Skipping $msg.\n";
	set_term_title("report sender: $msg");
	exit 1;
    }
} elsif ($only_good) {
    my $msg = scalar(@files) . " distribution(s) with FAILs";
    warn "Skipping $msg.\n";
    set_term_title("report sender: $msg");
    exit 1;
}

if ($sort_by_date) {
    @files =
	map {
	    $_->[1]
	} sort {
	    $a->[0] <=> $b->[0]
	} map {
	    my @s = stat $_;
	    [$s[9], $_]
	} @files;
}
if ($reversed) {
    @files = reverse @files;
}

set_term_title("report sender: interactive mode");

my $mw = tkinit;
$mw->geometry($geometry) if $geometry;
my $balloon = $mw->Balloon;

my $currfile_i = 0;
my $currfile;
my($currdist, $currversion);
my $modtime;

my $prev_b;
my $next_b;
my $good_b;
my $more = $mw->Scrolled("More")->pack(-fill => "both", -expand => 1);
{
    my $f = $mw->Frame->pack(-fill => "x");
    $f->Label(-text => "Report created:")->pack(-side => "left");
    $f->Label(-textvariable => \$modtime)->pack(-side => "left");

    $f->Label(-text => "/ " . $#files)->pack(-side => "right");
    $f->Label(-textvariable => \$currfile_i)->pack(-side => "right");
}
my $analysis_frame = $mw->Frame->place(-relx => 1, -rely => 0, -x => -2, -y => 2, -anchor => 'ne');
{
    my $f = $mw->Frame->pack(-fill => "x");
    $prev_b = $f->Button(-text => "Prev (F4)",
	       -command => sub {
		   if ($currfile_i > 0) {
		       $currfile_i--;
		       set_currfile();
		   } else {
		       die "No files before!";
		   }
	       })->pack(-side => "left");
    $good_b = $f->Button(-text => "GOOD (C-g)",
	       -command => sub {
		   move $currfile, $good_directory
		       or die "Cannot move $currfile to $good_directory: $!";
		   nextfile();
	       }
	      )->pack(-side => "left");
    $f->Button(-text => "INVALID",
	       -command => sub {
		   move $currfile, $invalid_directory
		       or die "Cannot move $currfile to $invalid_directory: $!";
		   nextfile();
	       }
	      )->pack(-side => "left");
    $f->Button(-text => "UNDECIDED",
	       -command => sub {
		   move $currfile, $undecided_directory
		       or die "Cannot move $currfile to $undecided_directory: $!";
		   nextfile();
	       }
	      )->pack(-side => "left");
       
    $next_b = $f->Button(-text => "Next (F5)",
	       -command => sub { nextfile() },
	      )->pack(-side => "left");

    $f->Label(-width => 2)->pack(-side => "left"); # Spacer

    $f->Button(-text => "RT",
	       -command => sub {
		   require CGI;
		   require Tk::Pod::WWWBrowser;
		   Tk::Pod::WWWBrowser::start_browser("http://rt.cpan.org/Public/Dist/Display.html?" . CGI->new({Name=>$currdist})->query_string);
	       })->pack(-side => "left");
    $f->Button(-text => "Matrix",
	       -command => sub {
		   require CGI;
		   require Tk::Pod::WWWBrowser;
		   Tk::Pod::WWWBrowser::start_browser("http://matrix.cpantesters.org/?" . CGI->new({dist=>$currdist,# reports=>"1"
												   })->query_string);
	       })->pack(-side => "left");
    $f->Button(-text => "ctgetreports",
	       -command => sub {
		   require Tk::ExecuteCommand;
		   require File::Temp;
		   my($tmpfh, $tempfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_report.txt");
		   my $t = $mw->Toplevel(-title => "Reports on $currdist $currversion");
		   my $ec = $t->ExecuteCommand()->pack;
		   $ec->configure(-command => "ctgetreports $currdist --ctformat=yaml --dumpvars=. --dumpfile=$tempfile");
		   $ec->execute_command;
		   $ec->bell;
		   $ec->destroy;
		   $t->update;
		   my $m = $t->Scrolled("More", -scrollbars => "osoe")->pack(qw(-fill both -expand 1));
		   $t->update;
		   $m->Load($tempfile);
		   $m->Subwidget("scrolled")->focus;
	       })->pack(-side => "left");
    $f->Button(-text => "solve",
	       -command => sub {
		   require Tk::ExecuteCommand;
		   require File::Temp;
		   my($tmpfh, $tempfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_report.txt");
		   my $t = $mw->Toplevel(-title => "Solve $currdist $currversion");
		   my $ec = $t->ExecuteCommand()->pack(qw(-fill both -expand 1));
		   $ec->configure(-command => "ctgetreports $currdist --ctformat=yaml --solve --dumpfile=$tempfile");
		   $ec->execute_command;
		   $ec->bell;
		   $ec->focus;
	       })->pack(-side => "left");
}

set_currfile();

$mw->bind("<Control-q>" => sub { $mw->destroy });
$mw->bind("<Control-g>" => sub { $good_b->invoke });
$mw->bind("<F4>" => sub { $prev_b->invoke });
$mw->bind("<F5>" => sub { $next_b->invoke });

if ($auto_good) {
    $mw->repeat(2*1000, sub {
		    if (!is_user_at_computer()) {
			warn "User not anymore at computer, quitting...\n";
			$mw->destroy;
		    }
		})
}

#$mw->FullScreen; # does not work (with fvwm2 only?)
#$mw->attributes(-fullscreen => 1); # does not work (with fvwm2 only?)
MainLoop;

set_term_title("report sender: finished");

sub set_currfile {
    $currfile = $files[$currfile_i];
    $more->Load($currfile);
    my $textw = $more->Subwidget("scrolled");
    $textw->SearchText(-searchterm => qr{PROGRAM OUTPUT});
    $textw->yviewScroll(30, 'units'); # actually a hack, I would like to have PROGRAM OUTPUT at top
    my $currfulldist;
    my %analysis_tags;
    if (open my $fh, $currfile) {
	# Parse header
	my $subject;
	my $x_test_reporter_perl;
	while(<$fh>) {
	    if (/^Subject:\s*(.*)/) {
		$subject = $1;
		if (/^Subject:\s*(?:FAIL|PASS|UNKNOWN|NA) (\S+)/) {
		    $currfulldist = $1;
		} else {
		    warn "Cannot parse distribution out of '$subject'";
		}
	    } elsif (/^X-Test-Reporter-Perl:\s*(.*)/i) {
		$x_test_reporter_perl = $1;
	    } elsif (/^$/) {
		last;
	    }
	}

	# Parse body
	{
	    my $section = '';

	    my $program_output = {}; # collects only one line in PROGRAM OUTPUT

	    my $add_analysis_tag = sub {
		my($tag, $line) = @_;
		if (!defined $line) { $line = $. }
		if (!exists $analysis_tags{$tag}) {
		    $analysis_tags{$tag} = { line => $line };
		}
	    };

	    while(<$fh>) {
		if (/^PROGRAM OUTPUT$/) {
		    $section = 'PROGRAM OUTPUT';
		} elsif (/^PREREQUISITES$/) {
		    if ($section eq 'PROGRAM OUTPUT' && defined $program_output->{content}) {
			if (
			    $program_output->{content} =~ /No tests defined for \S+ extension\.$/ || # EUMM version
			    $program_output->{content} =~ /No tests defined\.$/                      # MB version
			   ) {
			    $add_analysis_tag->('notests', $program_output->{line});
			}
		    }
		    $section = 'PREREQUISITES';
		} elsif (/^ENVIRONMENT AND OTHER CONTEXT$/) {
		    $section = 'ENVIRONMENT';
		} elsif ($section eq 'PROGRAM OUTPUT') {
		    if      (
			     /^Warning: Perl version \S+ or higher required\. We run \S+\.$/ ||
			     /^\s*!\s*perl \([\d\.]+\) is installed, but we need version >= v?[\d\.]+$/ ||
			     /^ERROR: perl: Version [\d\.]+ is installed, but we need version >= [\d\.]+ $at_source_qr$/ ||
			     /^(?:\s*#\s+Error:\s+)?Perl $v_version_qr required--this is only $v_version_qr, stopped $at_source_qr$/
			    ) {
			$add_analysis_tag->('low perl');
		    } elsif (
			     /^Result: NOTESTS$/
			     ## Rely solely on the above regexp --- the below may happen because a sub-module has no tests
			     ## but see $program_output logic before PREREQUISITES section
			     # || /^No tests defined for \S+ extension\.$/
			     # || /^No tests defined\.$/
			    ) {
			$add_analysis_tag->('notests');
		    } elsif (
			     /^OS unsupported$/ ||
			     /^OS unsupported $at_source_qr$/ ||
			     /^No support for OS at /
			    ) {
			$add_analysis_tag->('os unsupported');
		    } elsif (
			     /^(?:#\s+Error:\s+)?(?:Smartmatch|given|when) is experimental $at_source_qr$/
			    ) {
			$add_analysis_tag->('smartmatch');
		    } elsif (
			     /^(?:push|pop|keys|shift|unshift) on reference is experimental $at_source_qr$/
			    ) {
			$add_analysis_tag->('experimental functions on references');
		    } elsif (
			     /^#\s+Failed test 'POD test for [^']+'$/
			    ) {
			$add_analysis_tag->('pod test');
		    } elsif (
			     /^#\s+Failed test 'Pod coverage on [^']+'$/ ||
			     /^#\s+Coverage for \S+ is [\d\.]+%, with \d+ naked subroutines?:$/
			    ) {
			$add_analysis_tag->('pod coverage test');
		    } elsif (
			     /^#\s+Failed test 'POD spelling for [^']+'$/
			    ) {
			$add_analysis_tag->('pod spelling test');
		    } elsif ( # this should come before the generic 'prereq fail' test
			     m{^(?:#\s+Error:\s+)?Can't locate \S+ in \@INC \(\@INC contains.* /etc/perl} || # Debian version
			     m{^(?:#\s+Error:\s+)?Can't locate \S+ in \@INC \(\@INC contains.* /usr/local/lib/perl5/5.\d+/BSDPAN} # FreeBSD version
			    ) {
			$add_analysis_tag->('system perl used');
		    } elsif (
			     /^(?:#\s+Error:\s+)?Can't locate \S+ in \@INC/ ||
			     /^(?:#\s+Error:\s+)?Base class package ".*?" is empty\.$/
			    ) {
			$add_analysis_tag->('prereq fail');
		    } elsif (
			     /Type of arg \d+ to (?:keys|each) must be hash \(not (?:hash element|private (?:variable|array))\)/ ||
			     /Type of arg \d+ to (?:push|unshift) must be array \(not array element\)/
			    ) {
			$add_analysis_tag->('container func on ref');
		    } elsif (
			     /This Perl not built to support threads/
			    ) {
			$add_analysis_tag->('unthreaded perl');
		    } elsif (
			     /error: .*?\.h: No such file or directory/
			    ) {
			$add_analysis_tag->('missing c include');
		    } elsif (
			     /gcc: not found/ ||
			     /gcc: Kommando nicht gefunden/
			    ) {
			$add_analysis_tag->('gcc not found');
		    } elsif (
			     /^.*?$c_ext_qr:\d+:\s+error:\s+/ || # gcc
			     /^.*?$c_ext_qr:\d+:\d+:\s+error:\s+/ # gcc or clang
			    ) {
			$add_analysis_tag->('c compile error');
		    } elsif (
			     /^\s*#\s+Error:  Can't load '.*?\.so' for module .*: Undefined symbol ".*?" $at_source_qr/
			    ) {
			$add_analysis_tag->('undefined symbol in shared lib');
		    } elsif (
			     /Out of memory!/
			    ) {
			$add_analysis_tag->('out of memory');
		    } elsif (
			     /^# Perl::Critic found these violations in .*:$/
			    ) {
			$add_analysis_tag->('perl critic');
		    } elsif (
			     /syntax error.*\bnear "\$\w+ qw\(/ ||
			     /syntax error.*\bnear "\$\w+ qw\// ||
			     /syntax error.*\bnear "->\w+ qw\(/
			    ) {
			$add_analysis_tag->('qw without parentheses');
		    } elsif (
			     /==> MISMATCHED content between MANIFEST and distribution files! <==/
			    ) {
			$add_analysis_tag->('signature mismatch');
		    } elsif (
			     /^Attribute \(.+?\) does not pass the type constraint because: .* $at_source_without_dot_qr$/ || # Validation failed for '.+?' with value or ... is too long
			     /^Attribute \(.+?\) is required $at_source_without_dot_qr$/
			    ) {
			$add_analysis_tag->('type constraint violation');
		    } elsif (
			     /^(?:# died: )?Insecure .+? while running with -T switch $at_source_qr$/
			    ) {
			$add_analysis_tag->('taint');
		    } elsif (
			     /# Error: META.yml does not conform to any recognised META.yml Spec./
			    ) {
			$add_analysis_tag->('meta.yml spec');
		    } elsif (
			     /^Test::Builder::Module version [\d\.]+ required--this is only version [\d\.]+ $at_source_qr$/ ||
			     /^Test::Builder version [\d\.]+ required--this is only version [\d\.]+ $at_source_qr$/ ||
			     m{^\Q# Error: This distribution uses an old version of Module::Install. Versions of Module::Install prior to 0.89 does not detect correcty that CPAN/CPANPLUS shell is used.\E$}
			    ) {
			$add_analysis_tag->('possibly old bundled modules');
		    } elsif (
			     /^\s*#\s+Failed test '.*'$/ ||
			     /^\s*#\s+Failed test at .* line \d+\.$/ ||
			     /^\s*#\s+Failed test \(.*\)$/ ||
			     /^\s*#\s+Failed test \d+ in .* at line \d+$/
			    ) {
			$add_analysis_tag->('__GENERIC_TEST_FAILURE__'); # lower prio than other failures, special handling needed
		    } elsif (
			     /\S+ uses NEXT, which is deprecated. Please see the Class::C3::Adopt::NEXT documentation for details. NEXT used\s+$at_source_qr/
			    ) {
			$add_analysis_tag->('deprecation (NEXT)');
		    } elsif (
			     /Class::MOP::load_class is deprecated/
			    ) {
			$add_analysis_tag->('deprecation (Class::MOP)');
		    } elsif (
			     /Passing a list of values to enum is deprecated. Enum values should be wrapped in an arrayref. $at_source_qr/
			    ) {
			$add_analysis_tag->('deprecation (Moose)');
		    } elsif (
			     /DBD::SQLite::st execute failed: database is locked/ ||
			     /DBD::SQLite::db do failed: database is locked \[for Statement "/
			    ) {
			$add_analysis_tag->('locking issue (File::Temp?)');
		    } elsif (
			     /Perl lib version \(.*?\) doesn't match executable '.*?' version (.*?) $at_source_qr/
			    ) {
			$add_analysis_tag->('perl version mismatch (lib)');
		    } elsif (
			     /Can't connect to \S+ \((Invalid argument|Bad hostname)\) $at_source_qr/
			    ) {
			$add_analysis_tag->('remote connection problem');
		    } elsif (
			     /^Files=\d+, Tests=\d+, (\d+) wallclock secs /
			    ) {
			if ($1 >= 1800) {
			    $add_analysis_tag->('very long runtime (>= 30 min)');
			} elsif ($1 >= 900) {
			    $add_analysis_tag->('long runtime (>= 15 min)');
			}
		    } elsif (
			     /Unrecognized character .* at \._\S+ line \d+\./
			    ) {
			$add_analysis_tag->('hidden MacOSX file');
		    } elsif (
			     m{^Unknown regexp modifier "/[^"]+" at }
			    ) {
			$add_analysis_tag->('unknown regexp modifier');
		    } elsif (
			     m{^make: \*\*\* No targets specified and no makefile found\.  Stop\.$}
			    ) {
			$add_analysis_tag->('makefile missing'); # probably due to Makefile.PL and Build.PL missing before
		    } elsif (
			     m{^String found where operator expected at \S+ line \d+, near "Carp::croak }
			    ) {
			$add_analysis_tag->('possibly missing use Carp');
		    } else {
			# collect PROGRAM OUTPUT string (maybe)
			if (!$program_output->{skip_collector}) {
			    if (/^-*$/) {
				# skip newlines and dashes
			    } elsif (/^Output\s+from\s+'.*(?:make|Build)\s+test':/) {
				# skip
			    } elsif (defined $program_output->{content}) {
				# collect just one line
				$program_output->{skip_collector} = 1;
			    } else {
				$program_output->{content} .= $_;
				$program_output->{line} = $. if !defined $program_output->{line};
			    }
			}
		    }
		} elsif ($section eq 'PREREQUISITES') {
		    if (/^\s*!\s*perl\s*([\d\.]+)\s+([\d\.]+)\s*$/) {
			my($perl_need, $perl_have) = ($1, $2);
			if ($perl_need > $perl_have) {
			    $add_analysis_tag->('low perl');
			}
		    }
		}
	    }
	}

	my $title = "ctr_good_or_invalid:";
	if ($subject) {
	    $title =  " " . $subject;
	    if ($x_test_reporter_perl) {
		$title .= " (perl " . $x_test_reporter_perl . ")";
	    }
	    my $mw = $more->toplevel;
	} else {
	    $title = " (subject not parseable)";
	}
	$mw->title($title);

	$modtime = scalar localtime ((stat($currfile))[9]);
    } else {
	warn "Can't open $currfile: $!";
	$modtime = "N/A";
    }

    my %recent_states;
    if ($show_recent_states) {
	%recent_states = get_recent_states();
    }

    # Create the "analysis tags"
    $_->destroy for $analysis_frame->children;
    my $generic_analysis_tag_value = delete $analysis_tags{__GENERIC_TEST_FAILURE__};
    if (!%analysis_tags && $generic_analysis_tag_value) { # show generic test fails only if there's nothing else
	$generic_analysis_tag_value->{__bgcolor__} = 'white'; # different color than the other analysis tags
	$analysis_tags{'generic test failure'} = $generic_analysis_tag_value;
    }
    for my $analysis_tag (sort keys %analysis_tags) {
	my $line = $analysis_tags{$analysis_tag}->{line};
	my $bgcolor = $analysis_tags{$analysis_tag}->{__bgcolor__} || 'yellow';
	$analysis_frame->Button(-text => $analysis_tag,
				@common_analysis_button_config,
				-bg => $bgcolor,
				-command => sub {
				    $more->Subwidget('scrolled')->see("$line.0");
				},
			       )->pack;
    }

    # Highlight the lines in the text which caused the analysis
    # process to match
    {
	my $textw = $more->Subwidget("scrolled");
	$textw->tagConfigure('analysis_highlight', -background => '#eeeeee');
	while(my($analysis_tag, $info) = each %analysis_tags) {
	    my $line = $info->{line};
	    $textw->tagAdd('analysis_highlight', "$line.0", "$line.end");
	}
    }

    # Create the tags with the recent states for this distribution.
    for my $recent_state (sort keys %recent_states) {
	my $count = scalar @{ $recent_states{$recent_state} };
	my $color = (
		     $recent_state eq 'pass' ? 'green' :
		     $recent_state eq 'fail' ? 'red'   : 'orange'
		    );
	my $sample_recent_file = $recent_states{$recent_state}->[0];
	my $b = $analysis_frame->Button(-text => "$recent_state: $count",
					@common_analysis_button_config,
					-bg => $color,
					-command => sub {
					    my $t = $more->Toplevel(-title => $sample_recent_file);
					    my $more = $t->Scrolled('More')->pack(qw(-fill both -expand 1));
					    $more->Load($sample_recent_file);
					    $more->Subwidget('scrolled')->Subwidget('text')->configure(-background => '#f0f0c0'); # XXX really so complicated?
					    $t->Button(-text => 'Close', -command => sub { $t->destroy })->pack(-fill => 'x');
					},
				       )->pack;
	my @balloon_msg;
	for my $f (@{ $recent_states{$recent_state} }) {
	    if (open my $fh, $f) {
		my $subject;
		my $x_test_reporter_perl;
		while(<$fh>) {
		    chomp;
		    if (m{^X-Test-Reporter-Perl: (.*)}) {
			$x_test_reporter_perl = $1;
		    } elsif (m{^Subject: (.*)}) {
			$subject = $1;
		    } elsif (m{^$}) {
			warn "WARN: cannot find X-Test-Reporter-Perl header in $f";
			last;
		    }
		    if ($x_test_reporter_perl && $subject) {
			push @balloon_msg, "perl $x_test_reporter_perl $subject";
			last;
		    }
		}
	    } else {
		warn "WARN: cannot open $f: $!";
	    }
	}
	if (eval { require Sort::Naturally; 1 }) {
	    @balloon_msg = Sort::Naturally::nsort(@balloon_msg);
	} else {
	    @balloon_msg = sort @balloon_msg;
	}
	$balloon->attach($b, -msg => join("\n", @balloon_msg));
    }

    ($currdist, $currversion) = $currfulldist =~ m{^(.*)-(.*)$};
}

sub get_recent_states {
    my %recent_states;

    if (@recent_done_directories) {
	my $res = parse_report_filename($currfile);
	if (!$res) {
	    warn "WARN: cannot parse $currfile";
	} else {
	    my $distv = $res->{distv};
	    my @recent_reports;
	    for my $recent_done_directory (@recent_done_directories) {
		if (opendir(my $DIR, $recent_done_directory)) {
		    while(defined(my $file = readdir $DIR)) {
			if (index($file, $distv) >= 0) { # quick check
			    if (my $recent_res = parse_report_filename($file)) {
				if ($recent_res->{distv} eq $distv) {
				    my $recent_state = $recent_res->{state};
				    push @{ $recent_states{$recent_state} }, "$recent_done_directory/$file";
				}
			    }
			}
		    }
		} else {
		    warn "ERROR: cannot open $recent_done_directory: $!";
		}
	    }
	}
    }

    %recent_states;
}

sub nextfile {
    if ($currfile_i < $#files) {
	$currfile_i++;
	set_currfile();
    } else {
	$mw->destroy if $quit_at_end;
	if ($mw->messageBox(-icon => "question",
			    -title => "End of list",
			    -message => "No more files. Quit?",
			    -type => "YesNo",
			   ) eq 'Yes') {
	    $mw->destroy;
	} else {
	    warn "Continuing?";
	}
    }
}

sub is_user_at_computer {
    my $ret = eval {
	require X11::Protocol;
	my $X = X11::Protocol->new;
	$X->init_extension('MIT-SCREEN-SAVER')
	    or die "MIT-SCREEN-SAVER extension not available or CPAN module X11::Protocol::Ext::MIT_SCREEN_SAVER not installed";
	my($on_or_off) = $X->MitScreenSaverQueryInfo($X->root);
	$on_or_off eq 'On' ? 0 : 1;
    };
    if ($@) {
	if ($do_check_screensaver) {
	    die $@;
	} else {
	    return 1;
	}
    }
    $ret;
}

sub parse_report_filename {
    my $filename = shift;
    if (my($state, $distv_arch, $epoch, $pid) = $filename =~ m{(?:^|/)($the_ct_states_rx)\.(.*)\.(\d+)\.(\d+)\.rpt$}) {
	my @tokens = split /\./, $distv_arch;
	my $distv = shift @tokens;
	my $arch;
	while(defined(my $token = shift @tokens)) {
	    if ($token =~ m{^\d}) {
		$distv .= ".$token";
	    } else {
		$arch = join(".", $token, @tokens);
		last;
	    }
	}
	my $res =  +{
		     distv => $distv,
		     state => $state,
		     arch  => $arch,
		     epoch => $epoch,
		     pid   => $pid,
		    };
	return $res;
    } else {
	undef;
    }
}

sub check_term_title {
    if (!eval { require XTerm::Conf; 1 }) {
	if (!eval { require Term::Title; 1 }) {
	    warn "No XTerm::Conf and/or Term::Title available, turning -xterm-title off (specify -no-xterm-title to cease this warning)...\n";
	    $do_xterm_title = 0;
	}
    }
}

sub set_term_title {
    return if !$do_xterm_title;
    my $string = shift;
    if (defined &XTerm::Conf::xterm_conf_string) {
	print STDERR XTerm::Conf::xterm_conf_string(-title => $string);
    } else {
	Term::Title::set_titlebar($string);
    }
}

__END__

=head1 NAME

ctr_good_or_invalid.pl - interactively decide if CPAN Tester reports are good

=head1 SYNOPSIS

    ctr_good_or_invalid.pl [options] [reportworkflowdir]

=head1 DESCRIPTION

C<ctr_good_or_invalid.pl> is part of a CPAN Tester workflow where all
FAIL (or all non-PASS) reports are interactively checked before sent
to metabase. This script shows unprocessed test reports in a GUI
window (using L<Tk>), where the report is displayed and the user can
decide whether the report is "good" or "invalid" or "undecided" (and
check this report later). Also part of the GUI window is a number of
links to helpful tools in the CPAN Testers ecosystem
(L<http://matrix.cpantesters.org>, L<http://rt.cpan.org>, a solver
based on L<CPAN::Testers::ParseReport>).

=head2 OPTIONS

=over

=item C<-noxterm-title>

By default, the current status (number of reports) is displayed in the
xterm title. This requires L<XTerm::Conf>. Set this option to turn
this feature off.

=item C<-only-pass-is-good>

By default, only FAIL reports are checked interactively and everything
else is moved automatically to the C<sync> directory. Using this
switch also NA and UNKNOWN reports are checked interactively.


=head2 RELATED SCRIPTS

The other scripts in the workflow system are:

=over

=item * C<L<cpan_smoke_modules_wrapper3>> - a wrapper to call
L<cpan_smoke_modules> for a number of perl installations

=item * C<L<cpan_smoke_modules>> - a wrapper around L<CPAN.pm|CPAN>
and L<CPAN::Reporter>, capable of smoke testing recent modules or a
given list of modules

=item * C<ctr_good_or_invalid.pl> - this script, an interactive
checker for the validness of reports

=item * C<L<send_tr_reports.pl>> - a wrapper around L<Test::Reporter>
to send valid reports to metabase

=back

=head2 DIRECTORY STRUCTURE

Part of the workflow is a directory structure which reflects the
phases of the workflow. The default root directory for the workflow is
C<~/var/cpansmoker>, but may be changed by the individual scripts. The
subdirectories here are:

=over

=item * C<new> - here C<L<cpan_smoke_modules>> (or a manually
configured CPAN shell) writes new test reports

=item * C<sync> - reports marked by C<ctr_good_or_invalid.pl> as
"good" are moved to this directory for later processing

=item * C<invalid> - reports marked by C<ctr_good_or_invalid.pl> as
"invalid" are moved to this directory and will stay here

=item * C<undecided> - reports marked by C<ctr_good_or_invalid.pl> as
"undecided" are moved to this directory and will stay here; a user
should check these reports later manually and then move them to either
C<sync> or C<invalid>

=item * C<process> - C<send_tr_reports.pl> moves reports which are
about to be sent to metabase into this directory; in case of metabase
problems the report will be left here

=item * C<done> - after successfully sending to metabase the reports
will be archived into this directory; this directory is organized in
monthly subdirectories I<YYYY-MM>. =back

=back

=head1 EXAMPLES

Following needs the scripts C<forever> (unreleased, otherwise use a
shell C<while> loop), C<ctr_good_or_invalid.pl> (this script), and
C<L<send_tr_reports.pl>>. Note that the perl executable is hardcoded
here:

    forever -countdown -181 -pulse 'echo "*** WORK ***"; sleep 1; ./ctr_good_or_invalid.pl -auto-good -xterm-title ~cpansand/var/cpansmoker; ./send_tr_reports.pl ~cpansand/var/cpansmoker/; echo "*** DONE ***"'

The script's defaults may be quite demanding. If you don't have
C<X11::Protocol::Ext::MIT_SCREEN_SAVER> installed, and the
F<cpansmoker> is on an expensive file system (e.g. a remote mount),
then consider to set the C<-noauto-good> and C<-norecent-states> switches:

    ctr_good_or_invalid.pl -noauto-good -norecent-states ~/var/cpansmoker

=head1 AUTHOR

Slaven Rezic C<srezic AT cpan DOT org>

=head1 SEE ALSO

L<cpan_smoke_modules_wrapper3>, L<cpan_smoke_modules>,
L<send_tr_reports.pl>, L<Test::Reporter>, L<CPAN>,
L<CPAN::Testers::ParseReport>.

=cut
