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
use Config;
use File::Find;
use Getopt::Long;

my $v;
GetOptions("v+" => \$v)
    or die "usage: $0 [-v]";

my @search_libs = $Config{'sitearch'};

my %seen;
my %broken_module;
my %so_not_found;

for my $search_lib (@search_libs) {
    File::Find::find({wanted => \&wanted}, $search_lib);
}

if (%so_not_found) {
    print STDERR "The following .so could not be found:\n";
    for my $so (sort keys %so_not_found) {
	print STDERR "  $so (used in: " . join(', ', sort keys %{$so_not_found{$so}}) . ")\n";
    }
    print STDERR "\n";
}

# Remove some exceptions
for my $mod (
	     'Text::BibTeX', # libbtparse is installed under perl/lib
	    ) {
    if (exists $broken_module{$mod}) {
	print STDERR "INFO: removing false positive $mod from list\n";
	delete $broken_module{$mod};
    }
}

if (%broken_module) {
    my $broken_list = join(" ", sort keys %broken_module);
    print STDERR <<EOF;
Try now:

    $^X -MCPAN -eshell
    test $broken_list
    install_tested

EOF
} else {
    print STDERR "No broken .so files found in @search_libs\n";
}

sub wanted {
    if (-f $_ && m{\.so\z} && !$seen{$File::Find::name}) {
	my $res = `ldd $File::Find::name 2>&1`;
	if ($res =~ m{not found}) {
	    (my $module = $File::Find::name) =~ s{/[^/]+$}{};
	    $module =~ s{.*/auto/}{};
	    $module =~ s{/}{::}g;
	    $broken_module{$module} = 1;
	    if ($v) {
		while ($res =~ m{^\s+(.*?)\s+=>.*not found}gm) {
		    $so_not_found{$1}->{$File::Find::name} = 1;
		}
	    }
	}
	$seen{$File::Find::name} = 1;
    }
}


__END__
