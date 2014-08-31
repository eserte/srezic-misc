#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use LWP::UserAgent;
use JSON::XS;

my $mod = shift
    or die "Module?";

my $ua = LWP::UserAgent->new;
my $resp = $ua->post('http://api.metacpan.org/v0/release/_search',
		     Content => <<"EOF",
{
  "query": {
    "match_all": {}
  },
  "size": 5000,
  "fields": [ "distribution" ],
  "filter": {
    "and": [
      { "term": { "release.dependency.module": "$mod" } },
      { "term": {"release.maturity": "released"} },
      { "term": {"release.status": "latest"} }
    ]
  }
}
EOF
		    );
if (!$resp->is_success) {
    die $resp->as_string;
}

my $data = decode_json($resp->decoded_content(charset => 'none'));
my @dists = map { $_->{fields}->{distribution} } @{ $data->{hits}->{hits} || [] };
print join("\n",@dists), "\n";

__END__

=head1 EXAMPLES

Possible use cases:

* Just list reverse dependencies:

    ~/src/perl/CPAN-Testers-ParallelSmoker/utils/cpan_dist_to_mod.pl $(cpan-reverse-dependencies.pl Test::Prereq)

* Smoke them:

    cpan_smoke_modules $(~/src/perl/CPAN-Testers-ParallelSmoker/utils/cpan_dist_to_mod.pl $(cpan-reverse-dependencies.pl Test::Prereq))

=cut
