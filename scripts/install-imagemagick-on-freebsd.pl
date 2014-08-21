#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;

sub yn ();

# portversion => { testscript => number_of_failures, ... }
my %accepted_test_failures = ('6.8.0-7' => {'t/montage.t' => 19});

my $perl = shift
    or die "Please specify perl to use (full path)";

if (!-x $perl) {
    die "'$perl' is not a perl executable";
}

my $imagemagick_port_directory = "/usr/ports/graphics/ImageMagick";
if (!-d $imagemagick_port_directory) {
    die "/usr/ports/graphics/ImageMagick is missing. Ports not checked out? Not on a FreeBSD system?";
}

# do we need to run sudo?
my $need_sudo = 0;
if (!-w $imagemagick_port_directory) {
    $need_sudo = 1;
}
chdir $imagemagick_port_directory
    or die $!;

my $image_magick_version = `display --version`;
if (!$image_magick_version) {
    die "ImageMagick not yet installed?";
}
if (($image_magick_version) = $image_magick_version =~ m{Version: ImageMagick (\S+)}) {
    # ok
} else {
    die "Cannot parse ImageMagick version from '$image_magick_version'";
}

my $port_version = `make -f /usr/ports/graphics/ImageMagick/Makefile -VDISTFILES`;
if (($port_version) = $port_version =~ m{^ImageMagick-(.*)\.tar\.}) {
    # ok
} else {
    die "Cannot parse port version from '$port_version'";
}

if ($image_magick_version ne $port_version) {
    print STDERR "Currently installed ImageMagick and port versions do not match: $image_magick_version != $port_version. Continue (y/n)? ";
    yn();
}

if (-d "work") {
    if (!-w "work") {
	$need_sudo = 1;
    }
    maybe_sudo('make', 'clean');
}

maybe_sudo('make', 'patch');
my $perl_magick_work_dir = "work/ImageMagick-$port_version/PerlMagick";
chdir $perl_magick_work_dir
    or die "Can't chdir to $perl_magick_work_dir: $!";

maybe_sudo($perl, 'Makefile.PL');
maybe_sudo('make', 'all');

{
    my @test_cmd = maybe_sudo_cmd('make', 'test');
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
		my $this_accepted_test_failures = $accepted_test_failures{$port_version};
		if (!$this_accepted_test_failures) {
		    print STDERR "No accepted test failures for this version ($port_version)\n";
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
}

sub maybe_sudo {
    my(@cmd) = @_;
    @cmd = maybe_sudo_cmd(@cmd);
    system @cmd;
    die "'@cmd' failed" if $? != 0;
}

sub maybe_sudo_cmd {
    my(@cmd) = @_;
    if ($need_sudo) {
	@cmd = ('sudo', @cmd);
    }
    @cmd;
}

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

__END__
