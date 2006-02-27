#!/usr/bin/perl -w
# -*- perl -*-

use strict;
use charnames qw(:full);
use Template;

use FindBin;
my $tt = Template->new(
		       ABSOLUTE => 1,
		       EVAL_PERL => 1,
		       #COMPILE_DIR => "/tmp",
		       #COMPILE_EXT => ".ttc",
		      );
binmode STDOUT, ":utf8";
#binmode STDOUT, ":encoding(iso-8859-1)";
#binmode STDOUT, ":encoding(iso-8859-2)";
my $res;
$tt->process(
	     "$FindBin::RealBin/sample2.tt",
	     { name => "Slaven Rezi\N{LATIN SMALL LETTER C WITH ACUTE}" },
	     \$res
	    )
    or die $tt->error;
print $res, "\n";

__END__
Output:
 
  $ perl tt2.pl|od -c
  0000000    V   i   e   l   e       G   r   Ã   ¼   Ã 237   e   ,       S
  0000020    l   a   v   e   n       R   e   z   i   Ä 207   !  \n  \n    
  0000037
 
Compiled as:

eval { BLOCK: {
    # RAWPERL
    # -*- coding: utf-8 -*-
    use utf8;
    
    $output .=  "Viele GrÃ¼Ã<9F>e, ";
    $output .=  $stash->get('name');
    $output .=  "!\n";
} };
