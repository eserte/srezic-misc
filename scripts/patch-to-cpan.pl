#!/usr/bin/perl
# -*- cperl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
our $VERSION = 0.001;

use File::Copy qw(cp);
use File::Temp qw(tempdir);
use Getopt::Long;
use LWP::UserAgent;

my $rt;
my $patch_url;
my $dist;
my $distver;

sub usage (;$) {
    my $msg = shift;
    if ($msg) {
	warn "$msg\n";
    }
    die "usage: $0 -rt ... -patch ... -dist ... -ver ...\n";
}

sub yn () {
    while () {
        chomp(my $yn = <STDIN>);
        if ($yn eq 'n') {
            return 0;
        } elsif ($yn ne 'y') {
            warn "Please answer 'y' or 'n'!\n";
        } else {
            return 1;
        }
    }
}

GetOptions(
	   "rt=i"    => \$rt,
	   "patch=s" => \$patch_url,
	   "dist=s"  => \$dist,
	   "ver=s"   => \$distver,
	  )
    or usage;

$rt        or usage "-rt option with RT ticket number is missing";
$patch_url or usage "-patch option with URL to patch file is missing";
$dist      or usage "-dist option with distribution name (not module name) is missing";
$distver   or usage "-ver option with distribution version is missing";

my $patch_file = "$dist-$distver-RT$rt.patch";
print STDERR "Does this name for the patch file looks reasonable?

    $patch_file

(y/n) ";

if (!yn) {
    print "OK, exiting...\n";
    exit 1;
}

my $dir = tempdir("patch-to-cpan-XXXXXXXX", TMPDIR => 1, CLEANUP => 1)
    or die "Can't create temporary directory: $!";

my $dest_patch_file = "$dir/$patch_file";

if (-r $patch_url) {
    cp $patch_url, $dest_patch_file
	or die "Cannot copy $patch_url to $dest_patch_file: $!";
} else {
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->get($patch_url, ':content_file' => $dest_patch_file);
    if (!$resp->is_success) {
	die "No success fetch $patch_url to $dest_patch_file: " . $resp->as_string;
    }
}

print STDERR "Contents of $dest_patch_file\n";
print STDERR "="x70,"\n";
system('cat', $dest_patch_file);
print STDERR "="x70,"\n";

my @cmd = ("/opt/perl/bin/cpan-upload", "-d", "patches", $dest_patch_file);
print STDERR "Execute @cmd? (y/n) ";
if (!yn) {
    print "OK, exiting...\n";
    exit 1;
}

system @cmd;
warn "@cmd failed" if $? != 0;

show_upload_url();

sub show_upload_url {
    if (open my $fh, "$ENV{HOME}/.pause") {
        my $user;
        while(<$fh>) {
            chomp;
            if (m{^user\s+(\S+)}) {
                $user = $1;
                last;
            }
        }
        if ($user) {
            $user = uc $user;
            my($user2, $user1) = $user =~ m{^((.).)};
            my $desturl = 'http://cpan.cpantesters.org/authors/id/' . $user1 . '/' . $user2 . '/' . $user . '/patches/' . $patch_file;
            print STDERR "Patch file will appear at: $desturl\n";
        }
    }
}

__END__

=head1 NAME

patch-to-cpan.pl - transfer a patch to CPAN

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=cut

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# indent-tabs-mode: nil
# End:
# vim:sw=4:ts=8:sta:et
