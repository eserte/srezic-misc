#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cpandisthasfile.pl,v 1.3 2010/04/11 07:51:39 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008,2009,2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Basename qw(dirname);
use File::Path qw(mkpath);

my $cache = "$ENV{HOME}/var/cpanfilelist";
mkpath $cache if !-d $cache;
die "Cannot create cache $cache" if !-d $cache;

my @check_for;
if (@ARGV) {
    @check_for = @ARGV;
} else {
    die "usage: $0 rx ...";
}

my $tgz_qr = qr{\.(?:tgz|tar)};
my $zip_qr = qr{\.zip$};

my $dist = all_distributions();
for my $distfile (sort @$dist) {
    my $full = "/usr/local/src/CPAN/sources/authors/id/$distfile";
    if (!-r $full) {
	warn "SKIP distfile does not exist on disk: $full\n";
	next;
    }
    if ($full !~ $tgz_qr && $full !~ $zip_qr) {
	warn "SKIP can handle only tar or zip files: $distfile";
    }
    my $cachefile = $cache . "/" . $full . ".list";
    if (!-r $cachefile) {
	my $cachefiledir = dirname($cachefile);
	mkpath $cachefiledir if !-d $cachefiledir;
	die "Cannot create $cachefiledir: $!" if !-d $cachefiledir;

	open my $ofh, ">", $cachefile
	    or die "Can't write to $cachefile: $!";

	if ($full =~ $tgz_qr) {
	    my @cmd = ("tar", "tf", $full); # assumes modern tar without the need for -z
	    open my $fh, "-|", @cmd
		or die "@cmd: $!";
	    while(<$fh>) {
		print $ofh $_;
	    }
	} elsif ($full =~ $zip_qr) {
	    my $zip = Archive::Zip->new;
	    if ($zip->read($full) != AZ_OK) {
		warn "ERROR while reading zip: $distfile";
		next;
	    }
	    for my $member_name ($zip->memberNames) {
		print $ofh $member_name, "\n";
	    }
	} else {
	    warn "ERROR should never happen ($distfile)";
	}

	close $ofh
	    or die "While closing $cachefile: $!";
    }

    open my $fh, $cachefile
	or die "Cannot open $cachefile: $!";
    my %this_check_for = map{(qr{$_},1)} @check_for;
 LOOP_FILE: while(<$fh>) {
	for my $check_for (keys %this_check_for) {
	    if ($_ =~ $check_for) {
		delete $this_check_for{$check_for};
		if (!%this_check_for) {
		    print "$distfile\n"; # FOUND
		    last LOOP_FILE;
		}
	    }
	}
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
