#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008,2012,2013,2014,2015,2017,2018,2019,2024 Slaven Rezic. All rights reserved.
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
use File::Copy qw(move);
use POSIX qw(strftime);

sub check_term_title ();
sub set_term_title ($);
sub _ts ();

my $use_mail;
my $cpan_uid = 'srezic';
my $limit;
my $beta_test;
my $delay_retry = 60;
my $max_retry = 5;
my $fails_first;
my $special_fail_sorting;
GetOptions(
	   "mail" => \$use_mail,
	   "cpan-uid=s" => \$cpan_uid,
	   "limit=i" => \$limit,
	   "beta" => \$beta_test,
	   "max-retry=i" => \$max_retry,
	   "delay-retry=i" => \$delay_retry,
	   "fails-first!" => \$fails_first,
	   "special-fail-sorting!" => \$special_fail_sorting,
	  )
    or die "usage: $0 [-mail] [-cpan-uid ...] [-limit number] [-max-retry number] [-fails-first]\n";

#more_metabase_diagnostics(); # XXX maybe run conditionally

my $reportdir = shift || "$ENV{HOME}/var/cpansmoker";
if (!-d $reportdir) {
    die "$reportdir does not look like a directory";
}

my @reports = @ARGV;

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

# If reports are specified on command line: check that all are below $sync_dir
for my $report (@reports) {
    if (index($report, "$sync_dir/") != 0) {
	die "$report is not below $sync_dir";
    }
}

check_term_title;

if (!@reports) {
    @reports = (
		glob("$sync_dir/pass.*.rpt"),
		glob("$sync_dir/na.*.rpt"),
	       );
    my @fails    = glob("$sync_dir/fail.*.rpt");
    my @unknowns = glob("$sync_dir/unknown.*.rpt");
    if (@fails && $special_fail_sorting) {
	#warn qq{INFO: running special "unsimilarity" sorter, which is somewhat slow...\n};
	#@fails = UnsimilaritySorter::run(@fails);
	@fails = simple_unsimilarity_sorter(@fails);
    }
    if ($fails_first) {
	unshift @reports, @unknowns;
	unshift @reports, @fails;
    } else {
	push    @reports, @unknowns;
	push    @reports, @fails;
    }
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
    Time::Progress->new(min => 0, max => scalar(@reports));
};

my $sending_reports_msg = sub {
    my $reports_i = shift;
    "Sending reports (" . $reports_i . "/" . scalar(@reports) . ")" . ($progress && $reports_i ? $progress->report(" (yet %Emin)", $reports_i) : '') . ($beta_test ? " [-> BETA]" : "");
};

set_term_title $sending_reports_msg->(0);

my $should_exit;
$SIG{TERM} = $SIG{INT} = sub {
    warn "INFO: signal caught, will exit as soon as possible\n";
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
	    my $errstr = $r->errstr;
	    if ($errstr =~ m{(
				 \Qfact submission failed: No healthy backends\E
			     |   \Qfact submission failed: Proxy Error\E
			     |   \Qfact submission failed: Internal Exception\E
			     |   \Qfact submission failed: backend read error\E
			     )}x) {
		# short error message
		warn "[" . _ts . "] Failed for $process_file: $1\n";
	    } else {
		warn "[" . _ts . "] Something failed in $process_file: " . $errstr . ".\n";
	    }
	    if ($try == $max_retry) {
		die "Stop.\n";
	    }
	    my $this_sleep = int($delay_retry + rand(2*$sleep_jitter) - $sleep_jitter);
	    $this_sleep = 1 if $this_sleep < 1;
	    warn "Sleeping ${this_sleep}s before retrying...\n";
	    sleep $this_sleep;
	}
	die "Should not happen";
    }
    if (!$beta_test) {
	my $done_file = $done_dir . "/" . basename($file);
	move $process_file, $done_file
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

sub simple_unsimilarity_sorter {
    my(@files) = @_;
    my @out;
    my $letters = 0;
    while (@files) {
	$letters++;
	if ($letters > 1000) {
	    die "Possible problem, too many iterations (letters=$letters)";
	}
	my %seen;
	for(my $file_i=0; $file_i<=$#files; $file_i++) {
	    my $file = $files[$file_i];
	    my $base = basename $file;
	    $base =~ s{^[^.]+\.}{};
	    my $prefix = substr($base, 0, $letters);
	    if (!$seen{$prefix}++) {
		push @out, splice @files, $file_i, 1;
		$file_i--;
	    }
	}
    }
    @out;
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

# XXX monkey patch for more diagnostics
sub more_metabase_diagnostics {
    require Metabase::Client::Simple;
    no warnings 'once'; # but keep the redefine warning
    *Metabase::Client::Simple::submit_fact = sub {
    my ( $self, $fact ) = @_;

    my $path = sprintf 'submit/%s', $fact->type;

    $fact->set_creator( $self->profile->resource )
      unless $fact->creator;

    my $req_uri = $self->_abs_uri($path);

    my $auth = $self->_ua->_uri_escape(
        join( ":", $self->profile->resource->guid, $self->secret->content ) );

    $req_uri->userinfo($auth);

    my @req = (
        $req_uri,
        {
            headers => {
                Content_Type => 'application/json',
                Accept       => 'application/json',
            },
            content => JSON::MaybeXS->new( { ascii => 1 } )->encode( $fact->as_struct ),
        },
    );

    my $res = $self->_ua->post(@req);

    if ( $res->{status} == 401 ) {
        if ( $self->guid_exists( $self->profile->guid ) ) {
            Carp::confess($self->_error( $res => "authentication failed" ));
        }
        $self->register; # dies on failure
        # should now be registered so try again
        $res = $self->_ua->post(@req);
    }

    unless ( $res->{success} ) {
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$res],[qw()])->Indent(1)->Useqq(1)->Sortkeys(1)->Terse(1)->Dump; # XXX
        Carp::confess($self->_error( $res => "fact submission failed" ));
    }

    # This will be something more informational later, like "accepted" or
    # "queued," maybe. -- rjbs, 2009-03-30
    return 1;
};

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
