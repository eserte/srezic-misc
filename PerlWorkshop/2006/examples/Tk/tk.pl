#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: tk.pl,v 1.1 2006/02/21 22:42:07 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use Tk 804;
use Devel::Peek;

$top = new MainWindow;
$e = "הצü";
$top->Entry(-textvariable => \$e)->pack;
$lb = $top->Listbox->pack;
$lb->insert("end", "הצü");
$top->afterIdle(sub {
		    $lb_line = $lb->get(0);
		    Dump $e;
		    Dump $lb_line;
		});
MainLoop;

__END__
Ausgabe:

SV = PVMG(0x83403a4) at 0x811ddfc
  REFCNT = 2
  FLAGS = (GMG,SMG,pPOK,UTF8)
  IV = 0
  NV = 0
  PV = 0x83eeb8c "\303\244\303\266\303\274"\0 [UTF8 "\x{e4}\x{f6}\x{fc}"]
  CUR = 6
  LEN = 7
  MAGIC = 0x83c29e8
    MG_VIRTUAL = &PL_vtbl_uvar
    MG_TYPE = PERL_MAGIC_uvar(U)
    MG_LEN = 12
    MG_PTR = 0x83eeb98 "t\200$(p\201$(\320)<\10"
SV = PV(0x83c9784) at 0x83173ec
  REFCNT = 1
  FLAGS = (POK,pPOK,UTF8)
  PV = 0x83bc478 "\303\244\303\266\303\274"\0 [UTF8 "\x{e4}\x{f6}\x{fc}"]
  CUR = 6
  LEN = 8
