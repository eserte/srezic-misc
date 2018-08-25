#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2018 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Getopt::Long;
use P9Y::ProcessTable;

sub y_or_n (;$);

my $sleep = 10;
GetOptions(
	   "batch"   => \my $batch,
	   "dry-run" => \my $dry_run,
	   "debug"   => \my $debug,
	   "sleep=i" => \$sleep,
	  )
    or die "usage: $0 [--batch] [--dry-run] [--debug] [--sleep seconds]\n";

my %candidate_ppid_time;
while () {
    my %pid_to_childpid;
    my %candidate_ppid;
    my %seen_pid;

    my @processes = P9Y::ProcessTable->table;

    for my $process (@processes) {
	my $pid = $process->pid;
	$seen_pid{$pid} = 1;
	my $ppid = $process->ppid;
	if ($ppid) {
	    push @{ $pid_to_childpid{$ppid} }, $pid;
	}

	no warnings 'uninitialized';
	if (
	    $process->exe =~ m{perl\.exe$} &&
	    $process->cmdline =~ m{use Fcntl.*sysopen.*syswrite.*AppData\\Local\\Temp}s
	   ) {
	    my $duration = time - $process->start;
	    if ($duration >= 2) {
		push @{ $candidate_ppid{$ppid} }, $process;
	    }
	}
    }

    for my $ppid (keys %candidate_ppid) {
	if (
	    join(",", sort                 @{ $pid_to_childpid{$ppid} || [] }) eq
	    join(",", sort map { $_->pid } @{ $candidate_ppid{$ppid} })
	   ) {
	    if (exists $candidate_ppid_time{$ppid}) {
		my $candidate_duration = time - $candidate_ppid_time{$ppid};
		if ($candidate_duration >= 10) {
		    print STDERR "Candidates to kill (candidate duration: ${candidate_duration}s):\n";
		    for my $process (@{ $candidate_ppid{$ppid} }) {
			print STDERR "  " . $process->pid . " (duration: " . (time-$process->start) . "s)\n";
		    }

		    my $do_kill;
		    if (!$batch) {
			print STDERR "Kill processes? (y/n) ";
			if (y_or_n) {
			    $do_kill = 1;
			}
		    } else {
			$do_kill = 1;
		    }

		    if ($do_kill) {
			for my $process (@{ $candidate_ppid{$ppid} }) {
			    print STDERR "Kill process " . $process->pid . "... ";
			    if ($dry_run) {
				print STDERR "(dry-run)\n";
			    } else {
				$process->kill(9);
				print STDERR "done\n";
			    }
			}
		    }
		} else {
		    if ($debug) {
			print STDERR "Candidate duration for $ppid: ${candidate_duration}s\n";
		    }
		}
	    } else {
		# first seen
		$candidate_ppid_time{$ppid} = time;
	    }
	} else {
	    if ($debug) {
		print STDERR "$ppid is probably still active, do not kill candidates...\n";
	    }
	}
    }

    for my $ppid (keys %candidate_ppid_time) {
	if (!exists $candidate_ppid{$ppid}) {
	    # process gone or not inactive
	    delete $candidate_ppid_time{$ppid};
	}
    }

    sleep $sleep;
}

# REPO BEGIN
# REPO NAME y_or_n /home/eserte/src/srezic-repository 
# REPO MD5 146cfcf8f954555fe0117a55b0ddc9b1

#=head2 y_or_n
#
#Accept user input. Return true on 'y', return false on 'n', otherwise
#ask again.
#
#A default may be supplied as an optional argument:
#
#    y_or_n 'y';
#    y_or_n 'n';
#
#=cut

sub y_or_n (;$) {
    my $default = shift;
    while () {
        chomp(my $yn = <STDIN>);
	if ($yn eq '' && defined $default) {
	    $yn = $default;
	}
        if (lc $yn eq 'y') {
            return 1;
        } elsif (lc $yn eq 'n') {
	    return 0;
        } else {
            print STDERR "Please answer y or n: ";
        }
    }
}
# REPO END

__END__

=head1 NAME

capture-tiny-watcher.pl - kill hanging Capture::Tiny processes

=head1 SYNOPSIS

    perl capture-tiny-watcher.pl [--batch] [--debug] [--dry-run]

=head1 DESCRIPTION

Watch for possibly hanging Capture::Tiny processes on Windows systems,
and kill them automatically (in C<--batch> mode) or interactively
(default if C<--batch> is not specified) or just show what would be
killed (in C<--dry-run> mode).

Problem was described in

=over

=item * L<https://github.com/cpan-testers/CPAN-Reporter/issues/28>

=item * L<http://blogs.perl.org/users/michael/2012/12/smoke-testing-on-windows.html>

=back

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 SEE ALSO

L<PY9::ProcessTable>.

=cut
