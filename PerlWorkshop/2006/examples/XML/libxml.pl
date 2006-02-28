#!/usr/bin/perl
# -*- Mode: perl; coding: raw-text -*-

use warnings;
use XML::LibXML;
use Devel::Peek;

$p = XML::LibXML->new;

$xml_utf8 = <<EOF;
<?xml version="1.0" encoding="utf-8"?>
<test>√§√∂√º√Ñ√ñ√ú√ü</test>
EOF
# Euro: ‚Ç¨

$xml_iso_8859_1 = <<EOF;
<?xml version="1.0" encoding="iso-8859-1"?>
<test>‰ˆ¸ƒ÷‹ﬂ</test>
EOF

for $xml ($xml_utf8, $xml_iso_8859_1) {
    $doc = $p->parse_string($xml);
    $root = $doc->documentElement;
    $value = $root->findvalue("/test");
    Dump $value;
    #$serialized = $doc->toString;
    #Dump $serialized;
}

__END__
# findvalue
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

# serialized
SV = PV(0x8150944) at 0x81a9768
  REFCNT = 1
  FLAGS = (POK,pPOK,UTF8)
  PV = 0x8254600 "<?xml version=\"1.0\" encoding=\"utf-8\"?>\12<test>\303\244\303\266\303\274\303\204\303\226\303\234\303\237</test>\12"\0 [UTF8 "<?xml version="1.0" encoding="utf-8"?>\n<test>\x{e4}\x{f6}\x{fc}\x{c4}\x{d6}\x{dc}\x{df}</test>\n"]
  CUR = 67
  LEN = 68
SV = PV(0x8150944) at 0x81a9768
  REFCNT = 1
  FLAGS = (POK,pPOK)
  PV = 0x8271100 "<?xml version=\"1.0\" encoding=\"iso-8859-1\"?>\12<test>\344\366\374\304\326\334\337</test>\12"\0
  CUR = 65
  LEN = 66
