#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: perlstyle.pl,v 1.1 2005/08/10 22:59:42 eserte Exp $
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

create_gui();

sub create_gui {

    my $menuitems = 
    [

     [Cascade => "~File", -menuitems =>
      [
       [Button => "~New", -command => \&new],
       [Separator => ""],
       [Button => "~Open", -command => \&open],
       [Button => "~Save", -command => \&open],
       [Button => "~Save As", -command => \&open],
       [Cascade => "~Export", -menuitems =>
	[
	 [Button => "~GIF", -command => sub { export("gif")}],
	 [Button => "~JPG", -command => sub { export("jpg")}],
	 [Button => "~BMP", -command => sub { export("bmp")}],
	]
       ], 
       [Separator => ""],
       [Button => "~Print", -command => \&printcmd],
       [Button => "~Quit", -command => \&quitapp],
      ]
     ],

     [Cascade => "~Edit", -menuitems =>
      [
       [Button => "~Copy", -command => \&copy],
       [Button => "C~ut", -command => \&cut],
       [Button => "~Paste", -command => \&paste],
      ]
     ],

     [Cascade => "~Help", -menuitems =>
      [
       [Button => "~Index", -command => \&helpindex],
       [Button => "~About", -command => \&about],
      ]
     ],
    ];

    if ($Tk::VERSION >= 800) {
	$menubar = $top->Menu(-menuitems => $menuitems);
	$top->configure(-menu => $menubar);
    } else {
	$top->Menubutton(-text => "Pseudo menubar",
			 -menuitems => $menuitems)->pack;
    }
}

MainLoop;

__END__
