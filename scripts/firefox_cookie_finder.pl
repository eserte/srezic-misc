#!/usr/bin/env perl

package FirefoxCookieFinder;

use strict;
use warnings;
use Config;
use File::Temp;
use File::Copy;
use File::Glob qw(bsd_glob);

my @valid_methods = qw(auto dbi sqlite);

sub find_cookie_value {
    my ($cookie_name, $host_suffix, %options) = @_;
    my $expected_lifetime_in_days = delete $options{expected_lifetime};
    my $profile = delete $options{profile};
    my $debug_flag = delete $options{debug};
    my $method = delete $options{method};
    die "Unhandled options: " . join(" ", %options) if %options;

    $method = 'auto' if !defined $method;
    if (!grep { $method eq $_ } @valid_methods) {
	die "Invalid method '$method', must be one of @valid_methods\n";
    }

    my $debug = $debug_flag ? sub ($) { warn "DEBUG: $_[0]\n" } : sub ($) { };

    my $resolved_method = resolve_method($method, $debug);
    $debug->("using method '$resolved_method' (requested '$method')");

    # If expected_cookie_lifetime_in_days is provided, convert it to seconds
    my $expected_lifetime = defined $expected_lifetime_in_days ? $expected_lifetime_in_days * 24 * 60 * 60 : undef;

    my @firefox_directories;
    {
	my @firefox_directory_candidates = (
	    '.mozilla/firefox',                       # Linux
	    'snap/firefox/common',                     # Linux (snap package)
	    'Library/Application Support/Firefox/Profiles', # macOS
	);
	for my $candidate (@firefox_directory_candidates) {
	    my $candidate_path = "$ENV{HOME}/$candidate";
	    push @firefox_directories, $candidate_path if -d $candidate_path;
	}
	if (!@firefox_directories) {
	    die "No firefox directory found in home directory, tried @firefox_directory_candidates\n";
	}
    }	

    my @cookie_db_files;
    if (defined $profile) {
	my $profile_dir;
	if (-d $profile) {
	    $profile_dir = $profile;
	} else {
	    for my $firefox_directory (@firefox_directories) {
		my $candidate = "$firefox_directory/$profile";
		if (-d $candidate) {
		    $profile_dir = $candidate;
		    last;
		}
		($candidate) = bsd_glob("$firefox_directory/*.$profile");
		if (-d $candidate) {
		    $profile_dir = $candidate;
		    last;
		}
	    }
	}
	if (!defined $profile_dir) {
	    die "Cannot find a profile directory for profile name '$profile'\n";
	}
	@cookie_db_files = "$profile_dir/cookies.sqlite";
	if (!-f $cookie_db_files[0]) {
	    die "The profile directory $profile_dir does not have a cookies.sqlite file\n";
	}
    } else {
	@cookie_db_files = map { bsd_glob("$_/*/cookies.sqlite") } @firefox_directories;
	if (!@cookie_db_files) {
	    die "No cookies.sqlite files found in @firefox_directories\n";
	}
    }
    @cookie_db_files = sort { -M $a <=> -M $b } @cookie_db_files;

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

	my $cookie_value =
	    $resolved_method eq 'dbi'
	        ? _find_cookie_value_via_dbi("$temp_db_file", $cookie_name, $host_suffix, $debug)
	        : _find_cookie_value_via_sqlite_binary("$temp_db_file", $cookie_name, $host_suffix, $debug);

	if (defined $cookie_value) {
	    $debug->("found cookie $cookie_name for host $host_suffix in $db_file");
	    return $cookie_value;
	}

	$debug->("cannot find cookie $cookie_name for host $host_suffix in $db_file");
    }

    $debug->("nothing found");
    return undef;
}

# Decide which extraction method to actually use.
#   'dbi'    -> require DBI + DBD::SQLite to be available, die otherwise.
#   'sqlite' -> require a sqlite3 (or sqlite) binary in PATH, die otherwise.
#   'auto'   -> prefer DBI+DBD::SQLite if available, else fall back to a
#               sqlite binary, else die with a combined error message.
sub resolve_method {
    my ($method, $debug) = @_;
    $debug ||= sub ($) { };

    if ($method eq 'dbi') {
	if (!_dbi_available()) {
	    die "Method 'dbi' was requested, but DBI and/or DBD::SQLite are not installed.\n";
	}
	return 'dbi';
    } elsif ($method eq 'sqlite') {
	if (!_sqlite_binary()) {
	    die "Method 'sqlite' was requested, but no 'sqlite3' or 'sqlite' binary was found in PATH.\n";
	}
	return 'sqlite';
    } elsif ($method eq 'auto') {
	if (_dbi_available()) {
	    $debug->("auto: DBI+DBD::SQLite available, using 'dbi'");
	    return 'dbi';
	}
	if (_sqlite_binary()) {
	    $debug->("auto: sqlite binary available, using 'sqlite'");
	    return 'sqlite';
	}
	die "Neither DBI+DBD::SQLite nor a 'sqlite3'/'sqlite' binary in PATH is available.\n" .
	    "Install one of them to use this tool (e.g. 'cpan DBD::SQLite' or install the 'sqlite3' package).\n";
    }

    die "Unhandled method '$method'\n"; # should not happen, validated earlier
}

{
    my $memoized_dbi_available;
    sub _dbi_available {
	return $memoized_dbi_available if defined $memoized_dbi_available;
	$memoized_dbi_available = eval {
	    require DBI;
	    require DBD::SQLite;
	    1;
	} ? 1 : 0;
	return $memoized_dbi_available;
    }
}

{
    my $memoized_sqlite_binary;
    sub _sqlite_binary {
	return $memoized_sqlite_binary if defined $memoized_sqlite_binary;
	$memoized_sqlite_binary = '';
	for my $candidate (qw(sqlite3 sqlite)) {
	    for my $dir (split /\Q$Config::Config{path_sep}\E/, $ENV{PATH} || '') {
		next if !length $dir;
		my $full = "$dir/$candidate";
		if (-x $full && !-d $full) {
		    $memoized_sqlite_binary = $full;
		    last;
		}
	    }
	    last if length $memoized_sqlite_binary;
	}
	return length $memoized_sqlite_binary ? $memoized_sqlite_binary : undef;
    }
}

sub _find_cookie_value_via_dbi {
    my ($temp_db_file, $cookie_name, $host_suffix, $debug) = @_;

    require DBI;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$temp_db_file", "", "", { RaiseError => 1, AutoCommit => 1 })
        or die "Failed to connect to the database $temp_db_file: " . DBI->errstr . "\n";

    my $now = time();
    my $query = "SELECT value FROM moz_cookies WHERE host LIKE ? AND name = ? AND expiry > ? LIMIT 1";
    my $sth = $dbh->prepare($query);
    $sth->execute("%$host_suffix", $cookie_name, $now);
    my ($cookie_value) = $sth->fetchrow_array;
    $sth->finish;

    return $cookie_value;
}

sub _find_cookie_value_via_sqlite_binary {
    my ($temp_db_file, $cookie_name, $host_suffix, $debug) = @_;

    my $sqlite_binary = _sqlite_binary()
	or die "No 'sqlite3'/'sqlite' binary found in PATH.\n";

    my $now = time();
    my $escaped_host    = _sql_quote("%$host_suffix");
    my $escaped_name    = _sql_quote($cookie_name);
    my $query = "SELECT value FROM moz_cookies WHERE host LIKE $escaped_host AND name = $escaped_name AND expiry > $now LIMIT 1;";

    $debug->("running: $sqlite_binary -batch -noheader -list $temp_db_file <query>");

    my @cmd = ($sqlite_binary, '-batch', '-noheader', '-list', $temp_db_file, $query);
    my $output = _run_capture(@cmd);
    if (!defined $output) {
	die "Failed to run '$sqlite_binary' against $temp_db_file\n";
    }

    # -list mode with a single selected column just prints the value per line.
    my ($first_line) = split /\n/, $output, 2;
    return (defined $first_line && length $first_line) ? $first_line : undef;
}

# Minimal single-quote SQL literal escaping (doubling embedded single quotes).
# Fine here because the only inputs are a cookie name and a host suffix, both
# supplied on the command line / by the caller, not untrusted web content.
sub _sql_quote {
    my ($str) = @_;
    $str =~ s/'/''/g;
    return "'$str'";
}

sub _run_capture {
    my (@cmd) = @_;
    require IPC::Open3;
    require Symbol;
    my ($wtr, $rdr, $err) = (Symbol::gensym(), Symbol::gensym(), Symbol::gensym());
    my $pid = eval { IPC::Open3::open3($wtr, $rdr, $err, @cmd) };
    if (!$pid) {
	warn "Failed to execute @cmd: $@\n";
	return undef;
    }
    close $wtr;
    local $/;
    my $stdout = <$rdr>;
    my $stderr = <$err>;
    waitpid $pid, 0;
    my $exit_code = $? >> 8;
    if ($exit_code != 0) {
	warn "Command @cmd failed with exit code $exit_code: " . (defined $stderr ? $stderr : '') . "\n";
	return undef;
    }
    return defined $stdout ? $stdout : '';
}

if (!caller) {
    require Getopt::Long;

    my $usage = sub () {
        die <<EOF
Usage: $0 [--expected-lifetime days] [--debug] [--method auto|dbi|sqlite] <cookie_name> <host_suffix>
       $0 [--expected-lifetime days] [--debug] [--method auto|dbi|sqlite] --for-curl-cookie --host-suffix ... <cookie_name1> <cookie_name2> ...

--method selects how the Firefox cookies.sqlite file is queried:
  auto   - (default) use DBI+DBD::SQLite if available, otherwise fall back
           to a 'sqlite3'/'sqlite' binary in PATH.
  dbi    - require DBI+DBD::SQLite.
  sqlite - require a 'sqlite3'/'sqlite' binary in PATH.
EOF
    };

    Getopt::Long::GetOptions
	    (
	     "debug" => \my $debug,
	     "expected-lifetime=f" => \my $expected_lifetime_in_days,
	     "for-curl-cookie" => \my $for_curl_cookie,
	     "host-suffix=s" => \my $provided_host_suffix,
	     "method=s" => \my $method,
	    )
	    or $usage->();

    if (defined $method && !grep { $method eq $_ } @valid_methods) {
	warn "Invalid --method '$method', must be one of @valid_methods.\n";
	$usage->();
    }

    if ($for_curl_cookie) {
	if (!$provided_host_suffix) {
	    warn "--host-suffix is mandatory with --for-curl-cookie.\n";
	    $usage->();
	}
	if (!@ARGV) {
	    warn "Please specify one or more cookie names.\n";
	    $usage->();
	}
	my @cookie_strings;
	for my $cookie_name (@ARGV) {
	    my $cookie_value = find_cookie_value($cookie_name, $provided_host_suffix, expected_lifetime => $expected_lifetime_in_days, debug => $debug, method => $method);
	    if (defined $cookie_value) {
		push @cookie_strings, "$cookie_name=$cookie_value";
	    } else {
		die "Cannot find cookie $cookie_name.\n";
	    }
	}
	print join("; ", @cookie_strings);
    } else {
	$usage->() if @ARGV != 2;
	my($cookie_name, $host_suffix) = @ARGV;

	my $cookie_value = find_cookie_value($cookie_name, $host_suffix, expected_lifetime => $expected_lifetime_in_days, debug => $debug, method => $method);
	if (defined $cookie_value) {
	    print $cookie_value, "\n";
	    exit 0;
	} else {
	    die "Cannot find cookie.\n";
	}
    }
}

1;
