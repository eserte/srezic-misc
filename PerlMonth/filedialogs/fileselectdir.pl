#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: fileselectdir.pl,v 1.1 2005/08/10 22:59:41 eserte Exp $
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
use Tk::FileSelect;
use Cwd;

$top = new MainWindow;

$fs = $top->FileSelect(-verify => [qw/-d/]);
print $fs->Show;
print "\n";

__END__
