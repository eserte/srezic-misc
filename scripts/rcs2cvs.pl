#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: rcs2cvs.pl,v 1.1 2007/07/08 18:12:05 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use VCS;
use File::Basename;

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
GetOptions("n" => sub { $do_exec = 0 }) or die "usage!";

# VCS::Rcs assumes that every file in the given directory is RCS-controlled
my $old = VCS::Dir->new("vcs://localhost/VCS::Rcs/home/e/eserte/trash/bench2");
my $new = VCS::Dir->new("vcs://localhost/VCS::Cvs/home/e/eserte/trash/perl-bench");

copy_vcs($old, $new);

sub copy_vcs {
    my($old, $new) = @_;
    for my $o ($old->content) {
	if ($o->isa("VCS::Dir")) {
	    die "NYI";
	} else {
	    my($dir, $base) = ($new->path, basename($o->path));
	    chdir $dir or die "Can't chdir to $dir: $!";
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
