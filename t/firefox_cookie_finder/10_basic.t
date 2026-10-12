#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);

use Test::More;

my $script = "$FindBin::RealBin/../../scripts/firefox_cookie_finder.pl";

require $script;

# Find a sqlite3 (or sqlite) binary to build the test fixture database with
# -- independent of whatever method(s) are actually being tested below.
my $fixture_sqlite_binary;
for my $candidate (qw(sqlite3 sqlite)) {
    for my $dir (split /:/, $ENV{PATH} || '') {
	next if !length $dir;
	my $full = "$dir/$candidate";
	if (-x $full && !-d $full) {
	    $fixture_sqlite_binary = $full;
	    last;
	}
    }
    last if $fixture_sqlite_binary;
}

plan skip_all => "No sqlite3/sqlite binary found to build test fixture"
    if !$fixture_sqlite_binary;

my $have_dbi = eval { require DBI; require DBD::SQLite; 1 } ? 1 : 0;
my $have_sqlite_binary = eval { FirefoxCookieFinder::resolve_method('sqlite'); 1 } ? 1 : 0;

diag("DBI+DBD::SQLite available: " . ($have_dbi ? "yes" : "no"));
diag("sqlite3/sqlite binary available: " . ($have_sqlite_binary ? "yes" : "no"));

plan skip_all => "Neither DBI+DBD::SQLite nor a sqlite3/sqlite binary available"
    if !$have_dbi && !$have_sqlite_binary;

my $home_dir = tempdir(CLEANUP => 1);
my $profile_dir = "$home_dir/.mozilla/firefox/abcd1234.default-release";
mkdir_recursive($profile_dir);
my $cookies_sqlite = "$profile_dir/cookies.sqlite";

{
    my $now = time();
    my $future_expiry = $now + 24*60*60;
    my $past_expiry   = $now - 24*60*60;

    my $create_and_insert_sql = <<"SQL";
CREATE TABLE moz_cookies (host TEXT, name TEXT, value TEXT, expiry INTEGER);
INSERT INTO moz_cookies (host, name, value, expiry) VALUES ('www.confluence.idealo.tools', 'cloud.session.token', 'THE-FRESH-TOKEN-VALUE', $future_expiry);
INSERT INTO moz_cookies (host, name, value, expiry) VALUES ('www.confluence.idealo.tools', 'cloud.session.token', 'THE-EXPIRED-TOKEN-VALUE', $past_expiry);
INSERT INTO moz_cookies (host, name, value, expiry) VALUES ('other.example.com', 'cloud.session.token', 'UNRELATED-HOST-VALUE', $future_expiry);
SQL

    run_sqlite_batch($fixture_sqlite_binary, $cookies_sqlite, $create_and_insert_sql);
}

ok -f $cookies_sqlite, "fixture cookies.sqlite was created";

local $ENV{HOME} = $home_dir;

for my $method_to_test (
    ($have_dbi            ? ('dbi')    : ()),
    ($have_sqlite_binary  ? ('sqlite') : ()),
    'auto',
) {
    subtest "method=$method_to_test" => sub {
	my $value = FirefoxCookieFinder::find_cookie_value(
	    'cloud.session.token', 'confluence.idealo.tools',
	    method => $method_to_test,
	);
	is $value, 'THE-FRESH-TOKEN-VALUE', "found the non-expired cookie value";

	my $missing = FirefoxCookieFinder::find_cookie_value(
	    'does-not-exist', 'confluence.idealo.tools',
	    method => $method_to_test,
	);
	is $missing, undef, "unknown cookie name returns undef";
    };
}

subtest 'invalid method is rejected' => sub {
    eval {
	FirefoxCookieFinder::find_cookie_value(
	    'cloud.session.token', 'confluence.idealo.tools',
	    method => 'bogus',
	);
    };
    like $@, qr{Invalid method}, "dies with a clear error for an unknown method";
};

done_testing;

sub mkdir_recursive {
    my ($dir) = @_;
    require File::Path;
    File::Path::make_path($dir);
}

sub run_sqlite_batch {
    my ($sqlite_binary, $db_file, $sql) = @_;
    require IPC::Open3;
    require Symbol;
    my ($wtr, $rdr, $err) = (Symbol::gensym(), Symbol::gensym(), Symbol::gensym());
    my $pid = IPC::Open3::open3($wtr, $rdr, $err, $sqlite_binary, '-batch', $db_file);
    print $wtr $sql;
    close $wtr;
    local $/;
    my $stdout = <$rdr>;
    my $stderr = <$err>;
    waitpid $pid, 0;
    my $exit_code = $? >> 8;
    die "Failed to build test fixture with $sqlite_binary: $stderr" if $exit_code != 0;
}

__END__
