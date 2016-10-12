#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2016 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# If things fail, then maybe the following is missing:
#
#     sudo apt-get install libmagickcore-dev
#

use strict;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use Getopt::Long;

sub mydie ($);
sub yn ();

my %accepted_test_failures = (
			      '6.8.9.9' => {
					    't/mpeg/read.t' => 2,
					    't/read.t'      => 1,
					   }
			     );

my $keep;
GetOptions("keep!" => \$keep)
    or die "usage: $0 [--keep] /path/to/perl\n";

my $perl = shift
    or die "Please specify perl to use (full path)";

if (!-x $perl || !-f $perl) {
    die "'$perl' is not a perl executable";
}

if ($keep) {
    $File::Temp::KEEP_ALL = 1;
}

my $workdir = tempdir("imagemagick-install-XXXXXXXX", TMPDIR => 1, CLEANUP => 1);
chdir $workdir or die $!;

if (!-x '/usr/bin/dpkg-source') {
    my @cmd = ('apt-get', 'install', 'dpkg-dev');
    if ($< != 0) {
	unshift @cmd, 'sudo';
    }
    system @cmd;
    $? == 0 or warn "Installing dpkg-dev failed, probably next steps will fail.\n";
}

system('apt-get', 'source', 'perlmagick');
$? == 0 or mydie <<'EOF';
Fetching source failed

Maybe a fitting deb-src entry is missing in sources.list?
Try to add something like the following on ubuntu/mint systems:

    deb-src http://archive.ubuntu.com/ubuntu/ trusty main restricted universe multiverse

or

    deb-src http://archive.ubuntu.com/ubuntu/ precise main restricted universe multiverse

Followed by calling

    apt-get update

EOF

my($imagemagick_PerlMagick_dir) = glob("imagemagick-*/PerlMagick");
if (!$imagemagick_PerlMagick_dir || !-d $imagemagick_PerlMagick_dir) {
    mydie "Cannot find PerlMagick directory";
}

my $imagemagick_dir = dirname($imagemagick_PerlMagick_dir);
chdir $imagemagick_dir
    or mydie "Cannot chdir to $imagemagick_dir: $!";

my($imagemagick_version) = $imagemagick_dir =~ m{imagemagick-(.*)};

my $PerlMagick_dir = "PerlMagick";

# Do we have a modern, quantum-enabled ImageMagick (debian/jessie and
# newer)?
my $has_quantum_imagemagick = -d "$PerlMagick_dir/quantum";

if ($has_quantum_imagemagick) {
    # Replace .in files early
    system($^X, '-i.bak', '-pe', 's{-lperl}{}; s{\Q-L../magick/.libs}{};', "$PerlMagick_dir/Makefile.PL.in");
    $? == 0 or mydie "Patching PerlMagick/Makefile.PL.in failed";
    system($^X, '-i.bak', '-pe', 's{-lperl}{}; s{\Q-L../../magick/.libs}{};', "$PerlMagick_dir/quantum/Makefile.PL.in");
    $? == 0 or mydie "Patching PerlMagick/quantum/Makefile.PL.in failed";

    system './configure', "--with-perl=$perl";
    $? == 0 or mydie "configure step failed";
    system 'make', 'perl-sources';
    $? == 0 or mydie "make step failed";
}

chdir $PerlMagick_dir
    or mydie "Cannot chdir to $PerlMagick_dir: $!";

if (!-e "typemap") {
    warn "Create a dummy typemap...\n";
    open my $ofh, ">", "typemap"
	or die "Can't create typemap: $!";
    print $ofh <<'EOF';
Image::Magick T_PTROBJ
EOF
    close $ofh
	or die "Error while writing typemap: $!";
}

if (!$has_quantum_imagemagick) {
    system($^X, '-i.bak', '-pe', 's{-lperl}{}', 'Makefile.PL');
    $? == 0 or mydie "Patching Makefile.PL failed";
}

system($perl, 'Makefile.PL');
$? == 0 or mydie "Running Makefile.PL failed";

if ($has_quantum_imagemagick) {
    system($^X, '-i.bak', '-pe', 's{^LD_RUN_PATH *=.*}{}', 'Makefile');
    $? == 0 or mydie "Patching Makefile failed";
    system($^X, '-i.bak', '-pe', 's{^LD_RUN_PATH *=.*}{}', 'quantum/Makefile');
    $? == 0 or mydie "Patching quantum/Makefile failed";
}

system('make', 'all');
$? == 0 or mydie "Building failed";

{
    my @test_cmd = ('make', 'test');
    open my $fh, "-|", @test_cmd
	or die "Failure while running '@test_cmd': $!";
    my %test_failures;
    while(<$fh>) {
	print $_;
	if (m{^(\S+).*Wstat: \d+ Tests: \d+ Failed: (\d+)}) {
	    $test_failures{$1} = $2;
	}
    }
    close $fh;

    if ($? != 0) {
    AUTO_ACCEPT_TEST_FAILURES: {
	    if (!%test_failures) {
		print STDERR "Possible parse problem: test failed, but no test failures were parsed\n";
	    } else {
		my $this_accepted_test_failures = $accepted_test_failures{$imagemagick_version};
		if (!$this_accepted_test_failures) {
		    print STDERR "No accepted test failures for this version ($imagemagick_version)\n";
		} else {
		    for my $test_script (keys %test_failures) {
			if (exists $this_accepted_test_failures->{$test_script}) {
			    if ($this_accepted_test_failures->{$test_script} == $test_failures{$test_script}) {
				delete $test_failures{$test_script};
			    } else {
				print STDERR "Unexpected number of test failures in script '$test_script': expected $this_accepted_test_failures->{$test_script}, got $test_failures{$test_script}\n";
			    }
			} else {
			    print STDERR "Test failures in '$test_script' are not expected.\n";
			}
		    }
		    if (!%test_failures) {
			print STDERR "All test failures are known and accepted, continue with installation...\n";
			last AUTO_ACCEPT_TEST_FAILURES;
		    }
		}
	    }
	
	    print STDERR "Test failed. Continue (y/n)? ";
	    yn();
	}
    }
}

{
    my @install_cmd = ('make', 'install');
    my $perl_owner_uid = (stat($perl))[4];
    if (!defined $perl_owner_uid) {
	die "Unexpected: cannot get owner of '$perl': $!";
    }
    if ($perl_owner_uid == $<) {
	# no sudo necessary
    } else {
	unshift @install_cmd, 'sudo', '-u', '#'.$perl_owner_uid;
    }

    print STDERR "Running '@install_cmd'...\n";
    system @install_cmd;
    $? == 0 or mydie "Installation failed";
}

chdir "/"; # so temporary directories may be removed

sub yn () {
    while() {
	chomp(my $yn = <STDIN>);
	if ($yn eq 'y') {
	    last;
	} elsif ($yn eq 'n') {
	    exit 1;
	} else {
	    warn "Please answer y or n!\n";
	}
    }
}

sub mydie ($) {
    my $msg = shift;
    $File::Temp::KEEP_ALL = 1;
    die $msg;
}
__END__
