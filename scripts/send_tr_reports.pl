#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008,2012,2013,2014,2015,2017 Slaven Rezic. All rights reserved.
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
sub _ts ();

my $use_mail;
my $cpan_uid = 'srezic';
my $limit;
my $beta_test;
my $max_retry = 5;
my $fails_first;
my $special_fail_sorting;
GetOptions(
	   "mail" => \$use_mail,
	   "cpan-uid=s" => \$cpan_uid,
	   "limit=i" => \$limit,
	   "beta" => \$beta_test,
	   "max-retry=i" => \$max_retry,
	   "fails-first!" => \$fails_first,
	   "special-fail-sorting!" => \$special_fail_sorting,
	  )
    or die "usage: $0 [-mail] [-cpan-uid ...] [-limit number] [-max-retry number] [-fails-first]\n";

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
	      );
my @fails    = glob("$sync_dir/fail.*.rpt");
my @unknowns = glob("$sync_dir/unknown.*.rpt");
if (@fails && $special_fail_sorting) {
    warn qq{INFO: running special "unsimilarity" sorter, which is somewhat slow...\n};
    @fails = UnsimilaritySorter::run(@fails);
}
if ($fails_first) {
    unshift @reports, @unknowns;
    unshift @reports, @fails;
} else {
    push    @reports, @unknowns;
    push    @reports, @fails;
}

if (!@reports) {
    set_term_title 'No reports to send';
    exit 0;
}

if ($limit && $limit < scalar(@reports)) {
    print STDERR "Limit number of reports from " . scalar(@reports) . "... ";
    @reports = @reports[0..$limit-1];
    print STDERR "to " . scalar(@reports) . ".\n";
}

my $progress = eval {
    require Time::Progress;
    Time::Progress->new(min => 0, max => $limit);
};

my $sending_reports_msg = sub {
    my $reports_i = shift;
    "Sending reports (" . $reports_i . "/" . scalar(@reports) . ")" . ($progress && $reports_i ? $progress->report(" (yet %Emin)", $reports_i) : '') . ($beta_test ? " [-> BETA]" : "");
};

set_term_title $sending_reports_msg->(0);

my $should_exit;
local $SIG{TERM} = sub {
    warn "INFO: SIGTERM caught, will exit as soon as possible\n";
    $should_exit = 1;
};

my $reports_i = 0;
my $term_title_last_changed = time;
REPORTS_LOOP: for my $file (@reports) {
    if ($should_exit) {
	warn "INFO: now exiting because of signal\n";
	last REPORTS_LOOP;
    }

    $reports_i++;
    if (time - $term_title_last_changed >= 1) {
	set_term_title $sending_reports_msg->($reports_i);
	$term_title_last_changed = time;
    }
    warn "File $file does not exist anymore?", next if !-r $file;
    warn "$file...\n";
    my $process_file;
    if ($beta_test) {
	$process_file = $file;
    } else {
	$process_file = $process_dir . "/" . basename($file);
	rename $file, $process_file
	    or die "Cannot move $file to $process_file: $!";
    }
    my @tr_args;
    if ($use_mail) {
	@tr_args = (from => "srezic\@cpan.org",
		    transport => "Net::SMTP",
		    mx => ["localhost"],
		   );
    } else {
	my $url = 'https://metabase.cpantesters.org/api/v1/';
	if ($beta_test) {
	    $url = 'http://metabase-beta.cpantesters.org/api/v1';
	}
	@tr_args = (transport => 'Metabase',
		    transport_args => [
				       uri => $url,
				       id_file => "$ENV{HOME}/.cpanreporter/" . $cpan_uid . "_metabase_id.json",
				      ],
		   );
    }

 DO_SEND: {
	my $sleep = 60;
	my $sleep_jitter = 5; # +/-5s
	for my $try (1..$max_retry) {
	    if ($should_exit) {
		warn "INFO: now exiting because of signal\n";
		last REPORTS_LOOP;
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

	    last DO_SEND if $r->send;
	    warn "[" . _ts . "] Something failed in $process_file: " . $r->errstr . ".\n";
	    if ($try == $max_retry) {
		die "Stop.\n";
	    }
	    my $this_sleep = int($sleep + rand(2*$sleep_jitter) - $sleep_jitter);
	    warn "Sleeping ${this_sleep}s before retrying...\n";
	    sleep $this_sleep;
	}
	die "Should not happen";
    }
    if (!$beta_test) {
	my $done_file = $done_dir . "/" . basename($file);
	rename $process_file, $done_file
	    or die "Cannot move $process_file to $done_file: $!";
    }
}

if ($should_exit) {
    set_term_title "Report sender terminated";
} else {
    set_term_title "Report sender finished";
}

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

sub _ts () {
    strftime("%Y-%m-%d %H:%M:%S", localtime);
}

{
    package UnsimilaritySorter;

    {
	my %cache;
	sub _normalize ($) {
	    my $f = shift;
	    my $normalized = $cache{$f};
	    return $normalized if defined $normalized;
	    ($normalized = $f) =~ s{^[^.]+\.}{}; # "fail." ...
	    $normalized =~ s{\.\d+\.\d+\.rpt$}{};
	    $cache{$f} = $normalized;
	}
    }

    {
	my %cache;
	sub _get_similarity ($$) {
	    my($f1,$f2) = @_;
	    my $similarity = $cache{"$f1 $f2"};
	    return $similarity if defined $similarity;
	    $cache{"$f1 $f2"} = $similarity = String::Similarity::similarity($f1, $f2);
	}
    }

    sub run {
	my(@unsorted) = @_;

	require String::Similarity;

	my @sorted = shift @unsorted;

	# O(n^3) :-(
	while (@unsorted) {
	    my $min_similarity;
	    my $min_similarity_file_i;
	    for my $i (0 .. $#unsorted) {
		my $f = $unsorted[$i];
		my $f_cmp = _normalize $f;
		my $this_max_similarity;
		for my $f2 (@sorted) {
		    my $f2_cmp = _normalize $f2;
		    #my $similarity = similarity $f_cmp, $f2_cmp, (defined $this_max_similarity ? $this_max_similarity : ());
		    my $similarity = _get_similarity $f_cmp, $f2_cmp;
		    if (!defined $this_max_similarity || $similarity > $this_max_similarity) {
			$this_max_similarity = $similarity;
		    }
		}
		if (!defined $min_similarity || $this_max_similarity < $min_similarity) {
		    $min_similarity = $this_max_similarity;
		    $min_similarity_file_i = $i;
		}
	    }
	    if (!defined $min_similarity_file_i) {
		die "should not happen";
	    }
	    push @sorted, splice(@unsorted, $min_similarity_file_i, 1);
	}

	@sorted;
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
