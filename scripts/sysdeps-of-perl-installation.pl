#!/usr/bin/perl

use strict;
use warnings;
use Cwd qw(realpath);
use File::Find;
use File::Spec;
use Getopt::Long;

my $libdir;
my $debug;
my $with_cache;
my $debian_method = 'dpkg_query';
my @ignore_file_rxs;

sub debug ($) { warn "DEBUG: $_[0]\n" if $debug }

sub apt_file_find ($;$) {
    my $file = shift;
    my $for = shift;
    my @packages;
    (my $qr = $file) =~ s{\+}{\\+}g;
    my @cmd = (
	'apt-file', 'search', '--package-only', '--regexp', '^'.$qr.'$',
	#'^'.quotemeta($file).'$' # XXX does not work; backslash before / disturbs
    );
    debug "@cmd...";
    open my $fh, '-|', @cmd
	or die $!;
    while(<$fh>) {
	chomp;
	push @packages, $_;
    }
    if (!@packages) {
	my $msg = "WARN: cannot find anything while running '@cmd'...";
	if ($for) {
	    $msg .= " (required for $for->[0] ...)";
	}
	warn "$msg\n";
    }
    @packages;
}

sub dpkg_query ($;$) {
    my $file = shift;
    my $for = shift;

    my @tried_cmds;

    my $raw_dpkg_query = sub ($) {
	my($file) = @_;
	my @cmd = (
	    'dpkg-query', '-S', $file,
	);
	debug "@cmd...";
	open my $olderr, ">&", \*STDERR or die $!;
	open STDERR, ">", File::Spec->devnull or die $!;
	open my $fh, '-|', @cmd or die $!;
	push @tried_cmds, \@cmd;
	my @packages;
	while(<$fh>) {
	    chomp;
	    if (my($package) = $_ =~ m{^([^:]+)}) {
		push @packages, $package;
	    } else {
		warn "WARN: cannot parse line <$_>";
	    }
	}
	open STDERR, ">&", $olderr or die $!;
	@packages;
    };

    my @packages = $raw_dpkg_query->($file);
    if (!@packages && $file =~ m{^(/(lib|usr/lib)(|32|64|x32)/)}) {
	# On some systems (e.g. Ubuntu 20.04) there are symlinks /lib
	# -> /usr/lib etc. which also needs to be checked
	my $try_file;
	if ($file =~ m{^/lib}) {
	    ($try_file = $file) =~ s{^/lib}{/usr/lib};
	} else {
	    ($try_file = $file) =~ s{^/usr/lib}{/lib};
	}
	@packages = $raw_dpkg_query->($try_file);
    }

    if (!@packages) {
	my $msg = "WARN: cannot find anything while running " . join(", ", map { qq{'@$_'} } @tried_cmds) . "...";
	if ($for) {
	    $msg .= " (required for $for->[0] ...)";
	}
	warn "$msg\n";
    }
    @packages;
}

{
    my $brew_prefix;
    sub _get_brew_prefix () {
	if (!defined $brew_prefix) {
	    chomp($brew_prefix = `brew --prefix`);
	    if (!defined $brew_prefix || $brew_prefix eq '') {
		warn "WARN: no result running 'brew --prefix', fallback to '/usr/local'...\n";
		$brew_prefix = '/usr/local';
	    }
	}
	$brew_prefix;
    }
}

sub brew_file_find ($;$) {
    my $file = shift;
    my $for = shift;
    my @packages;
    my $brew_prefix = _get_brew_prefix;
    if ($file =~ m{^\Q$brew_prefix\E/Cellar/([^/]+)}) {
	push @packages, $1;
    } else {
	my $msg = "WARN: don't know what to do with '$file'";
	if ($for) {
	    $msg .= " (required for $for->[0])";
	}
	warn "$msg\n";
    }
    @packages;
}

GetOptions(
    "libdir=s" => \$libdir,
    "debug"    => \$debug,
    "with-cache" => \$with_cache,
    "debian-method=s" => \$debian_method,
    'ignore-file-rx=s@' => \@ignore_file_rxs,
)
    or die "usage: $0 [--debug] [--with-cache] [--libdir libdir] [--debian-method apt_file_find|dpkg_query] [--ignore-file-rx ...] [perldir]\n";

for (@ignore_file_rxs) {
    $_ = qr{$_};
}

if (!$libdir) {
    my $perldir = shift
	or die "perldir?";
    $libdir = realpath "$perldir/lib";
}
my $real_libdir = realpath $libdir;


my @do_unmemoize;
if ($with_cache) {
    if ($^O eq 'linux' && $debian_method eq 'apt_file_find') { # apt-file is very slow, caching is worth here
	require Memoize;
	require Memoize::Storable;
	my $cache_dir = "$ENV{HOME}/.cache";
	mkdir $cache_dir if !-d $cache_dir;
	my $cache_file = "$cache_dir/apt_file_find.cache.st";
	if (-e $cache_file && -z $cache_file) { # may happen if Memoize::Storable crashes while writing
	    unlink $cache_file;
	}
	tie my %cache => 'Memoize::Storable', $cache_file;
	Memoize::memoize(
	    'apt_file_find',
	    LIST_CACHE => ['HASH' => \%cache],
	    NORMALIZER => sub { $_[0] }, # ignore optional $for argument
	);
	push @do_unmemoize, 'apt_file_find';
    }
}

my $ignore_file_sub = sub ($) {
    my $f = shift;
    for my $rx (@ignore_file_rxs) {
	if ($f =~ $rx) {
	    debug "Ignore $f because of --ignore-file-rx $rx";
	    return 1;
	}
    }
    0;
};

my %sodeps;
my %sorevdeps;
if ($^O eq 'darwin') {
    find(sub {
	     if (-f $_ && m{\.bundle$}) {
		 return if $ignore_file_sub->($File::Find::name);
		 debug "Check .bundle $File::Find::name...";
		 open my $fh, '-|', 'otool', '-L', $File::Find::name
		     or die $!;
		 while(<$fh>) {
		     if (m{^\s+(\S+)}) {
			 my $dylib = realpath $1;
			 if (!defined $dylib) {
			     warn "Can't resolve $1 -> library missing? Found in $File::Find::name\n";
			 } else {
			     if (index($dylib, $real_libdir) == 0) {
				 # within perl installation - ignore
			     } elsif ($dylib =~ m{^( /usr/lib
						  |  /opt/X11/lib
						  |  /System/Library/Frameworks
						  )/}x) {
				 # system libraries - ignore
			     } else {
				 push @{ $sodeps{$File::Find::name} }, $dylib;
				 push @{ $sorevdeps{$dylib} }, $File::Find::name;
			     }
			 }
		     }
		 }
	     }
	 }, $libdir);
} else {
    find(sub {
	     if (-f $_ && m{\.so$}) {
		 return if $ignore_file_sub->($File::Find::name);
		 debug "Check .so $File::Find::name...";
		 open my $fh, '-|', 'ldd', $File::Find::name
		     or die $!;
		 while(<$fh>) {
		     if (m{.*\s+=>\s+(\S+)\s+\(0x[0-9a-f]+\)$}) {
			 my $so = realpath $1;
			 if (!defined $so) {
			     warn "Can't resolve $1 -> library missing? Found in $File::Find::name\n";
			 } else {
			     if (index($so, $real_libdir) == 0) {
				 # ignore
			     } else {
				 push @{ $sodeps{$File::Find::name} }, $so;
				 push @{ $sorevdeps{$so} }, $File::Find::name;
			     }
			 }
		     }
		 }
	     }
	 }, $libdir);
}

$| = 1; # because apt-file is slow
my %seen_package;
for my $so (keys %sorevdeps) {
    my $output_package = sub ($) {
	my $package = shift;
	if (!$seen_package{$package}) {
	    print $package, "\n";
	    $seen_package{$package} = 1;
	}
    };
    debug "Check dependent library $so...";
    my @so_packages;
    if ($^O eq 'darwin') {
	@so_packages = brew_file_find $so, $sorevdeps{$so};
    } else { # XXX actually only Debian
	if      ($debian_method eq 'apt_file_find') {
	    @so_packages = apt_file_find $so, $sorevdeps{$so};
	} elsif ($debian_method eq 'dpkg_query') {
	    @so_packages = dpkg_query $so, $sorevdeps{$so};
	} else {
	    die "Invalid debian method '$debian_method'";
	}
    }
    if (!@so_packages) {
	## already warned
	#warn "WARN: Cannot find a package for $so\n";
    } else {
	if (@so_packages > 1) {
	    my($so_package) = sort { length($a) <=> length($b) } @so_packages;
	    warn "INFO: found multiple packages for $so (@so_packages), choosing with shortest name: $so_package\n"; # XXX not good solution
	    $output_package->($so_package);
	} else {
	    $output_package->($so_packages[0]);
	}
    }
}

# Hack suggested in http://www.perlmonks.org/?node_id=802002
# Otherwise segfaults are possible (e.g. with debian/wheezy's system perl 5.14.2)
for (@do_unmemoize) {
    Memoize::unmemoize($_);
}

__END__

=head1 NAME

sysdeps-of-perl-installation.pl - list system packages needed for a perl installation

=head1 SYNOPSIS

    sysdeps-of-perl-installation.pl [--debug] [--with-cache] [--libdir libdir] [--debian-method apt_file_find|dpkg_query] [perldir]

=head1 DESCRIPTION

Scan C<@INC> of the given perl directory or libdir, try to find all
system dependencies and print the associated package names.

Currently, system dependencies are only determined by scanning shared
object files. Other runtime dependencies, especially required external
programs or scripts, are not detected.

Supported OSs are Debian and Mac OS X.

=head2 OPTIONS

=over

=item C<--debug>

Print some debugging to STDERR.

=item C<--with-cache>

Use a persistent cache for found module -> package mappings. This is
currently used only if C<apt_file_find> is used on Debian systems. The
cache file is stored below F<~/.cache>.

=item C<< --libdir I<path> >>

Use an alternative library path than a given perl directory.

=item C<--debian-method apt_file_find|dpkg_query>

Define the method for finding suitable packages for shared objects:
either C<dpkg_query> for using L<dpkg-query(1)> (default), or
C<apt_file_find> for using L<apt-file(1)>.

=item C<< --ignore-file-rx I<rx> >>

Specify a regular expression to ignore any matching C<.so> or
C<.bundle> file. This option can be used multiple times.

=back

=head1 TODO

Some perl modules have also non-shared objects, which are not
supported. One possibility would be to maintain a static mapping
(module -> package).

=head1 AUTHOR

Slaven Rezic

=cut
