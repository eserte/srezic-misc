#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cmp_ct_history.pl,v 1.8 2010/05/26 19:25:58 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Compare two CPAN::Reporter histories (e.g. for parallel comparing
# smokes)

use strict;
use CPAN;
use Getopt::Long;
use List::MoreUtils qw(uniq);

{
    package CPAN::SRTShell;
    use vars qw(@ISA);
    @ISA = $CPAN::Frontend;
    sub mysleep { shift; sleep shift()/10 }
    sub myprint { shift; print STDERR @_ }
}
$CPAN::Frontend="CPAN::SRTShell";

my $show_missing;
my $show_fulldist;
my $show_minimal;
my $org_file;
GetOptions("missing!"     => \$show_missing,
	   "fulldist!"    => \$show_fulldist,
	   "minimal|min+" => \$show_minimal,
	   "org=s"        => \$org_file,
	  )
    or die "usage: $0 [-missing] [-fulldist] [-minimal [-minimal]] newhistory oldhistory";

my $hist1 = shift or die "left history (usually the history with the *newer* system)?";
my $hist2 = shift or die "right history (usually the history with the *older* system)?";

my $dist2rt;
my $dist2fixed;
if ($org_file) {
    my %res = read_org_file($org_file);
    $dist2rt    = $res{dist2rt};
    $dist2fixed = $res{dist2fixed};
}

my %hist1 = %{ read_history($hist1) };
my %hist2 = %{ read_history($hist2) };

my %dists = map {($_,1)} keys(%hist1), keys(%hist2);

DIST: for my $dist (sort keys %dists) {
    my $res;
    if (!exists $hist1{$dist}) {
	$res = "missing left" if $show_missing;
    } elsif (!exists $hist2{$dist}) {
	$res = "missing right" if $show_missing;
    } else {
	my @grades_left  = uniq sort map { $_->[1] } @{$hist1{$dist}};
	my @grades_right = uniq sort map { $_->[1] } @{$hist2{$dist}};
	if ($show_minimal) {
	    for my $grades (\@grades_left, \@grades_right) {
		if ("@$grades" ne "DISCARD") {
		    @$grades = grep { $_ ne "DISCARD" } @$grades;
		}
	    }
	}
	if ($show_minimal && $show_minimal >= 2) {
	    my %grades_left  = map{($_,1)} @grades_left;
	    for my $grade_right (@grades_right) {
		if (exists $grades_left{$grade_right}) {
		    next DIST;
		}
	    }
	}
	my $grade_left  = join(" ", @grades_left);
	my $grade_right = join(" ", @grades_right);
	if ($show_minimal && $show_minimal >= 3) {
	    if ($grade_left eq 'PASS') {
		next DIST;
	    }
	}
	if ($show_minimal && $show_minimal >= 4) {
	    unless ($grade_left eq 'FAIL' && $grade_right =~ m{^(UNKNOWN|PASS|NA)$}) {
		next DIST;
	    }
	}
	if ($grade_left ne $grade_right) {
	    $res = "<$grade_left> vs. <$grade_right>";
	}
    }
    if ($res) {
	if ($show_fulldist) {
	    my $fulldist = CPAN::Shell->expand("Distribution", "/\\/$dist/");
	    $dist = $fulldist->id if $fulldist;
	}
	printf "%-55s %s", $dist, $res;
	if ($dist2rt->{$dist}) {
	    print "\t$dist2rt->{$dist}";
	}
	if ($dist2fixed->{$dist}) {
	    print "\t$dist2fixed->{$dist}";
	}
	print "\n";
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

sub read_org_file {
    my $file = shift;
    open my $fh, $file
	or die "Can't open $file: $!";
    my %dist2rt;
    my %dist2fixed;
    my $maybe_current_dist;
    while(<$fh>) {
	chomp;
	if (/^\*+\s*(\S+)/) {
	    $maybe_current_dist = $1;
	} elsif ($maybe_current_dist) {
	    if (m{(http.*?rt.cpan.org\S+Display.html\?id=\d+)}) {
		$dist2rt{$maybe_current_dist} = $1;
	    } elsif (m{(fixed in \d\S*)}) {
		$dist2fixed{$maybe_current_dist} = $1;
	    }
	}
    }
    (dist2rt    => \%dist2rt,
     dist2fixed => \%dist2fixed,
    );
}
 
__END__
