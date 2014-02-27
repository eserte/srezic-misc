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

my $perl = shift
    or die "Please specify perl to use (full path)";

if (!-x $perl) {
    die "'$perl' is not a perl executable";

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
    die "Currently installed ImageMagick and port versions do not match: $image_magick_version != $port_version";
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
eval { maybe_sudo('make', 'test') };
if ($@) {
    print STDERR "Test failed. Continue (y/n)? ";
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

system 'sudo', 'make', 'install';

sub maybe_sudo {
    my(@cmd) = @_;
    if ($need_sudo) {
	@cmd = ('sudo', @cmd);
    }
    system @cmd;
    die "'@cmd' failed" if $? != 0;
}

__END__
