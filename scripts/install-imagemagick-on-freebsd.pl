#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2014,2015,2016 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Status as of 2016-01-03: may or may not work.
#
# It works on a FreeBSD 9.2 system with ImageMagick-6.8.9.10_1,1
# installed.
#
# It may or may not work for newer ImageMagick versions. 6.9.0 did not
# (see below), newer versions not yet tested.
#
# Status as of 2015-01-10: currently broken.
#
# On FreeBSD 10.1, compilation with a non-threaded perl is successful,
# but almost all tests fail, most with an error messages like
#
#    Readimage (input.jpg): Exception 455: unable to load module `/usr/local/lib/ImageMagick-6.9.0//modules-Q16/coders/jpeg.la': file not found @ error/module.c/OpenModule/1282 at t/subroutines.pl line 690.
#
# On FreeBSD 9.2, already the non-perl part fails:
#
#    magick/distribute-cache.c: In function 'DestroyDistributeCacheInfo':
#    magick/distribute-cache.c:389: warning: implicit declaration of function 'CLOSE_SOCKET'
#    magick/distribute-cache.c: At top level:
#    magick/distribute-cache.c:751: error: expected '=', ',', ';', 'asm' or '__attribute__' before 'DistributePixelCacheClient'
#    Makefile:8461: recipe for target 'magick/magick_libMagickCore_6_Q16_la-distribute-cache.lo' failed
#    gmake[1]: *** [magick/magick_libMagickCore_6_Q16_la-distribute-cache.lo] Error 1

use strict;

use Getopt::Long;
use POSIX qw(strftime);

sub yn ();

my $svn_imagemagick_url = 'http://svn.freebsd.org/ports/head/graphics/ImageMagick';
my $svn_makefile_url    = "$svn_imagemagick_url/Makefile";

# portversion => { testscript => number_of_failures, ... }
my %accepted_test_failures = ('6.8.0-7' => {'t/montage.t' => 19},
			      '6.8.9-10' => {'t/mpeg/read.t' => 1, # these two tests also need user interaction (pressing q in window)
					     't/mpeg/read.t' => 2,
					    }
			     );
# portversion => [ sub { ...patch ... }, .... ]
# note: currently not available in --complete-build mode (which is default)
my %additional_patches = ();

# Previously the default was "/usr/ports/graphics/ImageMagick"
# but nowadays we checkout the matching directory from SVN
my $imagemagick_port_directory;
# Recent ImageMagick with Q16 (?) support obviously need a
# full build of ImageMagick :-(
my $do_complete_build = 1;
GetOptions(
	   'port-dir|port-directory=s' => \$imagemagick_port_directory,
	   'complete-build!'           => \$do_complete_build,
	  )
    or die "usage: $0 [--port-dir ...] [--no-complete-build] perl";

my $perl = shift
    or die "Please specify perl to use (full path)";

if (!-x $perl) {
    die "'$perl' is not a perl executable";
}

if (!$imagemagick_port_directory) {
    $imagemagick_port_directory = checkout_matching_imagemagick_port();
} elsif (!-d $imagemagick_port_directory) {
    die "The given directory $imagemagick_port_directory. Ports not checked out?";
}

# do we need to run sudo?
my $need_sudo = 0;
if (!-w $imagemagick_port_directory) {
    $need_sudo = 1;
}
chdir $imagemagick_port_directory
    or die "Can't chdir to $imagemagick_port_directory: $!";

my $image_magick_version = `display --version`;
if (!$image_magick_version) {
    die "ImageMagick not yet installed?";
}
if (($image_magick_version) = $image_magick_version =~ m{Version: ImageMagick (\S+)}) {
    # ok
} else {
    die "Cannot parse ImageMagick version from '$image_magick_version'";
}

my $port_version = `make -VDISTFILES`;
if (($port_version) = $port_version =~ m{^ImageMagick-(.*)\.tar\.}) {
    # ok
} else {
    die "Cannot parse port version from '$port_version'";
}

if ($image_magick_version ne $port_version) {
    print STDERR "Currently installed ImageMagick and port versions do not match: $image_magick_version != $port_version. Continue (y/n)? ";
    yn();
}

if (!is_in_path('dialog4ports')) { # required for "make config" step in port
    print STDERR "Install required dialog4ports package (y/n)? ";
    yn();
    system 'sudo', 'pkg', 'install', 'dialog4ports';
    if (!is_in_path('dialog4ports')) {
	die "Installation of dialog4ports seems to have failed";
    }
}

if (-d "work") {
    if (!-w "work") {
	$need_sudo = 1;
    }
    maybe_sudo('make', 'clean');
}

my $perl_magick_work_dir = "work/ImageMagick-$port_version/PerlMagick";
if ($do_complete_build) {
    maybe_sudo('make', "PERL=$perl");
    chdir $perl_magick_work_dir
	or die "Can't chdir to $perl_magick_work_dir: $!";
} else {
    maybe_sudo('make', 'patch');
    chdir $perl_magick_work_dir
	or die "Can't chdir to $perl_magick_work_dir: $!";
    my $additional_patches = $additional_patches{$port_version};
    if ($additional_patches) {
	print STDERR "Running additional patches for $port_version... ";
	for my $additional_patch (@$additional_patches) {
	    $additional_patch->();
	}
	print STDERR "done\n";
    }
    maybe_sudo($perl, 'Makefile.PL');
    maybe_sudo('make', 'all');
}

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

######################################################################
# Checking out from FreeBSD's ports svn

sub get_svn_revisions {
    require XML::LibXML;

    my $log_xml = do {
	open my $fh, '-|', 'svn', 'log', '--xml', $svn_makefile_url
	    or die $!;
	local $/;
	<$fh>;
    };
    my $p = XML::LibXML->new;
    my $doc = $p->parse_string($log_xml);
    my @revisions;
    for my $rev_node ($doc->findnodes('/log/logentry/@revision')) {
	push @revisions, $rev_node->findvalue('.');
    }
    @revisions;
}

sub get_distversion {
    my($svn_revision) = @_;
    open my $fh, '-|', 'svn', 'cat', '-r', $svn_revision, $svn_makefile_url
	or die $!;
    while(<$fh>) {
	if (m{^\s*DISTVERSION=\s*(\S+)}) {
	    return $1;
	}
    }
    die "Cannot find DISTVERSION in $svn_makefile_url revision $svn_revision";
}

sub get_current_imagemagick_pkg_version {
    my @cmd = ('pkg', 'query', '%v', 'ImageMagick');
    open my $fh, '-|', @cmd
	or die $!;
    chomp(my $pkg_version = <$fh>);
    close $fh
	or die "Error running @cmd: $!\nMaybe ImageMagick is not installed at all?";
    if (!$pkg_version) {
	die "Cannot get version for ImageMagick --- maybe it's not installed?";
    }
    $pkg_version;
}

sub pkg_version_to_distversion {
    my($pkg_version) = @_;
    $pkg_version =~ s{,\d+$}{}; # PORTEPOCH?
    $pkg_version =~ s{_\d+$}{}; # PORTREVISION?
    $pkg_version =~ s{\.(\d+)$}{-$1}g; # normalize
    $pkg_version; # well, now it's a DISTVERSION...
}

sub find_matching_svn_revision {
    my $pkg_version = get_current_imagemagick_pkg_version();
    my $distversion = pkg_version_to_distversion($pkg_version);
    print STDERR "Current ImageMagick version: $pkg_version (DISTVERSION=$distversion)\n";
    print STDERR "Get list of SVN revisions... ";
    my @svn_revisions = get_svn_revisions();
    print STDERR "done\n";
    my $matching_svn_revision;
    for my $svn_revision (@svn_revisions) {
	print STDERR "Check SVN revision $svn_revision... ";
	my $this_distversion = get_distversion($svn_revision);
	if ($this_distversion eq $distversion) {
	    print STDERR "found $this_distversion\n";
	    $matching_svn_revision = $svn_revision;
	    last;
	} else {
	    print STDERR "non-matching $this_distversion\n";
	}
    }
    if (!$matching_svn_revision) {
	die "Cannot find $distversion in svn revisions (@svn_revisions)";
    }
    $matching_svn_revision;
}

sub checkout_matching_imagemagick_port {
    my $matching_svn_revision = find_matching_svn_revision();

    require File::Temp;
    my $tempdir = File::Temp::tempdir('PerlMagick-' . strftime('%F', localtime) . '-XXXXXXXX', TMPDIR => 1); # don't cleanup for easier debugging
    print STDERR "Temporary directory: $tempdir\n";
    chdir $tempdir
	or die "Can't chdir to $tempdir: $!";
    system 'svn', 'co', '-r', $matching_svn_revision, $svn_imagemagick_url;
    if ($? != 0) {
	die "Cannot checkout $svn_imagemagick_url: $!";
    }

    "$tempdir/ImageMagick";
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/srezic-repository 
# REPO MD5 e18e6687a056e4a3cbcea4496aaaa1db

=head2 is_in_path($prog)

=for category File

Return the pathname of $prog, if the program is in the PATH, or undef
otherwise.

DEPENDENCY: file_name_is_absolute

=cut

sub is_in_path {
    my($prog) = @_;
    if (file_name_is_absolute($prog)) {
	if ($^O eq 'MSWin32') {
	    return $prog       if (-f $prog && -x $prog);
	    return "$prog.bat" if (-f "$prog.bat" && -x "$prog.bat");
	    return "$prog.com" if (-f "$prog.com" && -x "$prog.com");
	    return "$prog.exe" if (-f "$prog.exe" && -x "$prog.exe");
	    return "$prog.cmd" if (-f "$prog.cmd" && -x "$prog.cmd");
	} else {
	    return $prog if -f $prog and -x $prog;
	}
    }
    require Config;
    %Config::Config = %Config::Config if 0; # cease -w
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    # maybe use $ENV{PATHEXT} like maybe_command in ExtUtils/MM_Win32.pm?
	    return "$_\\$prog"     if (-f "$_\\$prog" && -x "$_\\$prog");
	    return "$_\\$prog.bat" if (-f "$_\\$prog.bat" && -x "$_\\$prog.bat");
	    return "$_\\$prog.com" if (-f "$_\\$prog.com" && -x "$_\\$prog.com");
	    return "$_\\$prog.exe" if (-f "$_\\$prog.exe" && -x "$_\\$prog.exe");
	    return "$_\\$prog.cmd" if (-f "$_\\$prog.cmd" && -x "$_\\$prog.cmd");
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/srezic-repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8

=head2 file_name_is_absolute($file)

=for category File

Return true, if supplied file name is absolute. This is only necessary
for older perls where File::Spec is not part of the system.

=cut

BEGIN {
    if (eval { require File::Spec; defined &File::Spec::file_name_is_absolute }) {
	*file_name_is_absolute = \&File::Spec::file_name_is_absolute;
    } else {
	*file_name_is_absolute = sub {
	    my $file = shift;
	    my $r;
	    if ($^O eq 'MSWin32') {
		$r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	    } else {
		$r = ($file =~ m|^/|);
	    }
	    $r;
	};
    }
}
# REPO END

__END__
