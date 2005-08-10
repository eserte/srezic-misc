#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: fbox.pl,v 1.1 2005/08/10 22:59:41 eserte Exp $
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
use Tk::FBox;

$top = new MainWindow;

my $fbox = $top->FBox(-title => "FBox demonstration");
my $file = $fbox->Show;
if (!defined $file || $file eq '') {
    $top->messageBox(-message => "No file chosen",
		     -type    => "OK");
} else {
    $top->messageBox(-message => "You hav chosen the file: $file",
		     -type    => "OK");
}

__END__
