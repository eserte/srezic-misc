#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: send_tr_reports.pl,v 1.2 2009/09/24 20:57:04 eserte Exp $
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
use Test::Reporter;
use File::Basename;

my $sync_dir = "$ENV{HOME}/trash/sync";
my $done_dir = "$ENV{HOME}/trash/sync/done";
my $process_dir = "$ENV{HOME}/trash/sync/process";

for my $file (glob("$sync_dir/pass*.rpt"),
	      glob("$sync_dir/unknown*.rpt"),
	      glob("$sync_dir/na*.rpt"),
	     ) {
    warn "File $file does not exist anymore?", next if !-r $file;
    warn "$file...\n";
    my $process_file = $process_dir . "/" . basename($file);
    rename $file, $process_file
	or die "Cannot move $file to $process_file: $!";
    my $r = Test::Reporter->new(from => "srezic\@cpan.org",
				transport => "Net::SMTP",
				mx => ["localhost"]
			       )->read($process_file);
    # XXX fix t::r bug?
    $r->{_subject} =~ s{\n}{}g;
    $r->send;
    if ($r->errstr) {
	die "Something failed in $process_file: " . $r->errstr . ". Stop.\n";
    }
    my $done_file = $done_dir . "/" . basename($file);
    rename $process_file, $done_file
	or die "Cannot move $process_file to $done_file: $!";
}

__END__

=pod

Workflow

(lookup CPAN/CPAN::Reporter configuration on windows)

The good (non-fail) reports. On the windows machine

    cd /cygdrive/c/Users/eserte/ctr
    rm -f sync/*
    mv {pass,unknown,na}.* sync/
    rsync -v -a sync/ eserte@biokovo:trash/sync/

On the unix machine

    send_tr_reports.pl

Now review the fail reports on the windows machine. Invalid ones move
to the invalid/ subdirectory.

=cut
