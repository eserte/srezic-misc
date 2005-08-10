#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: basic.pl,v 1.1 2005/08/10 22:59:42 eserte Exp $
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
use Tk::HList;

$top = new MainWindow;
$hlist = $top->HList->pack;
foreach (@INC) {
    $hlist->add(++$i, -text => $_);
}
MainLoop;

__END__
