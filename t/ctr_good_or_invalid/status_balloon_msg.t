#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use File::Temp qw(tempdir);
use Test::More 'no_plan';

my $scripts_dir = "$FindBin::RealBin/../../scripts";
require "$scripts_dir/ctr_good_or_invalid.pl";

my $tmpdir = tempdir(CLEANUP => 1, TMPDIR => 1);
for my $def (
	     ['pass.Something-1.0-freebsd.rpt', 'v5.20.0', 'PASS Something-1.0 freebsd'],
	     ['pass.Something-1.0-linux.rpt',   'v5.18.4', 'PASS Something-1.0 linux'],
	     ['pass.Something-1.0-windows.rpt', 'v5.22.0', 'PASS Something-1.0 windows'],
	     ['pass.Something-1.0-windows-123456.rpt', 'v5.22.0 RC1', 'PASS Something-1.0 windows'],
	    ) {
    my($file, $perl, $subject) = @$def;
    open my $ofh, '>', "$tmpdir/$file"
	or die "Can't write to $tmpdir/$file: $!";
    if ($subject =~ m{windows}) {
	binmode $ofh, ':crlf';
    } else {
	binmode $ofh;
    }
    print $ofh <<"EOF";
X-Test-Reporter-Perl: $perl
Subject: $subject

The report body
EOF
    close $ofh
	or die $!;
}

{
    my %recent_states =
	(
	 'PASS' => {
		    'old' => ["$tmpdir/pass.Something-1.0-freebsd.rpt", "$tmpdir/pass.Something-1.0-linux.rpt"],
		    'new' => ["$tmpdir/pass.Something-1.0-windows.rpt"],
		   },
	);
    my $msg = _get_status_balloon_msg($recent_states{'PASS'});
    chomp(my $expected_msg = <<'EOF');
perl v5.18.4 PASS Something-1.0 linux
perl v5.20.0 PASS Something-1.0 freebsd
perl v5.22.0 PASS Something-1.0 windows
EOF
    is $msg, $expected_msg;
}

{
    my %recent_states =
	(
	 'PASS' => {
		    'new' => ["$tmpdir/pass.Something-1.0-windows.rpt", "$tmpdir/pass.Something-1.0-windows-123456.rpt"],
		   },
	);
    my $msg = _get_status_balloon_msg($recent_states{'PASS'});
    chomp(my $expected_msg = <<'EOF');
perl v5.22.0 RC1 PASS Something-1.0 windows
perl v5.22.0 PASS Something-1.0 windows
EOF
    is $msg, $expected_msg;
}

__END__
