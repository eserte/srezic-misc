#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: imagetext.pl,v 1.1 2005/08/10 22:59:42 eserte Exp $
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

$top = new MainWindow;

$hlist = $top->Scrolled("HList",
			-columns => 1,
			-scrollbars => 'osoe',
		       )->pack(-expand => 1, -fill => 'both');

my $folderimage = $top->Getimage("folder");
my $fileimage   = $top->Getimage("file");
my $srcimage    = $top->Getimage("srcfile");
my $textimage   = $top->Getimage("textfile");

foreach (glob(".* *")) {
    my $image;
    if (-d $_) {
	$image = $folderimage;
    } elsif (-f $_) {
	if (/\.(c|cpp|cc)$/) {
	    $image = $srcimage;
	} elsif (/\.te?xt$/) {
	    $image = $textimage;
	} else {
	    $image = $fileimage;
	}
    }
    $hlist->add(++$i,
		-itemtype => "imagetext",
		-text => $_,
		(defined $image ? (-image => $image) : ()),
	       );
}

MainLoop;

__END__
