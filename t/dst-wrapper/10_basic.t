#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin;

use Test::More;

plan skip_all => 'IPC::Run required for tests' if !eval { require IPC::Run; 1 };
plan 'no_plan';

my $script = "$FindBin::RealBin/../../scripts/dst-wrapper";

{
    ok !IPC::Run::run([$script], '2>', \my $error), 'no command at all';
    like $error, qr{Command is missing};
}

{
    ok !IPC::Run::run([$script, '--'], '2>', \my $error), 'just option separator without command';
    like $error, qr{Command is missing};
}

my @portable_cmd = ($^X, '-e', 'print "hello, world\n"');

{
    for my $opt_def ([], ['--on-dst'], ['--on-std']) {
	ok IPC::Run::run([$script, @$opt_def, @portable_cmd], '>', \my $output, '2>', \my $error), "run (or not) command with options: " . (!@$opt_def ? "(none)" : "@$opt_def");
	is $error, '';
    }
}

{
    for my $opt_def ([], ['--on-dst'], ['--on-std']) {
	ok IPC::Run::run([$script, '--debug', @$opt_def, @portable_cmd], '>', \my $output, '2>', \my $error), "run (or not) command with options: --debug @$opt_def";
	like $error, qr{command .* (should not run|will now run) \(is_dst=(0|1) run_on_dst=(0|1)\)\n};
    }
}

__END__
