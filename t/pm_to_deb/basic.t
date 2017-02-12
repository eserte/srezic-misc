#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Test::More;

plan skip_all => "Not on a debian system or apt-file unavailable?" if !is_in_path('apt-file');
plan 'no_plan';

my $pm_to_db = "$FindBin::RealBin/../../scripts/pm-to-deb";

{
    my $out = `$^X $pm_to_db Moose`;
    is $out, "libmoose-perl\n", 'found package for Moose';
}

{
    my $out = `$^X $pm_to_db This::Module::Does::Not::Exist 2>&1`;
    is $out, "Cannot find package for This::Module::Does::Not::Exist\n", 'error message for non-existing package';
}

# REPO BEGIN
# REPO NAME is_in_path /home/eserte/src/srezic-repository 
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
# REPO NAME file_name_is_absolute /home/eserte/src/srezic-repository 
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
