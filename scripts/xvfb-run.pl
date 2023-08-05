#!/usr/bin/env perl

use strict;
use warnings;

use File::Temp qw(tempdir);
use Getopt::Long;

my $progname = "xvfb-run";
my $servernum = 99;
my $errorfile = "/dev/null";
my $xvfbargs = "-screen 0 640x480x8";
my $listentcp = "-nolisten tcp";
my $xauthproto = ".";

my ($auto_servernum, $auth_file, $help, $listen_tcp);

GetOptions(
    "a|auto-servernum" => \$auto_servernum,
    "e|error-file=s" => \$errorfile,
    "f|auth-file=s" => \$auth_file,
    "h|help" => \$help,
    "n|server-num=i" => \$servernum,
    "l|listen-tcp" => \$listen_tcp,
    "p|xauth-protocol=s" => \$xauthproto,
    "s|server-args=s" => \$xvfbargs,
) or die "Incorrect usage!\n";

my @command = @ARGV;

my $xvfb_run_tmpdir;
my $xvfb_pid;

sub find_free_servernum {
    while (-e "/tmp/.X$servernum-lock") {
        $servernum++;
    }
    return $servernum;
}

sub clean_up {
    if (-e $auth_file) {
        system("XAUTHORITY=$auth_file xauth remove :$servernum >/dev/null 2>&1");
    }

    if (defined $xvfb_pid && $xvfb_pid != 0) {
	#warn "killing $xvfb_pid";
        kill 'TERM', $xvfb_pid;
    }
}

END { clean_up }

if ($auto_servernum) {
    $servernum = find_free_servernum();
}

if (!$auth_file) {
    $xvfb_run_tmpdir = tempdir("$progname.XXXXXX", DIR => '/tmp', CLEANUP => 1);
    $auth_file = "$xvfb_run_tmpdir/Xauthority";
    open my $auth_fh, '>', $auth_file;
    close $auth_fh;
}

my $mcookie = join "", map { sprintf "%02x", int(rand(256)) } 1..16;

{
    my $cmd = qq(XAUTHORITY=$auth_file xauth source - <<EOF >>"$errorfile" 2>&1\nadd :$servernum $xauthproto $mcookie\nEOF);
    system($cmd);
}

$xvfb_pid = fork();
if ($xvfb_pid == 0) {
    my @xvfbargs = split /\s+/, $xvfbargs;
    my @listentcp = split /\s+/, $listentcp;
    my @cmd = ('Xvfb', ":$servernum", @xvfbargs, @listentcp, '-auth', $auth_file); # XXX missing: >>"$errorfile" 2>&1);
    exec(@cmd);
    die "Problem starting '@cmd': $!";
}

sleep(1); # Give Xvfb a chance to start

my $exit_status = do {
    local $ENV{DISPLAY} = ":$servernum";
    local $ENV{XAUTHORITY} = $auth_file;
    system(@command);
};

exit($exit_status >> 8);
