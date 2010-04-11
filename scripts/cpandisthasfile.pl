#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cpandisthasfile.pl,v 1.1 2010/04/11 07:51:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

my $check_for = qr{/Build\.PL$};

my $dist = all_distributions();
for my $distfile (sort @$dist) {
    my $full = "/usr/local/src/CPAN/sources/authors/id/$distfile";
    if (!-r $full) {
	warn "ERROR not exists: $full\n";
	next;
    }
    if ($full =~ m{\.(?:tgz|tar)}) {
	my @cmd = ("tar", "tfv", $full); # assumes modern tar without the need for -z
	open my $fh, "-|", @cmd
	    or die "@cmd: $!";
	while(<$fh>) {
	    if ($_ =~ $check_for) {
		print "FOUND: $distfile\n";
		last;
	    }
	}
    } elsif ($full =~ m{\.zip$}) {
	my $zip = Archive::Zip->new;
	if ($zip->read($full) != AZ_OK) {
	    warn "ERROR while reading zip: $distfile";
	    next;
	}
	for my $member_name ($zip->memberNames) {
	    if ($member_name =~ $check_for) {
		print "FOUND: $distfile\n";
		last;
	    }
	}
    } else {
	warn "ERROR can handled only tar files: $distfile";
    }
}

sub all_distributions { # takes ~3 seconds
    use PerlIO::gzip;
    my %dist;
    open my $FH, "<:gzip", "/usr/local/src/CPAN/sources/modules/02packages.details.txt.gz"
	or die $!;
    my $state = "h";
    while(<$FH>) {
	if ($state eq 'h') {
	    if (/^$/) {
		$state = 'b';
	    }
	} else {
	    my(undef,undef, $dist) = split;
	    $dist{$dist}++;
	}
    }
    [keys %dist];
}

__END__
