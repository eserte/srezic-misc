use strict;
use warnings;
use FindBin;
use Test::More;

BEGIN {
    if (!eval { use IPC::Run 'run'; 1 }) {
	plan skip_all => 'IPC::Run unavailable';
    }
}

plan 'no_plan';

my $script = "$FindBin::RealBin/../../scripts/sysdeps-of-perl-installation.pl";

SKIP: {
    my @inc_candidates = grep { m{(x86_64|arm|amd)} && -d } @INC; # limit to directories likely to contain .so modules
    skip "No INC candidates found", 1
	if !@inc_candidates;

    {
	my %packages;
	for my $inc (@inc_candidates) {
	    my @cmd = ($script, "--libdir", $inc);
	    ok(run(\@cmd, '>', \my $out), "@cmd runs ok");
	    chomp $out;
	    $packages{$_} = 1 for split /\n/, $out;
	}

	cmp_ok scalar(keys(%packages)), ">", 0, 'found at least one system package';

	diag explain \%packages;
    }

    {
	my %packages;
	for my $inc (@inc_candidates) {
	    my @cmd = ($script, '--libdir', $inc, '--ignore-file-rx', '\.(so|bundle)$');
	    ok(run(\@cmd, '>', \my $out), "@cmd runs ok");
	    chomp $out;
	    $packages{$_} = 1 for split /\n/, $out;
	}

	is_deeply \%packages, {}, '--ignore-file-rx ignored everything'
	    or diag explain \%packages;
	    
    }
}

__END__
