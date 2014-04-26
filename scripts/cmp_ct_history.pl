#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008-2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Compare two CPAN::Reporter histories (e.g. for parallel comparing
# smokes)

use strict;
use FindBin;
# for CPAN::Testers::ParallelSmoker:
use lib (
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../../lib",
	);

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
my $use_default_org_file;
my $do_dump_org_file;
my $smoke_config_file;
GetOptions("missing!"     => \$show_missing,
	   "fulldist!"    => \$show_fulldist,
	   "minimal|min+" => \$show_minimal,
	   "org=s"        => \$org_file,
	   "defaultorg!"  => \$use_default_org_file,
	   "dumporg"      => \$do_dump_org_file,
	   "config=s"     => \$smoke_config_file,
	  )
    or die "usage: $0 [-missing] [-fulldist] [-minimal [-minimal]] [-defaultorg|-org ...] -config file | newhistory oldhistory";

my($hist1, $hist2);
if ($smoke_config_file) {
    require CPAN::Testers::ParallelSmoker;
    CPAN::Testers::ParallelSmoker::load_config($smoke_config_file);
    CPAN::Testers::ParallelSmoker::set_home((getpwnam("cpansand"))[7]); # XXX do not hardcode!!!
    CPAN::Testers::ParallelSmoker::expand_config();
    $hist2 = $CPAN::Testers::ParallelSmoker::CONFIG->{perl1}->{configdir} . '/cpanreporter/reports-sent.db';
    $hist1 = $CPAN::Testers::ParallelSmoker::CONFIG->{perl2}->{configdir} . '/cpanreporter/reports-sent.db';
    -e $hist2 or die "Right history file $hist2 does not exist";
    -e $hist1 or die "Left history file $hist1 does not exist";
    -r $hist2 or die "Right history file $hist2 not readable";
    -r $hist1 or die "Left history file $hist2 not readable";
    if ($use_default_org_file) {
	my $_org_file = $CPAN::Testers::ParallelSmoker::CONFIG->{smokerdir} . '/smoke_' . $CPAN::Testers::ParallelSmoker::CONFIG->{testlabel} . '.txt';
	if (-e $_org_file) {
	    $org_file = $_org_file;
	} else {
	    $org_file = $CPAN::Testers::ParallelSmoker::CONFIG->{smokerdir} . '/smoke.txt';
	}
    }
} else {
    $hist1 = shift or die "left history (usually the history with the *newer* system)?";
    $hist2 = shift or die "right history (usually the history with the *older* system)?";
    if ($use_default_org_file) {
	die "Cannot use -defaultorg without -config, please specify -org /path/to/smoke.txt instead\n";
    }
}

my $dist2rt;
my $dist2fixed;
my $dist2ignore;
if ($org_file) {
    my %res = read_org_file($org_file);
    $dist2rt     = $res{dist2rt};
    $dist2fixed  = $res{dist2fixed};
    $dist2ignore = $res{dist2ignore};
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
	    if ($grade_left =~ m{^(PASS|DISCARD)$}) {
		next DIST;
	    } elsif ($grade_right ne 'PASS') {
		next DIST;
	    }
	}
	if ($grade_left ne $grade_right) {
	    $res = "<$grade_left> vs. <$grade_right>";
	}
    }
    if ($res) {
	my $dist_or_fulldist = $dist;
	if ($show_fulldist) {
	    my $fulldist = CPAN::Shell->expand("Distribution", "/\\/$dist/");
	    $dist_or_fulldist = $fulldist->id if $fulldist;
	}
	if ($show_minimal && $show_minimal >= 3 && $dist2ignore->{$dist}) {
	    next DIST;
	}
	printf "%-55s %s", $dist_or_fulldist, $res;
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
    my $file = shift;
    my %hist;
    open my $ifh, $file
	or die $!;
    while(<$ifh>) {
	next if m{^#};
	chomp;
	# test PASS XML-Parser-2.36 (perl-5.8.8) i386-freebsd 6.1-release-p23
	my($phase, $grade, $dist, $perl, $arch) = $_ =~
	    m{^(\S+)\s+(\S+)\s+(\S+)\s+\((.*?)\)\s+(.*)};
	if (!defined $phase) {
	    warn "Cannot parse <$_> in $file, skipping line";
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
    my %dist2ignore;
    my $maybe_current_dist;
    my $ignore_current_section = 0;
    my $current_section_is_fixed_or_redo = 0;
    while(<$fh>) {
	chomp;
	if (/^\*\s+(.*)/) {
	    my $section_line = $1;
	    if ($section_line =~ m{:IGNORE_IN_COMPARISONS:}) {
		$ignore_current_section = 1;
	    } else {
		$ignore_current_section = 0;
	    }
	    if ($section_line =~ m{:(FIXED|REDO):}) {
		$current_section_is_fixed_or_redo = 1;
	    } else {
		$current_section_is_fixed_or_redo = 0;
	    }
	} elsif (/^\*\*+\s*(\S+)/) {
	    $maybe_current_dist = $1;
	    if ($current_section_is_fixed_or_redo) {
		next;
	    }
	    if ($ignore_current_section) {
		$dist2ignore{$maybe_current_dist} = 1;
	    }
	} elsif ($maybe_current_dist) {
	    if (m{(
		      http.*?rt.cpan.org\S+Display.html\?id=\d+
		  |   http.*?rt.perl.org\S+Display.html\?id=\d+
		  |   https://github.com/.*/.*/issues/\d+
		  )}x) {
		if ($current_section_is_fixed_or_redo) {
		    next;
		}
		$dist2rt{$maybe_current_dist} = $1;
	    } elsif (m{(fixed in \d\S*)}) {
		$dist2fixed{$maybe_current_dist} = $1;
	    } elsif (m{\bignore\b}) {
		$dist2ignore{$maybe_current_dist} = 1;
	    }
	}
    }
    my %res = (dist2rt    => \%dist2rt,
	       dist2fixed => \%dist2fixed,
	       dist2ignore => \%dist2ignore,
	      );
    if ($do_dump_org_file) {
	require Data::Dumper;
	print Data::Dumper::Dumper(\%res);
	exit 0;
    }
    %res;
}
 
__END__

# TODO: documentation, especially of the org mode file
#
# org mode file, special tags and text:
# * first level sections may contain the tag :IGNORE_IN_COMPARISONS:
#   which will cause all distributions in this section to be
#   ignored in comparisons
# * distribution names (without author, with version) in section level
#   two or higher
# * a full cpan rt link is detected and displayed in a special column
# * a "fixed in ...." string is detected
# * if the word "ignore" appears in the text, then the distribution
#   will be ignored in comparisons
