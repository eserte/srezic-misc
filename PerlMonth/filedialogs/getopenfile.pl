#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: getopenfile.pl,v 1.1 2005/08/10 22:59:41 eserte Exp $
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
use Cwd;

$top = new MainWindow;

print
    "Filename: ",
    $top->getOpenFile(-defaultextension => ".pl",
		      -filetypes        =>
		      [['Perl Scripts',     '.pl'            ],
		       ['Text Files',       ['.txt', '.text']],
		       ['C Source Files',   '.c',      'TEXT'],
		       ['GIF Files',        '.gif',          ],
		       ['GIF Files',        '',        'GIFF'],
		       ['All Files',        '*',             ],
		      ],
		      -initialdir       => Cwd::cwd(),
		      -initialfile      => "getopenfile",
		      -title            => "Your customized title",
		     ),
    "\n";

__END__
