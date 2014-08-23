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
use Getopt::Long;

my $method;
GetOptions("method=s" => \$method)
    or die "usage?";

if (!$method && is_in_path('dpkg-parsechangelog')) {
    $method = 'dpkg-parsechangelog';
} else {
    $method = 'manually';
}

my $dpkg_log = shift || "/var/log/dpkg.log";

open my $fh, $dpkg_log or die "Can't open $dpkg_log: $!";
while(<$fh>) {
    if (my($package, $from_version, $to_version) = $_ =~ m{ upgrade (\S+) (\S+) (\S+)}) {
	print "-"x70, "\n";
	print $_;
	my $changelog = "/usr/share/doc/$package/changelog.Debian.gz";
	if (!-f $changelog) {
	    print "ERROR: the changelog file '$changelog' does not exist, skipping this package\n";
	    next;
	}

	my $parse_manually = sub {
	    open my $changelog_fh, "-|", "zcat", $changelog
		or do {
		    print "ERROR: Cannot read $changelog, skipping this package (error: $@)\n";
		    return;
		};
	    my $changelog_contents = '';
	    my $state = 'search_newer_version';
	    while (<$changelog_fh>) {
		if ($state eq 'search_newer_version') {
		    if (m{^\S+ \Q($to_version)}) {
			$changelog_contents .= $_;
			$state = 'search_older_version';
		    }
		} elsif ($state eq 'search_older_version') {
		    if (m{^\S+ \Q($from_version)}) {
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
		    return;
		};

	    if ($state eq 'search_newer_version') {
		print "ERROR: cannot find newer version '$to_version' in $changelog.\n";
	    } elsif ($state eq 'search_older_version') {
		print "ERROR: cannot find older version '$from_version' in $changelog.\n";
	    } else {
		print $changelog_contents;
	    }
	};

	my $parse_with_dpkg_parsechangelog = sub {
	    open my $changelog_fh, "zcat $changelog | dpkg-parsechangelog -l- --since '$from_version' --to '$to_version' 2>&1 |"
		or do {
		    print "ERROR: problem parsing $changelog with dpkg-parsechangelog.\n";
		    return;
		};
	    while(<$changelog_fh>) {
		print $_;
	    }
	};

	if ($method && $method eq 'dpkg-parsechangelog') {
	    $parse_with_dpkg_parsechangelog->();
	} elsif (!$method || $method eq 'manually') {
	    $parse_manually->();
	} else {
	    die "FATAL: Invalid method '$method'";
	}
    }
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/srezic-repository 
# REPO MD5 e18e6687a056e4a3cbcea4496aaaa1db
sub is_in_path {
    my($prog) = @_;
    require File::Spec;
    if (File::Spec->file_name_is_absolute($prog)) {
	if ($^O eq 'MSWin32') {
	    return $prog       if (-f $prog && -x $prog);
	    return "$prog.bat" if (-f "$prog.bat" && -x "$prog.bat");
	    return "$prog.com" if (-f "$prog.com" && -x "$prog.com");
	    return "$prog.exe" if (-f "$prog.exe" && -x "$prog.exe");
	    return "$prog.cmd" if (-f "$prog.cmd" && -x "$prog.cmd");
	} else {
	    return $prog if -f $prog and -x $prog;
	}
    }
    require Config;
    %Config::Config = %Config::Config if 0; # cease -w
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    # maybe use $ENV{PATHEXT} like maybe_command in ExtUtils/MM_Win32.pm?
	    return "$_\\$prog"     if (-f "$_\\$prog" && -x "$_\\$prog");
	    return "$_\\$prog.bat" if (-f "$_\\$prog.bat" && -x "$_\\$prog.bat");
	    return "$_\\$prog.com" if (-f "$_\\$prog.com" && -x "$_\\$prog.com");
	    return "$_\\$prog.exe" if (-f "$_\\$prog.exe" && -x "$_\\$prog.exe");
	    return "$_\\$prog.cmd" if (-f "$_\\$prog.cmd" && -x "$_\\$prog.cmd");
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

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

L<dpkg-parsechangelog(1)>, L<apt-listchanges(1)>.

=cut
