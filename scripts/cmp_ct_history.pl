#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cmp_ct_history.pl,v 1.1 2010/04/11 07:54:18 eserte Exp $
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
use Getopt::Long;
use List::MoreUtils qw(uniq);

my $show_missing;
GetOptions("missing!" => \$show_missing)
    or die "usage: $0 [-missing] lefthistory righthistory";

my $hist1 = shift or die "left history?";
my $hist2 = shift or die "right history?";

my %hist1 = %{ read_history($hist1) };
my %hist2 = %{ read_history($hist2) };

my %dists = map {($_,1)} keys(%hist1), keys(%hist2);

for my $dist (sort keys %dists) {
    my $res;
    if (!exists $hist1{$dist}) {
	$res = "missing left" if $show_missing;
    } elsif (!exists $hist2{$dist}) {
	$res = "missing right" if $show_missing;
    } else {
	my $grade_left  = join(" ", uniq sort map { $_->[1] } @{$hist1{$dist}});
	my $grade_right = join(" ", uniq sort map { $_->[1] } @{$hist2{$dist}});
	if ($grade_left ne $grade_right) {
	    $res = "<$grade_left> vs. <$grade_right>";
	}
    }
    if ($res) {
	printf "%-55s %s\n", $dist, $res;
    }
}

sub read_history {
    my %hist;
    open my $ifh, shift
	or die $!;
    while(<$ifh>) {
	next if m{^#};
	chomp;
	# test PASS XML-Parser-2.36 (perl-5.8.8) i386-freebsd 6.1-release-p23
	my($phase, $grade, $dist, $perl, $arch) = $_ =~
	    m{^(\S+)\s+(\S+)\s+(\S+)\s+\((.*?)\)\s+(.*)};
	if (!defined $phase) {
	    warn "Cannot parse $_";
	    next;
	}
	push @{ $hist{$dist} }, [$phase, $grade, $perl, $arch];
    }
    \%hist;
}

 
__END__
