#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: loadandsave.pl,v 1.1 2005/08/10 22:59:43 eserte Exp $
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
use Tk::ColorEditor;

$tmpdir = $ENV{TMPDIR} || $ENV{TEMP} || "/tmp";
if (! -d $tmpdir) {
    $tmpdir = "/temp";
    if (! -d $tmpdir) {
        die "Np temporary directory found";
    }
}
$rcfile = "$tmpdir/loadandsave.rc";

$top = new MainWindow;

loaddef();

$top->Label(-text => "Option DB")->pack;
$top->Button(-text => "Call color editor",
	     -command => \&coledit)->pack;
$top->Button(-text => "Load old definition",
	     -command => \&loaddef)->pack;
$top->Button(-text => "Save current definition",
	     -command => \&savedef)->pack;

MainLoop;

sub loaddef {
    if (-f $rcfile) {
	$top->optionReadfile($rcfile, "interactive");
    }
}

sub savedef {
    my $s = saverecurse($top);
    open(F, ">$rcfile") or die "Can't write to $rcfile: $!";
    print F $s;
    close F;
}

sub saverecurse {
    my $w = shift;
    my $s = "";
    eval {
	my $pathname = $w->PathName;
	$pathname =~ s/\./*/g;
	if ($pathname eq '*') { $pathname = '' }
	$s .= $pathname . "*foreground:\t" . $w->cget(-foreground) . "\n";
	$s .= $pathname . "*background:\t" . $w->cget(-background) . "\n";
    };
    warn $@ if $@;
    foreach ($w->children) {
	$s .= saverecurse($_);
    }
    $s;
}

sub coledit {
    $top->ColorEditor->Show;
}

__END__
