#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: newstyle.pl,v 1.1 2005/08/10 22:59:42 eserte Exp $
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

$top = new MainWindow;

create_gui();

sub create_gui {

    $menubar = $top->Menu;
    my $file_menu = $menubar->cascade(-label => "~File");
    my $edit_menu = $menubar->cascade(-label => "~Edit");
    my $help_menu = $menubar->cascade(-label => "~Help");

    $file_menu->command(-label => "~New",     -command => \&new);
    $file_menu->separator;
    $file_menu->command(-label => "~Open",    -command => \&open);
    $file_menu->command(-label => "~Save",    -command => \&save);
    $file_menu->command(-label => "Save ~As", -command => \&saveas);
    my $export_menu = $file_menu->cascade(-label => "~Export");
    $file_menu->separator;
    $file_menu->command(-label => "~Print",   -command => \&printcmd);
    $file_menu->command(-label => "~Quit",    -command => \&quitapp);

    $export_menu->command(-label => "~GIF", -command => sub { export("GIF") });
    $export_menu->command(-label => "~JPG", -command => sub { export("JPG") });
    $export_menu->command(-label => "~BMP", -command => sub { export("BMP") });

    $edit_menu->command(-label => "~Copy",  -command => \&copy);
    $edit_menu->command(-label => "C~ut",   -command => \&cut);
    $edit_menu->command(-label => "~Paste", -command => \&paste);

    $help_menu->command(-label => "~Index", -command => \&helpindex);
    $help_menu->command(-label => "~About", -command => \&about);

    $top->configure(-menu => $menubar);
}

MainLoop;

__END__
