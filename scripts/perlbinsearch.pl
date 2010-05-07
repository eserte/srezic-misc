#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: perlbinsearch.pl,v 1.17 2010/05/07 19:39:03 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

=pod

  git bisect start cb2877ce3cadf472e7e4932c3609b84b04fa46db perl-5.8.8
  git bisect view &
  git bisect run ~/work/srezic-misc/scripts/perlbinsearch.pl 

=cut

use strict;
use File::Basename qw(basename);
use Cwd qw(cwd);
my $perldir = cwd;

my $distribution;
#$distribution = "/usr/local/src/CPAN/build/autorequire-0.08-A3c4FR";
#$distribution = "/usr/local/src/CPAN/build/Attribute-Tie-0.01-HxCk5z";
#$distribution = "/usr/local/src/CPAN/build/Apache-Admin-Config-0.94-nzBcpg";
#$distribution = "/usr/local/src/CPAN/build/MPEG-Audio-Frame-0.09-12dhEG";
#$distribution = "/usr/local/src/CPAN/build/Acme-Oil-0.1-IUxiWf";
#$distribution = "/usr/local/src/CPAN/build/Class-Void-0.05-_REvQg";
#$distribution = "/usr/local/src/CPAN/build/Math-BigSimple-1.1a-0L7war";
#$distribution = "/usr/local/src/CPAN/build/Symbol-Values-1.07-Z93uus";
#$distribution = "/usr/local/src/CPAN/build/IO-Mark-v0.0.1-XXX";
#$distribution = "/usr/local/src/CPAN/build/Crypt-SecurID-0.04";
#$distribution = "/usr/local/src/CPAN/build/Tie-Array-FileWriter-0.1-NWMfS2";
#$distribution = "/usr/local/src/CPAN/build/Devel-SmallProf-2.02-0BwnEE";
#$distribution = "/usr/local/src/CPAN/build/Convert-IBM390-0.25-FPBfEZ";
#$distribution = "/usr/local/src/CPAN/build/Audio-AMR-Decode-0.01-6xodoh";

my $cpanmod;
#$cpanmod = "ex::lib::zip";
#$cpanmod = "HTML::Template::Dumper";
#$cpanmod = "Class::Void";
#$cpanmod = "Apache::Admin::Config";
#$cpanmod = "Class::AutoGenerate";
#$cpanmod = "IO::Mark";
#$cpanmod = "MPEG::Audio::Frame";
#$cpanmod = "Nmap::Scanner";
#$cpanmod = "Crypt::SecurID";
#$cpanmod = "Data::Reuse";
#$cpanmod = "Unicode::Property::XS";
#$cpanmod = "Filter::Include";
$cpanmod = "Convert::Number::Ethiopic";

my $checkcmd;
#$checkcmd = "env PERL5LIB=$perldir/lib make test";
#$checkcmd = "env PERL5LIB=$perldir/lib $perldir/perl -Mblib t/03_autodynaload_hook.t";
#$checkcmd = "env PERL5LIB=$perldir/lib $perldir/perl -Mblib t/02-array.t";
#$checkcmd = "env PERL5LIB=$perldir/lib make test TEST_FILES=t/value.t";
#$checkcmd = "env PERL5LIB=$perldir/lib make test TEST_FILES=t/04-tie.t";
#$checkcmd = "env PERL5LIB=$perldir/lib make test TEST_FILES=t/02-scalar.t";

my $script;
#$script = "/tmp/wah.pl";
#$script = "/tmp/readline.pl";
#$script = "/home/e/eserte/trash/bisect.pl";

my $allow_distroprefs = 0;
#my $allow_distroprefs = 1;

my $cc = "ccache cc";
#my $cc = "ccache gcc34";

my $do_patch_perl = 0;
#my $do_patch_perl = 1;

if ($distribution && $cpanmod ||
    $distribution && $script ||
    $cpanmod && $script) {
    warn "What do you want: distribution directory, script or CPAN mod?";
    exit 258;
}
if (!$distribution && !$cpanmod && !$script) {
    warn "Specify either distribution, script or CPAN mod!";
    exit 259;
}
if ($distribution && !$checkcmd) {
    warn "Distribution without checkcmd specified!";
    exit 260;
}

my $label;
if ($distribution) {
    $label = basename $distribution;
} elsif ($cpanmod) {
    $label = $cpanmod;
} elsif ($script) {
    $label = $script;
}

$SIG{__WARN__} = sub {
    print @_;
    system "xterm-conf", "-f", "-title", "$label: @_";
};

$SIG{INT} = sub {
    warn "User aborted ...";
    exit 257;
};

my $err = 125; # git-bisect skip
RUN: {
    warn "configure.gnu";
    system('./configure.gnu', "-Dcc=$cc", '-Dusedevel=define', '--prefix=/usr/perl.XXX',
	   ## extra stuff following:
	   #'-Dusefaststdio=define',
	  ) == 0 or last RUN;
    if ($do_patch_perl) {
	system("patch --forward < /usr/ports/lang/perl5.8/files/patch-makedepend"); # intentionally ignore exit code
    }
    warn "make";
    system('make', '-j4') == 0 or last RUN;
    if ($script) {
	warn "run script";
	local $ENV{PERL5LIB} = "$perldir/lib";
	system("$perldir/perl",
	       #"-I$perldir/lib",
	       $script,
	      );
	$err = $?==0 ? 0 : 1;
    } elsif ($cpanmod) {
	warn "Testing with CPAN.pm";
	my $cmd = "env PERL5LIB=$perldir/lib $perldir/perl -MCPAN -e '" .
	    q{$cpanmod = "} .
		$cpanmod .
		    q{"; CPAN::HandleConfig->can("load") and CPAN::HandleConfig->load; $CPAN::Config->{test_report} = 0; } .
			(!$allow_distroprefs ? q{$CPAN::Config->{prefs_dir} = undef; } : q{}) .
			    q{test($cpanmod); $success = eval { not CPAN::Shell->expand("Module", "$cpanmod")->distribution->{make_test}->failed }; if ($@) { warn "CPAN.pm problem: $@"; exit 125; }; exit($success ? 0 : 1)';};
	print STDERR $cmd, "\n";
	system($cmd);
	if ($?<<8 == 125) {
	    $err = 125; # skip, CPAN.pm problem
	} else {
	    $err = $?==0 ? 0 : 1;
	}
    } else {
	warn "chdir to cpan dist";
	chdir $distribution or do {
	    $err = 256;
	    warn "Cannot chdir to $distribution: $!";
	    last RUN;
	};
	warn "perl Makefile.PL";
	system("$perldir/perl", "-I$perldir/lib", "Makefile.PL") == 0 or last RUN;
	warn "make $distribution";
	system("make") == 0 or do {
	    $err = 1;
	    warn "error while doing make";
	    last RUN;
	};
	warn "check command: $checkcmd";
	system($checkcmd);
	$err = $?==0 ? 0 : 1;
    }
    warn "error code is $err";
}
warn "final cleanup";
chdir $perldir or do {
    warn "Cannot chdir back to $perldir: $!";
    exit 256;
};
system('make', 'distclean');
system('git', 'clean', '-f', '-d', '-x');
exit $err;

__END__
