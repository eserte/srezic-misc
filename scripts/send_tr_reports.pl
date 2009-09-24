#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: send_tr_reports.pl,v 1.7 2009/09/24 21:01:52 eserte Exp $
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

my $reportdir = shift || "$ENV{HOME}/var/ctr";

my $sync_dir = "$reportdir/sync";
my $done_dir = "$reportdir/done";
my $process_dir = "$reportdir/process";

if (!-d $sync_dir) {
    warn "Create $sync_dir and move reports to this directory...";
}
if (!-d $done_dir) {
    mkdir $done_dir    or die "While creating $done_dir: $!";
}
if (!-d $process_dir) {
    mkdir $process_dir or die "While creating $process_dir: $!";
}

for my $file (glob("$sync_dir/pass.*.rpt"),
	      glob("$sync_dir/unknown.*.rpt"),
	      glob("$sync_dir/na.*.rpt"),
	      glob("$sync_dir/fail.*.rpt"),
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

=head1 WORKFLOW

See CPAN/CPAN::Reporter configuration below:

The good (non-fail) reports. On the windows machine

    ssh 192.168.1.253
    cd /cygdrive/c/Users/eserte/ctr
    ls sync/* && echo "sync is not empty" || mv *.rpt sync/
    rsync -v -a sync/*.rpt eserte@biokovo:var/ctr/new/ && mv sync/*.rpt done/

On the unix machine

    ctr_good_or_invalid.pl
    send_tr_reports.pl

Now review the fail reports on the windows machine. Invalid ones move
to the invalid/ subdirectory.

=head1 CPAN::REPORTER CONFIGURATION

In /cygdrive/c/Users/eserte/Documents/.cpanreporter/config.ini:

    edit_report=default:no
    email_from=srezic@cpan.org
    send_report=default:yes
    transport=File C:\Users\eserte\ctr

Basically the same configuration can be used for cygwin
~/.cpanreporter/config.ini, just use the cygwin path style for the
transport directory.

    edit_report=default:no
    email_from=srezic@cpan.org
    send_report=default:yes
    transport=File /cygdrive/c/Users/eserte/ctr

=cut
