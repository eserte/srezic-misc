#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use File::Temp qw(tempdir);

sub mydie ($);

my $perl = shift
    or die "Please specify perl to use (full path)";

if (!-x $perl || !-f $perl) {
    die "'$perl' is not a perl executable";
}

my $workdir = tempdir("imagemagick-install-XXXXXXXX", TMPDIR => 1, CLEANUP => 1);
chdir $workdir or die $!;

system('apt-get', 'source', 'perlmagick');
$? == 0 or mydie <<'EOF';
Fetching source failed

Maybe a fitting deb-src entry is missing in sources.list?
Try to add something like the following on ubuntu/mint systems:

    deb-src http://archive.ubuntu.com/ubuntu/ precise main restricted universe multiverse

EOF

my($PerlMagick_dir) = glob("imagemagick-*/PerlMagick");
if (!$PerlMagick_dir || !-d $PerlMagick_dir) {
    mydie "Cannot find PerlMagick directory";
}
chdir $PerlMagick_dir
    or mydie "Cannot chdir to $PerlMagick_dir: $!";

system($^X, '-i.bak', '-pe', 's{-lperl}{}', 'Makefile.PL');
$? == 0 or mydie "Patching Makefile.PL failed";

system($perl, 'Makefile.PL');
$? == 0 or mydie "Running Makefile.PL failed";

system('make', 'all', 'test');
$? == 0 or mydie "Building or testing failed";

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

sub mydie ($) {
    my $msg = shift;
    $File::Temp::KEEP_ALL = 1;
    die $msg;
}
__END__
