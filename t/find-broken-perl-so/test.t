#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Test::More 'no_plan';
use IPC::Run 'run';

my $find_broken_perl_so = "$FindBin::RealBin/../../scripts/find-broken-perl-so.pl";

my $success = run [$^X, $find_broken_perl_so], '2>', \my $stderr;
ok $success;
like $stderr, qr{^No broken \.so files found in };

__END__
