# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2016 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package CtrGetReportsFastReader;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

my $inline_dir;
BEGIN {
    $inline_dir = "$ENV{HOME}/.cache/CtrGetReportsFastReader";
    if (!-d $inline_dir) {
	require File::Path;
	File::Path::mkpath($inline_dir);
    }
}

use Inline C => 'DATA',
           directory => $inline_dir,
;

1;

__DATA__
__C__

#include <fcntl.h>
#include <sys/types.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFLEN 40960
void get_matching_entries(SV* dir_sv, SV* search_sv) {
    char *dir = SvPV(dir_sv, PL_na);
    char *search = SvPV(search_sv, PL_na);
    int fd = open(dir, O_RDONLY);
    if (fd < 0) {
	croak("Cannot open directory %s", dir);
    }
    Inline_Stack_Vars;
    Inline_Stack_Reset;
    char buf[BUFLEN];
    int got;
    while((got = getdents(fd, buf, BUFLEN)) > 0) {
	struct dirent *ent = (struct dirent*)buf;
	while((long)ent-(long)buf < got) {
	    if (strstr(ent->d_name, search) != NULL) {
		Inline_Stack_Push(newSVpv(ent->d_name, 0));
	    }
	    ent = (struct dirent*)((long)ent + ent->d_reclen);
	}
    }
    Inline_Stack_Done;
}
