#
# $Id: Makefile,v 1.1 2005/08/10 22:59:42 eserte Exp $
#

all:

dist:
	cd ..; tar cfvz /tmp/perltkmenus.tar.gz \
		menus/menu.gif \
		menus/newstyle.pl \
		menus/oldstyle.pl \
		menus/perlstyle.pl \
		menus/perltk_menus.html \
		menus/popup.pl \
		menus/popupmenu.gif

test:
	perl -e 'for $$exe ("perl", "perl5.00502") { for $$pl (glob("*.pl")) { print "$$exe $$pl\n"; system($$exe, $$pl); } }'
