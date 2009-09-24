#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: ctr_good_or_invalid.pl,v 1.8 2009/09/24 20:53:33 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
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

my $reportdir = shift || "$ENV{HOME}/var/ctr";

my @files = @ARGV;
if (@files == 1 && -d $files[0]) {
    $reportdir = $files[0];
    @files = ();
}
if (!@files) {
    @files = glob("$reportdir/new/*.rpt");
}
die "No files given or found.\n" if !@files;

my $good_directory = "$reportdir/sync";
if (!-d $good_directory) {
    mkdir $good_directory or die "While creating $good_directory: $!";
}
my $invalid_directory = "$reportdir/invalid";
if (!-d $invalid_directory) {
    mkdir $invalid_directory or die "While creating $invalid_directory: $!";
}

my @new_files;
# pass, na, unknown are always good:
for my $file (@files) {
    if ($file =~ m{/(pass|unknown|na)\.}) {
	move $file, $good_directory
	    or die "Cannot move $file to $good_directory: $!";
    } else {
	push @new_files, $file;
    }
}
@files = @new_files;
if (!@files) {
    warn "No file needs to be checked manually, finishing.";
    exit;
}

my $mw = tkinit;

my $currfile_i = 0;
my $currfile;
my($currdist, $currversion);

my $prev_b;
my $next_b;
my $more = $mw->Scrolled("More")->pack(-fill => "both", -expand => 1);
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
    $f->Button(-text => "GOOD",
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
		   Tk::Pod::WWWBrowser::start_browser("http://bbbike.radzeit.de/~slaven/cpantestersmatrix.cgi?" . CGI->new({dist=>$currdist, reports=>"1"})->query_string);
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
$mw->bind("<F4>" => sub { $prev_b->invoke });
$mw->bind("<F5>" => sub { $prev_b->invoke });

#$mw->FullScreen; # does not work (with fvwm2 only?)
MainLoop;

sub set_currfile {
    $currfile = $files[$currfile_i];
    $more->Load($currfile);
    my $currfulldist;
    if (open my $fh, $currfile) {
	while(<$fh>) {
	    if (/^Subject:\s*(.*)/) {
		my $subject = $1;
		my $mw = $more->toplevel;
		$mw->title("ctr_good_or_invalid: $subject");
		if (/^Subject:\s*(?:FAIL|PASS|UNKNOWN|NA) (\S+)/) {
		    $currfulldist = $1;
		} else {
		    warn "Cannot parse distribution out of '$subject'";
		}
		last;
	    }
	}
    } else {
	warn "Can't open $currfile: $!";
    }
    ($currdist, $currversion) = $currfulldist =~ m{^(.*)-(.*)$};
}

sub nextfile {
    if ($currfile_i < $#files) {
	$currfile_i++;
	set_currfile();
    } else {
	if ($mw->messageBox(-icon => "question",
			    -title => "End of list",
			    -message => "No more files. Quit?",
			    -type => "YesNo",
			   ) eq 'Yes') {
	    exit;
	} else {
	    warn "Continuing?";
	}
    }
}

__END__
