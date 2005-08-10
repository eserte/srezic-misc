#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: oldstyle.pl,v 1.1 2005/08/10 22:59:42 eserte Exp $
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

$use_menubar = 1;
$use_tearoffs = 0;

$top = new MainWindow;
$top->Checkbutton(-text => "Use menubar",
		  -variable => \$use_menubar)->pack;
$top->Checkbutton(-text => "Use tear-offs",
		  -variable => \$use_tearoffs)->pack;
$top->Button(-text => "Create new GUI",
	     -command => \&create_gui)->pack;

sub create_gui {

    my $top2 = new MainWindow;
    if (!$use_tearoffs) {
	$top2->optionAdd("*tearOff", "false");
    }
    
    if (!$use_menubar) {
	$menubar = $top2->Frame(-relief => "raised", -borderwidth => 2)->pack;
    } else {
	$menubar = $top2->Menubar;
    }

    my $file_menu = $menubar->Menubutton(-text => "File", -underline => 0);
    $file_menu->command(-label => "~New",     -command => \&new);
    $file_menu->separator;
    $file_menu->command(-label => "~Open",    -command => \&open);
    $file_menu->command(-label => "~Save",    -command => \&save);
    $file_menu->command(-label => "Save ~As", -command => \&saveas);
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

    my $edit_menu = $menubar->Menubutton(-text => "Edit", -underline => 0);
    $edit_menu->command(-label => "~Copy",  -command => \&copy);
    $edit_menu->command(-label => "C~ut",   -command => \&cut);
    $edit_menu->command(-label => "~Paste", -command => \&paste);

    my $help_menu = $menubar->Menubutton(-text => "Help", -underline => 0);
    $help_menu->command(-label => "~Index", -command => \&helpindex);
    $help_menu->command(-label => "~About", -command => \&about);

    if (!$use_menubar) {
	$file_menu->pack(-side => "left");
	$edit_menu->pack(-side => "left");
	$help_menu->pack(-side => "right")
    }
}

MainLoop;

__END__
