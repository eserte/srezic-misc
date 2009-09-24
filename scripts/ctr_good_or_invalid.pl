#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: ctr_good_or_invalid.pl,v 1.2 2009/09/24 20:53:14 eserte Exp $
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

my @files = @ARGV;
die "No files given" if !@files;

my $good_directory = "$ENV{HOME}/var/ctr/sync";
die "No $good_directory" if !-d $good_directory;
my $invalid_directory = "$ENV{HOME}/var/ctr/invalid";
die "No $invalid_directory" if !-d $invalid_directory;

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

my $mw = tkinit;

my $currfile_i = 0;
my $currfile;

my $more = $mw->Scrolled("More")->pack(-fill => "both", -expand => 1);
{
    my $f = $mw->Frame->pack(-fill => "x");
    $f->Button(-text => "Prev",
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
       
    $f->Button(-text => "Next",
	       -command => sub { nextfile() },
	      )->pack(-side => "left");

}

set_currfile();

MainLoop;

sub set_currfile {
    $currfile = $files[$currfile_i];
    $more->Load($currfile);
}

sub nextfile {
    if ($currfile_i < $#files) {
	$currfile_i++;
	set_currfile();
    } else {
	die "No more files!";
    }
}

__END__
