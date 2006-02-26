#!/usr/bin/perl -w
# -*- perl -*-

use strict;
use charnames qw(:full);
use HTML::Template;

use FindBin;
my $ht = HTML::Template->new(filename => "sample.ht");
#binmode STDOUT, ":utf8";
#binmode STDOUT, ":encoding(iso-8859-1)";
binmode STDOUT, ":encoding(iso-8859-2)";
$ht->param(name => "Slaven Rezi\N{LATIN SMALL LETTER C WITH ACUTE}");
my $res = $ht->output;
print $res, "\n";

__END__
