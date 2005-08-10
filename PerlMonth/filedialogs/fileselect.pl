#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: fileselect.pl,v 1.1 2005/08/10 22:59:41 eserte Exp $
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

# maybe in 800.019:
#$Tk::FileSelect::error_text{'-T'} = "ist keine Textdatei";

$fs = $top->FileSelect
    (-directory        => Cwd::cwd(), # Alias: -initialdir
     -initialfile      => "fileselect.pl",
     -filter           => "*.pl",
     #-regexp           => '.*\.pl$', #' does not work (?)

     -filelabel        => "Datei",
     -filelistlabel    => "Dateien",
     -dirlabel         => "Verzeichnis",
     -dirlistlabel     => "Verzeichnisse",

     -verify           => ['-T'], # accept only text files

     # not yet, but maybe in Tk 800.019?
     #-acceptlabel      => "Übernehmen",
     #-cancellabel      => "Abbrechen",
     #-resetlabel       => "Zurücksetzen",
     #-homelabel        => "Heimatverzeichnis",

    );
print $fs->Show;
print "\n";

__END__
