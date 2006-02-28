#!/usr/bin/perl -w
# -*- Mode: perl; coding: raw-text -*-

use XML::LibXML;
use Devel::Peek;

$p = XML::LibXML->new;

$xml_utf8 = <<EOF;
<?xml version="1.0" encoding="utf-8"?>
<test>√§√∂√º√Ñ√ñ√ú√ü</test>
EOF

$xml_iso_8859_1 = <<EOF;
<?xml version="1.0" encoding="iso-8859-1"?>
<test>‰ˆ¸ƒ÷‹ﬂ</test>
EOF

for $xml ($xml_utf8, $xml_iso_8859_1) {
    $doc = $p->parse_string($xml);
    $root = $doc->documentElement;
    $value = $root->findvalue("/test");
    Dump $value;
}

__END__
SV = PVMG(0x8208fa8) at 0x817f66c
  REFCNT = 1
  FLAGS = (POK,pPOK,UTF8)
  IV = 0
  NV = 0
  PV = 0x8275780 "\303\244\303\266\303\274\303\204\303\226\303\234\303\237"\0 [UTF8 "\x{e4}\x{f6}\x{fc}\x{c4}\x{d6}\x{dc}\x{df}"]
  CUR = 14
  LEN = 15
SV = PVMG(0x8208fa8) at 0x817f66c
  REFCNT = 1
  FLAGS = (POK,pPOK,UTF8)
  IV = 0
  NV = 0
  PV = 0x8275640 "\303\244\303\266\303\274\303\204\303\226\303\234\303\237"\0 [UTF8 "\x{e4}\x{f6}\x{fc}\x{c4}\x{d6}\x{dc}\x{df}"]
  CUR = 14
  LEN = 15
