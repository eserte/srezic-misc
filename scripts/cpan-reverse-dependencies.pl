#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2016 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Getopt::Long;
use LWP::UserAgent;

my $recurse;
GetOptions("rec|recurse!" => \$recurse)
    or die "usage?";

my $mod = shift
    or die "Module or distribution?";

my $ua = LWP::UserAgent->new;

if ($recurse) {
    if ($mod =~ m{::}) {
	die "Please specify a distribution with version number, not a module";
    }

    require XML::LibXML;

    my $resp = $ua->get('http://deps.cpantesters.org/depended-on-by.pl?xml=1;dist='.$mod);
    if (!$resp->is_success) {
	die "Fetching failed: " . $resp->as_string;
    }
    my $p = XML::LibXML->load_xml(string => $resp->decoded_content(charset => 'none'));
    for my $node ($p->findnodes('//depended_on_by//dist/name')) {
	print $node->findvalue('.'), "\n";
    }

} else {
    if ($mod =~ m{-}) {
	die "Please specify a module, not a distribution";
    }

    require JSON::XS;

    my $resp = $ua->post('https://fastapi.metacpan.org/v1/release/_search',
			 Content => <<"EOF",
{
  "size": 5000,
  "fields": [ "distribution" ],
  "filter": {
    "and": [
      { "term": {"dependency.module": "$mod" } },
      { "term": {"maturity": "released"} },
      { "term": {"status": "latest"} }
    ]
  }
}
EOF
			);
    if (!$resp->is_success) {
	die $resp->as_string;
    }

    my $data = JSON::XS::decode_json($resp->decoded_content(charset => 'none'));
    my @dists = map { $_->{fields}->{distribution} } @{ $data->{hits}->{hits} || [] };
    print join("\n",@dists), "\n";
}

__END__

=head1 EXAMPLES

Possible use cases:

* Just list reverse dependencies:

    ~/src/perl/CPAN-Testers-ParallelSmoker/utils/cpan_dist_to_mod.pl $(cpan-reverse-dependencies.pl Test::Prereq)

* Smoke them:

    cpan_smoke_modules $(~/src/perl/CPAN-Testers-ParallelSmoker/utils/cpan_dist_to_mod.pl $(cpan-reverse-dependencies.pl Test::Prereq))

=cut
