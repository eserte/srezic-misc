#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: rcs2cvs.pl,v 1.4 2007/07/08 18:12:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# The target CVS directory must already exist and already CVS-controlled.
# There's no support for branches or such.
# The file's description won't be copied.
# No support for non-linear version increments.

use VCS;
use File::Basename;
use File::Spec;

# REPO BEGIN
# REPO NAME system_or_print /home/e/eserte/src/repository 
# REPO MD5 077305e5aeadf69bc092419e95b33d14

=head2 system_or_print(cmd, param1, ...)

=for category System

If the global variable $do_exec is set to a true value, then execute the
given command with its parameters, otherwise print the command string to
standard error. If Tk is running and there is a LogWindow, then the command
string is logged to this widget.

=cut

use vars qw($do_exec); # our in 5.6.0

sub system_or_print {
    my(@cmd) = @_;

    my $log_window;
    if (defined &Tk::MainWindow::Existing) {
	my($mw) = Tk::MainWindow::Existing();
	if (defined $mw and
	    Tk::Exists($mw->{LogWindow})) {
	    $log_window = $mw->{LogWindow};
	}
    }
    if ($log_window) {
	$log_window->insert('end', join(" ", @cmd));
	$log_window->see('end');
	$log_window->update;
    }

    if ($do_exec) {
	system @cmd;
    } else {
	print STDERR join(" ", @cmd), "\n";
	$? = 0;
    }
}
# REPO END

use Getopt::Long;

$do_exec = 1;
# XXX -n only works for flat directories
GetOptions("n" => sub { $do_exec = 0 }) or die "usage!";

my $old_dir = shift || die "Old RCS directory?";
my $new_dir = shift || die "New RCS directory?";

$old_dir = File::Spec->rel2abs($old_dir)
    if !File::Spec->file_name_is_absolute($old_dir);
$new_dir = File::Spec->rel2abs($new_dir)
    if !File::Spec->file_name_is_absolute($new_dir);

# VCS::Rcs assumes that every file in the given directory is RCS-controlled
my $old = VCS::Dir->new("vcs://localhost/VCS::Rcs" . $old_dir);
my $new = VCS::Dir->new("vcs://localhost/VCS::Cvs" . $new_dir);

copy_vcs($old, $new);

sub copy_vcs {
    my($old, $new) = @_;
    for my $o ($old->content) {
	my $dir = $new->path;
	chdir $dir or die "Can't chdir to $dir: $!";
	if ($o->isa("VCS::Dir")) {
	    (my $base = $o->path) =~ s{/+$}{};
	    $base = basename $base;
	    if (!$do_exec) {
		print STDERR "mkdir $base...\n";
		print STDERR "cvs add $base...\n";
	    } else {
		if (!-d $base) {
		    mkdir $base or die "Can't create $base: $!";
		    system("cvs", "add", $base);
		    die "Can't add $base" if $? != 0;
		}
	    }
	    copy_vcs(VCS::Dir->new($old->url . "/$base"),
		     VCS::Dir->new($new->url . "/$base"));
	} else {
	    my $base = basename($o->path);
	    if (-e $base) {
		print STDERR "Skipping $base...\n";
		next;
	    }
	    my $first = 1;
	    for my $v ($o->versions) {
		my $text = $v->text;
		if (!$do_exec) {
		    print STDERR "Write to $dir/$base...\n";
		} else {
		    open(my $OUT, "> $base") or die $!;
		    binmode $OUT;
		    print $OUT $text;
		    close $OUT;
		}

		if ($first) {
		    system_or_print("cvs", "add", $base);
		    die "Can't add $base" if $? != 0;
		    $first = 0;
		}

		system_or_print("cvs", "commit", "-m", $v->reason, $base);
		die "Can't commit $base version " . $v->version if $? != 0;
	    }
	}
    }
}

__END__
