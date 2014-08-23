#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;

my $dpkg_log = shift || "/var/log/dpkg.log";

open my $fh, $dpkg_log or die "Can't open $dpkg_log: $!";
while(<$fh>) {
    if (my($package, $from_version, $to_version) = $_ =~ m{ upgrade (\S+) (\S+) (\S+)}) {
	print "-"x70, "\n";
	print $_;
	my $changelog = "/usr/share/doc/$package/changelog.Debian.gz";
	open my $changelog_fh, "-|", "zcat", $changelog
	    or do {
		print "ERROR: Cannot read $changelog, skipping this package (error: $@)\n";
		next;
	    };
	my $changelog_contents = '';
	my $state = 'search_newer_version';
	while(<$changelog_fh>) {
	    if ($state eq 'search_newer_version') {
		if (m{^\Q$package ($to_version)}) {
		    $changelog_contents .= $_;
		    $state = 'search_older_version';
		}
	    } elsif ($state eq 'search_older_version') {
		if (m{^\Q$package ($from_version)}) {
		    $state = 'finished';
		    # don't "last" out of the loop, consume the changelog till the end to avoid SIGPIPE errors
		} else {
		    $changelog_contents .= $_;
		}
	    }
	}
	close $changelog_fh
	    or do {
		print "ERROR: problem reading from $changelog (error: $!)\n";
		next;
	    };

	if ($state eq 'search_newer_version') {
	    print "ERROR: cannot find newer version '$to_version' in $changelog.\n";
	} elsif ($state eq 'search_older_version') {
	    print "ERROR: cannot find older version '$from_version' in $changelog.\n";
	} else {
	    print $changelog_contents;
	}
    }
}

__END__

=head1 NAME

show-debian-changes.pl - display changes for recent debian updates

=head1 SYNOPSIS

    show-debian-changes.pl

    show-debian-changes.pl /var/log/dpkg.log.1

    zcat /var/log/dpkg.log.2.gz | show-debian-changes.pl -

=head1 DESCRIPTION

For the updates listed in F</var/log/dpkg.log> (or the given log file)
try to find the changelog entries and display them.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<apt-listchanges(1)>.

=cut
