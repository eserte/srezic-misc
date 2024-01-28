#!/usr/bin/env perl

package FirefoxCookieFinder;

use strict;
use warnings;
use DBI;
use File::Temp;
use File::Copy;
use File::Glob qw(bsd_glob);

sub find_cookie_value {
    my ($cookie_name, $host_suffix, %options) = @_;
    my $expected_lifetime_in_days = delete $options{expected_lifetime};
    my $debug_flag = delete $options{debug};
    die "Unhandled options: " . join(" ", %options) if %options;

    my $debug = $debug_flag ? sub ($) { warn "DEBUG: $_[0]\n" } : sub ($) { };

    # If expected_cookie_lifetime_in_days is provided, convert it to seconds
    my $expected_lifetime = defined $expected_lifetime_in_days ? $expected_lifetime_in_days * 24 * 60 * 60 : undef;

    my @cookie_db_files = sort { -M $a <=> -M $b } bsd_glob("~/.mozilla/firefox/*/cookies.sqlite");

    for my $db_file (@cookie_db_files) {
	my $age_seconds = time - (stat($db_file))[9];
	$debug->("check $db_file (age ${age_seconds} seconds)");
        if (defined $expected_lifetime) {
            my $mod_time = -M $db_file;
            if ($mod_time > $expected_lifetime) {
		$debug->("older than expected lifetime");
		next;
	    }
        }

	# Create a temporary copy of the selected database file
	# (because the original is locked)
	my $temp_db_file = File::Temp->new(TMPDIR => 1);
	copy($db_file, $temp_db_file)
	    or die "Failed to create a temporary copy of the database file $db_file: $!\n";

	$debug->("open copy of sqlite file $temp_db_file");
	my $dbh = DBI->connect("dbi:SQLite:dbname=$temp_db_file", "", "", { RaiseError => 1, AutoCommit => 1 })
	    or die "Failed to connect to the database $temp_db_file: $DBI::errstr\n";

	my $now = time();
	my $query = "SELECT value FROM moz_cookies WHERE host LIKE ? AND name = ? AND expiry > ? LIMIT 1";
	my $sth = $dbh->prepare($query);
	$sth->execute("%$host_suffix", $cookie_name, $now);
	my ($cookie_value) = $sth->fetchrow_array;
	$sth->finish;

	if (defined $cookie_value) {
	    $debug->("found cookie $cookie_name for host $host_suffix in $db_file");
	    return $cookie_value;
	}

	$debug->("cannot find cookie $cookie_name for host $host_suffix in $db_file");
    }

    $debug->("nothing found");
    return undef;
}

if (!caller) {
    require Getopt::Long;

    my $usage = sub () {
        die "Usage: $0 [--expected-lifetime days] [--debug] <cookie_name> <host_suffix>\n";
    };

    Getopt::Long::GetOptions
	    (
	     "debug" => \my $debug,
	     "expected-lifetime=f" => \my $expected_lifetime_in_days,
	    )
	    or $usage->();
    $usage->() if @ARGV != 2;
    my($cookie_name, $host_suffix) = @ARGV;

    my $cookie_value = find_cookie_value($cookie_name, $host_suffix, expected_lifetime => $expected_lifetime_in_days, debug => $debug);
    if (defined $cookie_value) {
	print $cookie_value, "\n";
	exit 0;
    } else {
	die "Cannot find cookie.\n";
    }
}

1;
