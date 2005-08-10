#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: dirlist.pl,v 1.1 2005/08/10 22:59:41 eserte Exp $
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
use Tk::Dirlist;

$top = new MainWindow;

$dl = $top->Scrolled
    ('Dirlist',

     # Show the contents of this directory.
     -directory => "/usr/bin",

     # If the user clicks once on a directory, open it.
     -browsecmd => sub {
	 my $f = shift;
	 if (-d $f) {
	     $dl->configure(-directory => $f);
	 }
     },

     # If the user double-clicks on a directory or file entry,
     # record the filename and cause waitVariable to continue.
     -command => sub {
	 $file = shift;
     });
$dl->pack(-fill => "both", -expand => 1);

# wait until a file is selected
$dl->waitVariable(\$file);

print STDERR "The result is: $file\n";

__END__
