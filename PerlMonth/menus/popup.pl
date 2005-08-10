#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: popup.pl,v 1.1 2005/08/10 22:59:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use Tk;

$top = new MainWindow;

$l = $top->Label(-text => "Press right button\nfor popup menu.")->pack;
$m = $top->Menu(-tearoff => 0,
		-menuitems =>
    [
     [Button => "Cut",   -command => \&cut],
     [Button => "Copy",  -command => \&copy],
     [Button => "Paste", -command => \&paste],
    ]
   );
$top->bind("<Button-3>" => sub { $m->Popup(-popover => "cursor",
					   -popanchor => 'nw') });

MainLoop;

__END__
