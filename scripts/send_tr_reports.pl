#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008,2012,2013,2014,2015 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Getopt::Long;
use Test::Reporter;
use File::Basename;
use POSIX qw(strftime);

sub check_term_title ();
sub set_term_title ($);

my $use_mail;
my $cpan_uid = 'srezic';
GetOptions(
	   "mail" => \$use_mail,
	   "cpan-uid=s" => \$cpan_uid,
	  )
    or die "usage: $0 [-mail] [-cpan-uid ...]";

my $reportdir = shift || "$ENV{HOME}/var/cpansmoker";

my $sync_dir = "$reportdir/sync";
my $done_root_dir = "$reportdir/done";
my $done_dir = "$done_root_dir/" . strftime("%Y-%m", localtime);
my $process_dir = "$reportdir/process";

if (!-d $sync_dir) {
    warn "Create $sync_dir and move reports to this directory...";
}
if (!-d $done_root_dir) {
    mkdir $done_root_dir or die "While creating $done_root_dir: $!";
}
if (!-d $done_dir) {
    mkdir $done_dir or die "While creating $done_dir: $!";
}
if (!-d $process_dir) {
    mkdir $process_dir or die "While creating $process_dir: $!";
}

check_term_title;

my @reports = (
	       glob("$sync_dir/pass.*.rpt"),
	       glob("$sync_dir/na.*.rpt"),
	       glob("$sync_dir/unknown.*.rpt"),
	       glob("$sync_dir/fail.*.rpt"),
	      );

if (!@reports) {
    set_term_title 'No reports to send';
    exit 0;
}

my $sending_reports_msg = sub {
    my $reports_i = shift;
    "Sending reports (" . $reports_i . "/" . scalar(@reports) . ")";
};

set_term_title $sending_reports_msg->(0);

my $reports_i = 0;
my $term_title_last_changed = time;
for my $file (@reports) {
    $reports_i++;
    if (time - $term_title_last_changed >= 1) {
	set_term_title $sending_reports_msg->($reports_i);
	$term_title_last_changed = time;
    }
    warn "File $file does not exist anymore?", next if !-r $file;
    warn "$file...\n";
    my $process_file = $process_dir . "/" . basename($file);
    rename $file, $process_file
	or die "Cannot move $file to $process_file: $!";
    my @tr_args;
    if ($use_mail) {
	@tr_args = (from => "srezic\@cpan.org",
		    transport => "Net::SMTP",
		    mx => ["localhost"],
		   );
    } else {
	@tr_args = (transport => 'Metabase',
		    transport_args => [
				       uri => 'https://metabase.cpantesters.org/api/v1/',
				       id_file => "$ENV{HOME}/.cpanreporter/" . $cpan_uid . "_metabase_id.json",
				      ],
		   );
    }
    my $r = Test::Reporter->new(@tr_args);

    # XXX Another TR bug: should not set these two by default
    # See https://rt.cpan.org/Ticket/Display.html?id=76447
    # XXX see also below
    undef $r->{_perl_version}->{_archname};
    undef $r->{_perl_version}->{_osvers};

    $r->read($process_file);

    # XXX fix t::r bug?
    # XXX Still problematic in current TR versions using Metabase?
    $r->{_subject} =~ s{\n}{}g;

    # XXX 2nd half on another TR bug: set the correct values for
    # _archname and _osvers
    # See https://rt.cpan.org/Ticket/Display.html?id=76447
    {
	use Config::Perl::V ();
	my $perlv = $r->{_perl_version}->{_myconfig};
	my $config = Config::Perl::V::summary(Config::Perl::V::plv2hash($perlv));
	$r->{_perl_version}->{_archname} = $config->{archname};
	$r->{_perl_version}->{_osvers} = $config->{osvers};
    }

    $r->send or
	die "Something failed in $process_file: " . $r->errstr . ". Stop.\n";
    my $done_file = $done_dir . "/" . basename($file);
    rename $process_file, $done_file
	or die "Cannot move $process_file to $done_file: $!";
}

set_term_title "Report sender finished";

{
    my $cannot_xterm_title;

    sub check_term_title () {
	if (!eval { require XTerm::Conf; 1 }) {
	    if (!eval { require Term::Title; 1 }) {
		$cannot_xterm_title = 1;
	    }
	}
    }

    sub set_term_title ($) {
	return if $cannot_xterm_title;
	my $string = shift;
	if (defined &XTerm::Conf::xterm_conf_string) {
	    print STDERR XTerm::Conf::xterm_conf_string(-title => $string);
	} else {
	    Term::Title::set_titlebar($string);
	}
    }
}

__END__

=head1 NAME

send_tr_reports.pl - send filed Test::Reporter reports to metabase

=head1 STANDALONE USAGE

Create a directory F<var/cpansmoker/sync> in your C<$HOME> directory
and move the test reports to this directory. Run the script (of course
replace with your cpan user id):

    send_tr_reports.pl --cpan-uid=srezic

Reports are first moved to the F<process> subdirectory, then processed
and moved further to the F<done> subdirectory. In case sending to
metabase fails, the report will still be in F<process> and has to be
moved manually to F<sync>.

=head1 SAMPLE COMPLETE WORKFLOW

I<(Warning: this section is probably not useful!)>

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

=head2 CPAN::REPORTER CONFIGURATION

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

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<Test::Reporter>.

=cut
