#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2015,2016 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Config;
use File::Find;
use Getopt::Long;

my $v = 0;
my $doit;
my @ignorerxs;
GetOptions(
	   "v+" => \$v,
	   'q|quiet' => sub { $v = -1 },
	   "doit" => \$doit,
	   'ignorerx=s@' => \@ignorerxs,
	  )
    or die "usage: $0 [-v] [-doit] [-ignorerx rx ...]";

if ($doit && !has_cpan_smoke_modules_cmd()) {
    die "Sorry, -doit is only possible if cpan_smoke_modules is available";
}

for my $ignorerx (@ignorerxs) {
    $ignorerx = qr{$ignorerx};
}

my @search_libs = $Config{'sitearch'};

my %seen;
my %broken_module;
my %so_not_found;

my $ext = $^O eq 'darwin' ? 'bundle' : 'so';

if ($^O eq 'darwin') {
    print STDERR "Completely untested for MacOSX. Press RETURN to continue. ";
    <STDIN>;    
}

for my $search_lib (@search_libs) {
    if (!-d $search_lib) {
	print STDERR "INFO: skipping non-existent search lib path '$search_lib'\n" if $v >= 0;
    } elsif ($^O eq 'darwin') {
	File::Find::find({wanted => \&wanted_darwin}, $search_lib);
    } else {
	File::Find::find({wanted => \&wanted}, $search_lib);
    }
}

if (%so_not_found) {
    print STDERR "The following .$ext could not be found:\n";
    for my $so (sort keys %so_not_found) {
	print STDERR "  $so (used in: " . join(', ', sort keys %{$so_not_found{$so}}) . ")\n";
    }
    print STDERR "\n";
}

# Remove some exceptions
for my $mod (
	     'Text::BibTeX', # libbtparse is installed under perl/lib
	     'HTML::Gumbo', # missing .so is in share/dist/Alien-LibGumbo/lib/libgumbo.so.1, LD_LIBRARY_PATH tricks?
	     'Judy', # libJudy is in .../Alien/Judy/libJudy.so.1, LD_LIBRARY_PATH tricks?
	     'Vmprobe::Cache', 'Vmprobe::Cache::Snapshot', # deleted from CPAN, only at BackPAN: https://metacpan.org/release/FRACTAL/Vmprobe-v0.1.5
	     # XXX scheinen doch "echte" Fehler zu sein --- qw(SVN::_Client SVN::_Core SVN::_Delta SVN::_Fs SVN::_Ra SVN::_Repos SVN::_Wc), # also LD_LIBRARY_PATH tricks?
	    ) {
    if (exists $broken_module{$mod}) {
	print STDERR "INFO: removing false positive $mod from list\n" if $v >= 0;
	delete $broken_module{$mod};
    }
}

if (@ignorerxs) {
    for my $mod (keys %broken_module) {
	for my $ignorerx (@ignorerxs) {
	    if ($mod =~ $ignorerx) {
		print STDERR "INFO: remove $mod from list (matching --ignorerx param $ignorerx)\n" if $v >= 0;
		delete $broken_module{$mod};
		last;
	    }
	}
    }
}

if (%broken_module) {
    my $cpan_smoke_modules_cmd = has_cpan_smoke_modules_cmd();
    my @broken_list = sort keys %broken_module;
    print STDERR "Try now:\n\n";
    if ($cpan_smoke_modules_cmd) {
	my @cmd = ($cpan_smoke_modules_cmd, '-noreport', '-perl', $^X, '-reinstall', @broken_list);
	print STDERR <<EOF;
    @cmd
EOF
	if ($doit) {
	    system @cmd;
	    if ($? != 0) {
		warn "Something failed while re-installing the modules...\n";
	    }
	}
    } else {
	print STDERR <<EOF;
    $^X -MCPAN -eshell
    test @broken_list
    install_tested
EOF
    }
    print STDERR "\n";
} else {
    print STDERR "No broken .$ext files found in @search_libs\n";
}

sub wanted {
    if (-f $_ && m{\.so\z} && !$seen{$File::Find::name}) {
	my $res = `ldd $File::Find::name 2>&1`;
	if ($res =~ m{not found}) {
	    (my $module = $File::Find::name) =~ s{/[^/]+$}{};
	    $module =~ s{.*/auto/}{};
	    $module =~ s{/}{::}g;
	    $broken_module{$module} = 1;
	    if ($v >= 1) {
		while ($res =~ m{^\s+(.*?)\s+=>.*not found}gm) {
		    $so_not_found{$1}->{$File::Find::name} = 1;
		}
	    }
	}
	$seen{$File::Find::name} = 1;
    }
}

# XXX completely untested, probably does not work!
sub wanted_darwin {
    if (-f $_ && m{\.bundle\z} && !$seen{$File::Find::name}) {
	my $res = `otool -L $File::Find::name 2>&1`;
	if ($res =~ m{not found}) {
	    (my $module = $File::Find::name) =~ s{/[^/]+$}{};
	    $module =~ s{.*/auto/}{};
	    $module =~ s{/}{::}g;
	    $broken_module{$module} = 1;
	    if ($v >= 1) {
		while ($res =~ m{^\s+(.*?)\s+=>.*not found}gm) {
		    $so_not_found{$1}->{$File::Find::name} = 1;
		}
	    }
	    warn "$module -> $res"; # XXX
	}
	$seen{$File::Find::name} = 1;
    }
}

sub has_cpan_smoke_modules_cmd {
    my $cpan_smoke_modules_cmd;
    if (is_in_path('cpan_smoke_modules')) {
	$cpan_smoke_modules_cmd = 'cpan_smoke_modules';
    } else {
	my $candidate = "$ENV{HOME}/src/srezic-misc/scripts/cpan_smoke_modules";
	if (-x $candidate) {
	    $cpan_smoke_modules_cmd = $candidate;
	}
    }
    if ($cpan_smoke_modules_cmd) {
	$cpan_smoke_modules_cmd;
    } else {
	undef;
    }
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
    require File::Spec;
    if (File::Spec->file_name_is_absolute($prog)) {
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

__END__

=head1 EXAMPLES

    for perl in /usr/perl5.*/bin/perl; do echo "---> $perl"; $perl /tmp/find-broken-perl-so.pl -doit; done

    for perl in /opt/perl*/bin/perl; do echo "---> $perl"; $perl /tmp/find-broken-perl-so.pl -doit; done

=head1 BUGS

This script should do some kind of dependency ordering. If for example
openssl was updated, then first Net::SSLeay should be updated,
followed by other modules possibly using both openssl and Net::SSLeay.

=cut
