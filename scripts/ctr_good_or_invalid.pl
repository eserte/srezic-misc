#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008-2010,2012,2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use File::Copy qw(move);
use Tk;
use Tk::More;
use Tk::ErrorDialog;
use Getopt::Long;

my $only_good;
my $auto_good;
my $only_pass_is_good;
my $sort_by_date;
my $reversed;
my $geometry;
my $quit_at_end = 1;
my $do_xterm_title;
GetOptions("good" => \$only_good,
	   "auto-good" => \$auto_good,
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
	  )
    or die "usage: $0 [-good] [-sort date] [-r] [-geometry x11geom] [-noquit-at-end] [-xterm-title] [directory [file ...]]";

my $reportdir = shift || "$ENV{HOME}/var/ctr";

if ($auto_good) {
    # just to check if X11::Protocol etc. is available
    is_user_at_computer();
}

if ($do_xterm_title) {
    if (!eval { require XTerm::Conf; 1 }) {
	warn "No XTerm::Conf available, turning -xterm-title off...\n";
	$do_xterm_title = 0;
    }
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
    if ($do_xterm_title) {
	print STDERR XTerm::Conf::xterm_conf_string(-title => "report sender: $msg");
    }
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
    if ($do_xterm_title) {
	print STDERR XTerm::Conf::xterm_conf_string(-title => "report sender: $msg");
    }
    exit;
}
if ($auto_good) {
    if (!is_user_at_computer()) {
	my $msg = scalar(@files) . " distribution(s) with FAILs (inactive user)";
	warn "Skipping $msg.\n";
	if ($do_xterm_title) {
	    print STDERR XTerm::Conf::xterm_conf_string(-title => "report sender: $msg");
	}
	exit 1;
    }
} elsif ($only_good) {
    my $msg = scalar(@files) . " distribution(s) with FAILs";
    warn "Skipping $msg.\n";
    if ($do_xterm_title) {
	print STDERR XTerm::Conf::xterm_conf_string(-title => "report sender: $msg");
    }
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

if ($do_xterm_title) {
    print STDERR XTerm::Conf::xterm_conf_string(-title => "report sender: interactive mode");
}

my $mw = tkinit;
$mw->geometry($geometry) if $geometry;

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
$mw->bind("<F5>" => sub { $prev_b->invoke });

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

if ($do_xterm_title) {
    print STDERR XTerm::Conf::xterm_conf_string(-title => "report sender: finished");
}

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
	    while(<$fh>) {
		if (/^PROGRAM OUTPUT$/) {
		    $section = 'PROGRAM OUTPUT';
		} elsif (/^PREREQUISITES$/) {
		    $section = 'PREREQUISITES';
		} elsif ($section eq 'PROGRAM OUTPUT') {
		    if      (/^Warning: Perl version \S+ or higher required\. We run \S+\.$/) {
			$analysis_tags{'low perl'} = 1;
		    } elsif (/^Result: NOTESTS$/) {
			$analysis_tags{'notests'} = 1;
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

    $_->destroy for $analysis_frame->children;
    for my $analysis_tag (sort keys %analysis_tags) {
	$analysis_frame->Label(-text => $analysis_tag,
			       -bg => 'yellow',
			       -borderwidth => 1,
			       -relief => 'raised'
			      )->pack;
    }

    ($currdist, $currversion) = $currfulldist =~ m{^(.*)-(.*)$};
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
    require X11::Protocol;
    my $X = X11::Protocol->new;
    $X->init_extension('MIT-SCREEN-SAVER')
	or die "MIT-SCREEN-SAVER extension not available or CPAN module X11::Protocol::Ext::MIT_SCREEN_SAVER not installed";
    my($on_or_off) = $X->MitScreenSaverQueryInfo($X->root);
    $on_or_off eq 'On' ? 0 : 1;
}

__END__

=head1 EXAMPLES

Following needs forever (unreleased), ctr_good_or_invalid.pl (this
file), send_tr_reports.pl (available at same place like
ctr_good_or_invalid.pl). Note that the perl executable is hardcoded
here:

    forever -countdown -181 -pulse 'echo "*** WORK ***";sleep 1;perl5.12.4 -S ctr_good_or_invalid.pl -auto-good -xterm-title ~cpansand/var/cpansmoker; perl5.12.4 -S send_tr_reports.pl ~cpansand/var/cpansmoker/; echo "*** DONE ***"'

=cut
