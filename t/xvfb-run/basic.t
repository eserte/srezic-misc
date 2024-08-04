#!/usr/bin/perl -w
# -*- cperl -*-

use strict;
use warnings;
use FindBin;

use Getopt::Long;
use Test::More 'no_plan';

my $script = "$FindBin::RealBin/../../scripts/xvfb-run.pl";

GetOptions("run-original" => \my $run_original)
    or die "usage: $0 [--run-original]\n";

system $^X, '-c', $script;
is $?, 0, "$script compiles";

if ($run_original) {
    $script = "xvfb-run";
}

SKIP: {
    my $no_tests = 5;
    skip "IPC::Run required", $no_tests if !eval { require IPC::Run; 1 };
    skip "Tk required", $no_tests if !module_exists('Tk');

    ok IPC::Run::run([$script, $^X, '-MTk', '-e1']), 'running a simple Tk script works'; # no output here
    ok !IPC::Run::run([$script, $^X, '-e', 'exit 1']), 'program errors are propagated';

    my($stdout, $stderr);
    ok IPC::Run::run([$script, $^X, '-MTk', '-e', '$mw = tkinit; $mw->Label(-text => "hello")->pack; $mw->update; warn "tk script is running (stderr)"; print "tk script is running (stdout)\n"'],
		     '>', \$stdout, '2>', \$stderr), 'real Tk script works';
    like $stderr, qr{tk script is running \(stderr\)}, 'stderr is intercepted';
    like $stdout, qr{tk script is running \(stdout\)}, 'stdout is intercepted';
}

# REPO BEGIN
# REPO NAME module_exists /home/e/eserte/src/srezic-repository 
# REPO MD5 1ea9ee163b35d379d89136c18389b022
sub module_exists {
    my($filename) = @_;
    $filename =~ s{::}{/}g;
    $filename .= ".pm";
    return 1 if $INC{$filename};
    foreach my $prefix (@INC) {
	my $realfilename = "$prefix/$filename";
	if (-r $realfilename) {
	    return 1;
	}
    }
    return 0;
}
# REPO END

__END__
