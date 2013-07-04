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
my $github;
my $patch_url;
my $dist;
my $distver;

sub usage (;$) {
    my $msg = shift;
    if ($msg) {
	warn "$msg\n";
    }
    die "usage: $0 [-rt ...|-github ...] -patch ... -dist ... -ver ...\n";
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
           "github=i" => \$github,
	   "patch=s" => \$patch_url,
	   "dist=s"  => \$dist,
	   "ver=s"   => \$distver,
	  )
    or usage;

if ($rt && $github) {
    usage "Use either -rt or -github, not both";
} elsif (!$rt && !$github) {
    usage "-rt option with RT ticket number or -github with github issue number is missing";
}
$patch_url or usage "-patch option with URL to patch file is missing";
$dist      or usage "-dist option with distribution name (not module name) is missing";
$distver   or usage "-ver option with distribution version is missing";

my $patch_file = "$dist-$distver-" . ($rt ? "RT$rt" : "github$github") . ".patch";
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

my $cpan_upload = 'cpan-upload';
if (!is_in_path($cpan_upload)) {
    # last ressort, try /opt/perl
    $cpan_upload = '/opt/perl/bin/cpan-upload';
    if (!-x $cpan_upload) {
	die "cpan-upload does not seem to be available, cannot upload $dest_patch_file\n";
    }
}
my @cmd = ($cpan_upload, "-d", "patches", $dest_patch_file);
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
            my $destdir = 'http://cpan.cpantesters.org/authors/id/' . $user1 . '/' . $user2 . '/' . $user . '/patches/';
            my $desturl = $destdir . $patch_file;
            print STDERR <<EOF
Patch file will appear at: $desturl
Directory listing: $destdir?C=M;O=D
EOF
        }
    }
}

# REPO BEGIN
# REPO NAME is_in_path /home/slavenr/work2/srezic-repository 
# REPO MD5 e18e6687a056e4a3cbcea4496aaaa1db
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
# REPO NAME file_name_is_absolute /home/slavenr/work2/srezic-repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8
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

=head1 NAME

patch-to-cpan.pl - transfer a patch to CPAN

=head1 SYNOPSIS

    patch-to-cpan.pl -rt 12345 -patch http://host/path/to/patch -name Dist-Name -ver 1.2.3
    patch-to-cpan.pl -github 2 -patch http://host/path/to/patch -name Dist-Name -ver 1.2.3

=head1 PREREQUISITES

=over

=item * L<cpan-upload> installed

=item * F<~/.pause> configured at least with the C<user> name

=item * a "patches" subdirectory in the user's PAUSE directory

=back

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=cut

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# indent-tabs-mode: nil
# End:
# vim:sw=4:ts=8:sta:et
