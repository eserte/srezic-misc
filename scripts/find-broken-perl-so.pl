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

my @search_libs = $Config{'sitearch'};

my %seen;
my %broken_module;

for my $search_lib (@search_libs) {
    File::Find::find({wanted => \&wanted}, $search_lib);
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
	}
	$seen{$File::Find::name} = 1;
    }
}


__END__
