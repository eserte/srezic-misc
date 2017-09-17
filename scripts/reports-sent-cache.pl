#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2016,2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use autodie;
use 5.010; # regexp capture groups

use Getopt::Long;
use Fcntl qw(O_CREAT O_RDWR SEEK_SET LOCK_EX);
use MLDBM qw(DB_File Storable);

my $incremental = 1;
my $reports_sent_file = "$ENV{HOME}/.cpanreporter/reports-sent.db";
my $cache_file;

GetOptions(
	   'cache=s'        => \$cache_file,
	   'reports-sent=s' => \$reports_sent_file,
	   'incremental!'   => \$incremental,
	  )
    or die 'usage?';

if (!defined $cache_file) {
    $cache_file = $reports_sent_file . '.cache';
}

my $lockfh;
if (-e $cache_file) {
    warn "INFO: Wait for lock...\n";
    open $lockfh, '<', $cache_file
	or die "ERROR: Can't open $cache_file: $!";
    flock $lockfh, LOCK_EX
	or die "ERROR: Can't lock: $!";
}

tie my %db, 'MLDBM', $cache_file, O_CREAT|O_RDWR, 0640
    or die "ERROR: Can't tie cache: $!";

open my $fh, '<', $reports_sent_file;
if ($incremental && defined $db{' seek'}) {
    if (-s $reports_sent_file < $db{' seek'}) {
	die "ERROR: Size of $reports_sent_file less than seek position (" . $db{' seek'} . "), file shrinked?";
    }
    warn 'INFO: Start from seek position ' . $db{' seek'} . "...\n";
    seek $fh, $db{' seek'}, SEEK_SET
	or die "ERROR: Cannot seek: $!";
}
my $lines = 0;
while(<$fh>) {
    next if /^#/; # just in case
    if (!m{\n\z}) {
	warn "WARN: incomplete line? Stop here!\n";
	last;
    }
    chomp;
    if (m{^(?<phase>\S+) (?<action>\S+) (?<dist>\S+) \(perl-(?<perlver>[^)]+)\) (?<archname>\S+) (?<osvers>\S+)}) {
	my $hash = $db{$+{dist}} || {};
	$hash->{$+{perlver}}->{$+{archname}}->{$+{action}} = 1;
	$db{$+{dist}} = $hash;
    } else {
	warn "WARN: cannot parse $_";
    }
    if (++$lines % 10_000 == 0) {
	printf STDERR "\r$lines lines ...";
	$db{' seek'} = tell $fh; # flush seek position every now and then
    }
}
$db{' seek'} = tell $fh;
printf STDERR "\r$lines lines - finished\n";

__END__

=pod

Work in progress: create a fast L<MLDBM>-based cache for
F<reports-sent.db>. To be used by L<cpan_smoke_modules>.

=cut
