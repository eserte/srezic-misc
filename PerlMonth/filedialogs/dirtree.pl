#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: dirtree.pl,v 1.1 2005/08/10 22:59:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use Tk;
use Tk::DirTree;
use Cwd;

my $top = new MainWindow;
$top->withdraw;

my $t = $top->Toplevel;
$t->title("Choose directory:");
my $ok = 0; # flag: "1" means OK, "-1" means cancelled

# Create Frame widget before the DirTree widget, so it's always visible
# if the window gets resized.
my $f = $t->Frame->pack(-fill => "x", -side => "bottom");

my $curr_dir = Cwd::cwd();

my $d;
$d = $t->Scrolled('DirTree',
		  -scrollbars => 'osoe',
		  -width => 35,
		  -height => 20,
		  -selectmode => 'browse',
		  -exportselection => 1,
		  -browsecmd => sub { $curr_dir = shift },

		  # With this version of -command a double-click will
		  # select the directory
		  -command   => sub { $ok = 1 },

		  # With this version of -command a double-click will
		  # open a directory. Selection is only possible with
		  # the Ok button.
		  #-command   => sub { $d->opencmd($_[0]) },
		 )->pack(-fill => "both", -expand => 1);
# Set the initial directory
$d->chdir($curr_dir);

$f->Button(-text => 'Ok',
	   -command => sub { $ok =  1 })->pack(-side => 'left');
$f->Button(-text => 'Cancel',
	   -command => sub { $ok = -1 })->pack(-side => 'left');

# You probably want to set a grab. See the Tk::FBox source code for
# more information (search for grabCurrent, waitVariable and
# grabRelease).
$f->waitVariable(\$ok);

if ($ok == 1) {
    warn "The resulting directory is: $curr_dir\n";
}

__END__
