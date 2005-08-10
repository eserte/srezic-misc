#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: ditem.pl,v 1.1 2005/08/10 22:59:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use Tk 800;
use Tk::HList;
use Tk::ItemStyle;

$top = new MainWindow;

$hlist = $top->Scrolled("HList",
			-columns => 2,
			-scrollbars => 'osoe',
			-width => 40,
		       )->pack(-expand => 1, -fill => 'both');

$is1 = $hlist->ItemStyle("text", -foreground => "red", -background => "blue");
$is2 = $hlist->ItemStyle("text", -foreground => "blue", -background => "red",
			 -font => "Helvetica 18"
			);
$is3 = $hlist->ItemStyle("text", -foreground => "black",
			 -background => "#ffdead");

$hlist->add(++$i,
	    -style => $is1,
	    -text => "red foreground",
	   );
$hlist->itemCreate
  ($i, 1,
   -style => $is3,
   -text => "something",
  );
$hlist->add(++$i,
	    -style => $is2,
	    -text => "blue foreground",
	   );
$hlist->itemCreate
  ($i, 1,
   -itemtype => "imagetext",
   -text => "image and text",
   -image => $hlist->Pixmap(-file => Tk->findINC("folder.xpm")),
  );
$hlist->add(++$i,
	    -itemtype => "window",
	    -window => $hlist->Button(-text => "Click me"),
	   );
$hlist->add(++$i, 
	    -itemtype => "text",
	    -style => $is2,
	    -text => "a default image",
	   );

MainLoop;

__END__
