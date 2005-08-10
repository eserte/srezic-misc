#
# $Id: Makefile,v 1.1 2005/08/10 22:59:42 eserte Exp $
#

all:

dist:
	cd ..; tar cfvz /tmp/perltkoptiondb.tar.gz \
		optiondb/optiondb.html \
		optiondb/loadandsave.pl

test:
	perl -e 'for $$exe ("perl", "perl5.6.0") { for $$pl (glob("*.pl")) { print "$$exe $$pl\n"; system($$exe, $$pl); } }'
