#
# $Id: Makefile,v 1.2 2006/02/27 23:14:40 eserte Exp $
#

#SPIP_DIR=/usr/local/src/spip_1.5
SPIP_DIR=/usr/local/src/new.spip_1.5
SPIP_BIN=$(SPIP_DIR)/spip/bin/spip.pl
#PERL=perl
PERL=perl5.8.8

all:	spip-convert scherz

spip-convert:
	$(PERL) $(SPIP_BIN)

scherz:
	mv html/output_0001_01.html html/output_0001_01.html~
	piconv -f iso-8859-1 -t utf-8 html/output_0001_01.html~ > html/output_0001_01.html
	mv html/output_0002_01.html html/output_0002_01.html~
	piconv -f utf-8 -t iso-8859-1 html/output_0002_01.html~ > html/output_0002_01.html
