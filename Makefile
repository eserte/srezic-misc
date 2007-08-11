#
# $Id: Makefile,v 1.1 2007/08/11 09:39:19 eserte Exp $
#

all: cpan_in_a_nutshell.html

cpan_in_a_nutshell.html: cpan_in_a_nutshell.pod Makefile
	perl -e 'package MyPH; \
	    use base Pod::Simple::HTML; \
	    sub html_header_after_title { \
		my $$self = shift; \
		if (@_) { \
		    $$self->SUPER::html_header_after_title(@_); \
		} else { \
		    $$self->SUPER::html_header_after_title . "\n<h1>CPAN in a nutshell</h1>"; \
		} \
	    } \
	    sub html_footer { \
		my $$self = shift; \
		if (@_) { \
		    $$self->SUPER::html_footer(@_); \
		} else { \
		     "\n<h1>Author</h1>Slaven Rezi&#x107;" . $$self->SUPER::html_footer; \
		} \
	    } \
	    sub force_title { "CPAN in a nutshell" } \
	    sub index {1} \
	    sub html_css { "http://search.cpan.org/s/style.css" } \
	    MyPH->parse_from_file(@ARGV)' \
		cpan_in_a_nutshell.pod cpan_in_a_nutshell.html
