#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin;

use Test::More;
use Time::Local qw(timegm);

plan skip_all => 'Time::Fake and IPC::Run required for tests' if !eval { require Time::Fake; require IPC::Run; 1 };
plan 'no_plan';

my $script = "$FindBin::RealBin/../../scripts/dst-wrapper";

sub get_env_for_epoch ($) {
    my $epoch = shift;
    my $offset = $epoch - time;
    $offset = "+$offset" if $offset >= 0;
    ("PERL5OPT" => "-MTime::Fake=${offset}s", "TZ" => "Europe/Berlin");
}

my %env_for_std = get_env_for_epoch(timegm(0,0,0,1,1-1,2022));
my %env_for_dst = get_env_for_epoch(timegm(0,0,0,1,8-1,2021));

my @portable_cmd = ($^X, '-e', 'print "hello, world\n"');

{
    local %ENV = %env_for_std;

    {
	ok IPC::Run::run([$^X, $script,             @portable_cmd], '>', \my $output), 'simulate standard time, and it should run (default without options)';
	is $output, "hello, world\n";
    }

    {
	ok IPC::Run::run([$^X, $script, '--on-std', @portable_cmd], '>', \my $output), 'simulate standard time, and it should run';
	is $output, "hello, world\n";
    }

    {
	ok IPC::Run::run([$^X, $script, '--on-dst', @portable_cmd], '>', \my $output), 'simulate standard time, and it should not run';
	is $output, '';
    }

    {
	alarm 60; # just in case
	ok IPC::Run::run([$^X, $script, '--sleep-if-dst', @portable_cmd], '>', \my $output), 'simulate standard time, using --sleep-if-dst';
	alarm 0;
	is $output, "hello, world\n";
    }
}

{
    local %ENV = %env_for_dst;

    {
	ok IPC::Run::run([$^X, $script,             @portable_cmd], '>', \my $output), 'simulate DST, and it should not run (default without options)';
	is $output, '';
    }

    {
	ok IPC::Run::run([$^X, $script, '--on-std', @portable_cmd], '>', \my $output), 'simulate DST, and it should not run';
	is $output, '';
    }

    {
	ok IPC::Run::run([$^X, $script, '--on-dst', @portable_cmd], '>', \my $output), 'simulate DST, and it should run';
	is $output, "hello, world\n";
    }

    {
	alarm 60; # just in case
	my $h = IPC::Run::start([$^X, $script, '--sleep-if-dst', '--debug', @portable_cmd], '>', \my $output, '2>', \my $stderr, IPC::Run::timeout(30));
	ok $h, "simulate DST, using --sleep-if-dst";
	$h->pump until $stderr =~ /sleep.*because of DST/;
	$h->kill_kill;
	alarm 0;
	like $stderr, qr{sleep 3600s because of DST};
	is $output, '';
    }
}

__END__
