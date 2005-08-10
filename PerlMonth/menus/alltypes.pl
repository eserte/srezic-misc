#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: alltypes.pl,v 1.1 2005/08/10 22:59:42 eserte Exp $
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
use Tk::Menubar;

$top = new MainWindow;
$top->Checkbutton(-text => "Use menubar",
		  -variable => \$use_menubar)->pack;
$top->Checkbutton(-text => "Use tear-offs",
		  -variable => \$use_tearoffs)->pack;
$top->Button(-text => "Create new GUI",
	     -command => \&create_gui)->pack;

sub create_gui {

    my $top2 = new MainWindow;
    
    $menubar = $top2->Menubar;

    my $file_menu = $menubar->Menubutton(-text => "File", -underline => 0);
    $file_menu->command(-label => "~New",     -command => \&new);
    $file_menu->separator;
    $file_menu->checkbutton(-label => "A checkbutton",
			    -variable => \$cb);
    $file_menu->radiobutton(-label => "Radiobutton A",
			    -value => "A",
			    -variable => \$rb);
    $file_menu->radiobutton(-label => "Radiobutton B",
			    -value => "B",
			    -variable => \$rb);
    my $export_menu = $file_menu->cascade(-label => "~Export");
    $file_menu->separator;
    $file_menu->command(-label => "~Print",   -command => \&printcmd);
    $file_menu->command(-label => "~Quit",    -command => \&quitapp);

    if ($Tk::VERSION < 800) {
	# but this line won't break Tk800
	$export_menu = $export_menu->cget(-menu);
    }
    $export_menu->command(-label => "~GIF", -command => sub { export("gif") });
    $export_menu->command(-label => "~JPG", -command => sub { export("jpg") });
    $export_menu->command(-label => "~BMP", -command => sub { export("bmp") });

    $file_menu->pack(-side => "left");
}

MainLoop;

__END__
