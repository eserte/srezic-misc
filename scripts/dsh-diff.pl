#!/usr/bin/perl
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
our $VERSION = 0.001;

use File::Temp qw(tempfile);
use Getopt::Long;
use IPC::Run qw(run);

my(@dsh_files, @dsh_groups, @hosts, $reference_host);
GetOptions('f=s@' => \@dsh_files,
	   'g=s@' => \@dsh_groups,
           'h|host=s@' => \@hosts,
	   "ref|reference=s" => \$reference_host,
	  )
    or die "usage?";
@ARGV == 1 or die "usage? Need exactly one file to diff!";
my $file_to_diff = shift @ARGV;

my(@other_hosts);
if (@dsh_groups) {
    for my $dsh_group (@dsh_groups) {
        push @dsh_files, "$ENV{HOME}/.dsh/group/$dsh_group";
    }
}
if (@dsh_files) {
    for my $dsh_file (@dsh_files) {
        open my $fh, $dsh_file
            or die "Can't open $dsh_file: $!";
        while(<$fh>) {
            chomp;
            push @other_hosts, $_;
        }
    }
}
push @other_hosts, @hosts;
if (!defined $reference_host) {
    $reference_host = shift @other_hosts;
} else {
    @other_hosts = grep { $_ ne $reference_host } @other_hosts;
}

if (!@other_hosts) {
    die "Other hosts are empty. Did you specify -f, -g, or -h?";
}
if (!$reference_host) {
    die "Cannot find a first host, maybe the group file @dsh_files is empty?";
}

my($tmp2fh,$principal_file) = tempfile(UNLINK => 1)
    or die $!;
my @cmd = ("ssh", "-o", "ClearAllForwardings=yes", $reference_host, "cat $file_to_diff");
open my $sshfh, "-|", @cmd
    or die $!;
while(<$sshfh>) {
    print $tmp2fh $_;
}
close $sshfh
    or die "While running '@cmd': $?";
close $tmp2fh
    or die $!;

print "="x70, "\n";
print "=== $reference_host (reference)\n";

for my $other_host (@other_hosts) {
    print "="x70, "\n";
    print "=== $other_host\n";
    my @cmd = ("ssh", "-o", "ClearAllForwardings=yes", $other_host, "diff -I '\$HeadURL:' -I '\$Id:' -u - $file_to_diff");
    my $success = run [@cmd], "<", $principal_file;
    ## No: a diff run with diffs exists with status!=0
    # if (!$success) {
    # 	warn "No success running '@cmd'";
    # }
}

__END__

=head1 NAME

dsh-diff.pl - make a diff over multiple hosts

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=cut
