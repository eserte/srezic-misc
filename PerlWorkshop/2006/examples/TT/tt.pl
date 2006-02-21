#!/usr/bin/perl -w
# -*- perl -*-

use strict;
use charnames qw(:full);
use Template::Provider::Encoding;
use Template::Stash::ForceUTF8;
use Template;

use FindBin;
my $tt = Template->new(
		       LOAD_TEMPLATES => [ Template::Provider::Encoding->new ],
		       STASH => Template::Stash::ForceUTF8->new,
		      );
binmode STDOUT, ":utf8";
#binmode STDOUT, ":encoding(iso-8859-1)";
my $res;
$tt->process(
	     "sample.tt",
	     { name => "Slaven Rezi\N{LATIN SMALL LETTER C WITH ACUTE}" },
	     \$res
	    )
    or die $tt->error;
print $res, "\n";

__END__
