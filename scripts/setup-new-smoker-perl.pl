#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use File::Basename qw(basename);
use File::Path qw(mkpath);
use File::Temp qw(tempfile);
use Getopt::Long;

use autodie qw(:all);

sub save_pwd2 ();
sub step ($%);
sub sudo (@);

sub check_term_title ();
sub set_term_title ($);

my $perlver;
my $build_debug;
my $build_threads;
my $morebits;
my $for_cpansand;
my $use_patchperl;
my $patchperl_path;
my $jobs;
my $download_url;
GetOptions(
	   "perlver=s" => \$perlver,
	   "debug"     => \$build_debug,
	   "threads"   => \$build_threads,
	   "morebits"  => \$morebits,
	   "cpansand"  => \$for_cpansand,
	   "patchperl" => \$use_patchperl,
	   "patchperlpath=s" => \$patchperl_path,
	   "j|jobs=i" => \$jobs,
	   "downloadurl=s" => \$download_url,
	  )
    or die "usage: $0 [-debug] [-threads] [-morebits] [-cpansand] [-jobs ...] [-patchperl | -patchperlpath /path/to/patchperl] -downloadurl ... | -perlver 5.X.Y\n";

if (!$perlver && $download_url) {
    if ($download_url =~ m{/perl-(5\.\d+\.\d+(?:-RC\d+)?)\.tar\.(?:gz|bz2)$}) {
	$perlver = $1;
	print STDERR "Guess perl version from download URL: $perlver\n";
    }
}

if (!$perlver) {
    die "-perlver is mandatory";
}

if ($perlver !~ m{^5\.\d+\.\d+(-RC\d+)?$}) {
    die "'$perlver' does not look like a perl5 version";
}

if ($use_patchperl && !defined $patchperl_path) {
    $patchperl_path = "$ENV{HOME}/bin/pistachio-perl/bin/patchperl";
}
if (defined $patchperl_path && !-x $patchperl_path) {
    die "patchperl script '$patchperl_path' is not available";
}

check_term_title;
set_term_title "Setup new smoker perl $perlver";

my $perldir = "/usr/perl$perlver";
if ($^O eq 'linux') {
    $perldir = "/opt/perl-$perlver";
}
if ($build_debug)   { $perldir .= "d" }
if ($build_threads) { $perldir .= "t" }

my $sudo_validator_pid;
sudo 'echo', 'Initialized sudo password';

my $original_download_directory = my $download_directory = "/usr/ports/distfiles";
if (!-d $download_directory) {
    $download_directory = "/tmp";
    if ($^O eq 'freebsd') {
	# may happen if no port installation was done ever
	warn "$original_download_directory not yet created? Adjusting download directory to $download_directory\n";
    } else {
	warn "Not on a FreeBSD system? Adjusting download directory to $download_directory\n";
    }
}
if (!-w $download_directory) {
    $download_directory = "/tmp";
    warn "Download directory '$original_download_directory' is not writable, fallback to '$download_directory'\n";
}
my $srezic_misc = "$ENV{HOME}/src/srezic-misc";
if (!-d $srezic_misc) {
    $srezic_misc = "$ENV{HOME}/work/srezic-misc";
    if (!-d $srezic_misc) {
	warn "* WARN: srezic-misc directory not found, install will very probably fail!\n";
    }
}

my $perl_tar_gz  = "perl-$perlver.tar.gz";
my $perl_tar_bz2 = "perl-$perlver.tar.bz2";
my $downloaded_perl_gz  = "$download_directory/$perl_tar_gz";
my $downloaded_perl_bz2 = "$download_directory/$perl_tar_bz2";
my $downloaded_perl;
if (-f $downloaded_perl_bz2 && -s $downloaded_perl_bz2) {
    $downloaded_perl = $downloaded_perl_bz2;
} else {
    $downloaded_perl = $downloaded_perl_gz;
}
if (!defined $download_url) {
    $download_url = "http://www.cpan.org/src/5.0/$perl_tar_gz"; # XXX only .gz
} else {
    basename($download_url) eq $perl_tar_gz
	or die "Unexpected download URL '$download_url' does not match expected basename '$perl_tar_gz'";
}

# Possibly interactive, so do it first
my $cpan_myconfig = "$ENV{HOME}/.cpan/CPAN/MyConfig.pm";
step "CPAN/MyConfig.pm exists",
    ensure => sub {
	-s $cpan_myconfig
    },
    using => sub {
	if (!-e $cpan_myconfig) {
	    my $cpan_myconfig_dir = dirname($cpan_myconfig);
	    mkpath $cpan_myconfig_dir if !-d $cpan_myconfig_dir;
	    open my $ofh, ">", $cpan_myconfig;
	    my $conf_contents = <<'EOF';
$CPAN::Config = {
  'colorize_output' => q[1],
  'colorize_print' => q[blue],
  'colorize_warn' => q[bold red],
  'index_expire' => q[0.05],
  'make_install_make_command' => q[sudo /usr/bin/make],
  'mbuild_install_build_command' => q[sudo ./Build],
  'prefs_dir' => q[__HOME__/.cpan/prefs],
  'test_report' => q[1],
  'urllist' => [q[http://cpan.cpantesters.org/], q[http://cpan.develooper.com/], q[ftp://ftp.funet.fi/pub/CPAN]],
};
1;
__END__
EOF
	    $conf_contents =~ s{__HOME__}{$ENV{HOME}};
	    print $ofh $conf_contents;
	    require CPAN;
	    CPAN::HandleConfig->load;
	}
    };

my $cpanreporter_config_ini = "$ENV{HOME}/.cpanreporter/config.ini";
step ".cpanreporter/config.ini exists",
    ensure => sub {
	-s $cpanreporter_config_ini
    },
    using => sub {
	if (!-e $cpanreporter_config_ini) {
	    my $cpanreporter_config_ini_dir = dirname($cpanreporter_config_ini);
	    mkpath $cpanreporter_config_ini_dir if !-d $cpanreporter_config_ini_dir;
	    open my $ofh, ">", $cpanreporter_config_ini;
	    my $conf_contents = <<'EOF';
edit_report=default:no
email_from=srezic@cpan.org
send_report=default:yes fail:ask/yes
transport = Metabase uri http://metabase.cpantesters.org/beta/ id_file /home/e/eserte/.cpanreporter/srezic_metabase_id.json
EOF
	    print $ofh $conf_contents;
	}
    };

step "Download perl $perlver",
    ensure => sub {
	-f $downloaded_perl && -s $downloaded_perl
    },
    using => sub {
	my $save_pwd = save_pwd2;
	chdir $download_directory;
	my $tmp_perl_tar_gz = $perl_tar_gz.".~".$$."~";
	system 'wget', "-O", $tmp_perl_tar_gz, $download_url;
	rename $tmp_perl_tar_gz, $perl_tar_gz;
    };

my $src_dir = "/usr/local/src";
if (!-d $src_dir || !-w $src_dir) {
    $src_dir = "/tmp";
    warn "/usr/local/src missing, adjusting src dir to $src_dir\n";
}
my $perl_src_dir = "$src_dir/perl-$perlver";
step "Extract in $src_dir",
    ensure => sub {
	-f "$perl_src_dir/.extracted";
    },
    using => sub {
	my $save_pwd = save_pwd2;
	chdir $src_dir;
	system "tar", "xf", $downloaded_perl;
	system "touch", "$perl_src_dir/.extracted";
    };

if (defined $patchperl_path) {
    step "Patch perl",
	ensure => sub {
	    -f "$perl_src_dir/.patched";
	},
	using => sub {
	    my $save_pwd = save_pwd2;
	    chdir $perl_src_dir;
	    system $patchperl_path;
	    system "touch", ".patched";
	};
}

my $built_file = "$perl_src_dir/.built" . ($build_debug || $build_threads ? "_" . ($build_debug ? "d" : "") . ($build_threads ? "t" : "") : "");
step "Build perl",
    ensure => sub {
	-x "$perl_src_dir/perl" && -f $built_file;
    },
    using => sub {
	my $save_pwd = save_pwd2;
	for my $looks_like_built (glob(".built*")) {
	    unlink $looks_like_built;
	}
	chdir $perl_src_dir;
	if (-e "$ENV{HOME}/FreeBSD/perl/build") {
	    my @build_cmd = (
			     'nice', "$ENV{HOME}/FreeBSD/perl/build",
			     '-prefix' => $perldir,
			     ($build_debug ? "-debug" : ()),
			     ($build_threads ? "-threads" : ()),
			     ($morebits ? "-morebits" : ()),
			    );
	    system @build_cmd;
	} else {
	    my $need_usedevel;
	    if ($perlver =~ m{^5\.(\d+)} && $1 >= 7 && $1%2 == 1) {
		$need_usedevel = 1;
	    }
	    my @build_cmd = (
			     "nice ./configure.gnu --prefix=$perldir" .
			     ($need_usedevel ? ' -Dusedevel -Dusemallocwrap=no' : '') .
			     ($build_debug ? ' -DDEBUGGING' : '') .
			     ($build_threads ? ' -Dusethreads' : '') .
			     ($morebits ? die("No support for morebits") : ()) .
			     ' && make' . ($jobs>1 ? " -j$jobs" : '') . ' all'
			    );
	    system @build_cmd;
	    if (!eval {
		local $ENV{TEST_JOBS};
		$ENV{TEST_JOBS} = $jobs if $jobs > 1;
		system 'make', 'test';
		1;
	    }) {
		while () {
		    print STDERR "make test failed. Continue nevertheless? (y/n) ";
		    chomp(my $yn = <STDIN>);
		    if ($yn eq 'y') {
			last;
		    } elsif ($yn eq 'n') {
			die "Aborting.\n";
		    } else {
			print STDERR "Please reply either y or n.\n";
		    }
		}
	    }
	}
	system "touch", $built_file;
    };

my $state_dir = "$perldir/.install_state";
step "Install perl",
    ensure => sub {
	-d $perldir && -f "$state_dir/.installed"
    },
    using => sub {
	my $save_pwd = save_pwd2;
	chdir $perl_src_dir;
	sudo 'make', 'install';
	if (!-d $state_dir) {
	    sudo 'mkdir', $state_dir;
	    sudo 'chown', (getpwuid($<))[0], $state_dir;
	}
	system 'touch', "$state_dir/.installed";
    };

step "Symlink perl for devel perls",
    ensure => sub {
	-x "$perldir/bin/perl"
    },
    using => sub {
	sudo 'ln', '-s', "perl$perlver", "$perldir/bin/perl";
    };


my $symlink_src = "/usr/local/bin/perl$perlver" . ($build_debug ? "d" : "") . ($build_threads ? "t" : "");
step "Symlink in /usr/local/bin",
    ensure => sub {
	-l $symlink_src
    },
    using => sub {
	sudo 'ln', '-s', "$perldir/bin/perl", $symlink_src;
    };

#- change ownership to cpansand:
#sudo chown -R cpansand:cpansand $MYPERLDIR && sudo chmod -R ugo+r $MYPERLDIR
#- switch now to cpansand (set again MYPERLDIR and MYPERLVER!)

# install both YAML::Syck and YAML, because it's not clear what's configured
# for CPAN.pm (by default it's probably YAML, but on cvrsnica/biokovo it's
# set to YAML::Syck)
my @toolchain_modules = qw(YAML::Syck YAML Term::ReadKey Expect Term::ReadLine::Perl CPAN::Reporter);

step "Install modules needed for CPAN::Reporter",
    ensure => sub {
	toolchain_modules_installed_check();
    }, 
    using => sub {
	# -notypescript, because -typescript uses another terminal,
	# and in this terminal the sudo_keeper is not active. Anyway,
	# tests are run later again with -typescript turned on (or
	# whatever the default is).
	system $^X, "$srezic_misc/scripts/cpan_smoke_modules", "-notypescript", "-nosignalend", "-install", @toolchain_modules, "-perl", "$perldir/bin/perl";
    };

step "Install and report Kwalify",
    ensure => sub {
	-f "$state_dir/.reported_kwalify"
    },
    using => sub {
	system $^X, "$srezic_misc/scripts/cpan_smoke_modules", "-notypescript", "-nosignalend", "-install", qw(Kwalify), "-perl", "$perldir/bin/perl";
	# XXX unfortunately, won't fail if reporting did not work for some reason
	system "touch", "$state_dir/.reported_kwalify";
    };

step "Report toolchain modules",
    ensure => sub {
	-f "$state_dir/.reported_toolchain"
    },
    using => sub {
	# note: as this is the last step (currently), explicitely use -signalend
	system $^X, "$srezic_misc/scripts/cpan_smoke_modules", "-signalend", @toolchain_modules, "-perl", "$perldir/bin/perl";
	# XXX unfortunately, won't fail if reporting did not work for some reason
	system "touch", "$state_dir/.reported_toolchain";
    };

step "Force a fail report",
    ensure => sub {
	-f "$state_dir/.reported_fail"
    },
    using => sub {
	eval { system $^X, "$srezic_misc/scripts/cpan_smoke_modules", "-notypescript", "-nosignalend", qw(Devel::Fail::MakeTest), "-perl", "$perldir/bin/perl"; };
	# XXX unfortunately, won't fail if reporting did not work for some reason
	system "touch", "$state_dir/.reported_fail";
    };

if ($for_cpansand) {
    step "chown for cpansand",
	ensure => sub {
	    my($cpansand_uid, $cpansand_gid) = (getpwnam("cpansand"))[2,3];
	    if (!defined $cpansand_uid) {
		die "No uid found for user <cpansand>, maybe user is not defined?";
	    }
	    if (!defined $cpansand_gid) {
		die "No gid found for group <cpansand>, maybe group is not defined?";
	    }

	    my($perldir_uid,$perldir_gid) = (stat($perldir))[4,5];
	    if ($perldir_uid != $cpansand_uid || $perldir_gid != $cpansand_gid) {
		return 0;
	    } else {
		my($perlexe_uid,$perlexe_gid) = (stat("$perldir/bin/perl"))[4,5];
		if ($perlexe_uid != $cpansand_uid || $perlexe_gid != $cpansand_gid) {
		    return 0;
		}
	    }
	    1;
	},
	using => sub {
	    sudo 'chown', '-R', 'cpansand:cpansand', $perldir;
	    if ($? != 0) {
		warn "<chown -R cpansand:cpansand $perldir> failed, reverting the permissions at least for the root directory...\n";
		sudo 'chown', 'root:root', $perldir; # just to signal the wrong permission for next run
	    }
	};
}

#- ImageMagick manuell installieren (von CPAN geht nicht) und zwar
#gegen die Version, die schon mit FreeBSD kommt (does not work
#currently for bleadperl, FreeBSD's ImageMagick is too old):
#cd /usr/local/src/work/ImageMagick-*/PerlMagick
#	  und normal bauen (als eserte)
#	    $MYPERLDIR/bin/perl Makefile.PL && make all test
#	  aber als cpansand installieren:
#	    sudo -H -u cpansand make install
#	  Achtung: ältere Versionen von Image::Magick brauchen eine
#	  Dummy-Typemap-Datei, wenn sie mit einem neuen Perl (~ >= 5.14.0)
#	  gebaut wurden. Siehe "typemap problems in newer perls" in TODO.

#	- Bundle::BBBike installieren (Achtung: X11::Protocol ist interaktiv!)
#	  cd ~eserte/src/bbbike && ~eserte/src/srezic-misc/scripts/cpan_smoke_modules -nobatch -shell -perl $MYPERLDIR/bin/perl
#	  und dann: install Bundle::BBBike

#	- Consider to add the new perl to
#	  ~/src/srezic-misc/scripts/cpan_smoke_modules_wrapper3

#	- Consider to set the new perl (if it's the latest stable one)
#	  as "pistacchio-perl".

END {
    if ($sudo_validator_pid) {
	kill $sudo_validator_pid;
	undef $sudo_validator_pid;
    }

    if ($? == 0) {
	set_term_title "Setup new smoker perl $perlver finished";
    } else {
	set_term_title "Setup new smoker perl $perlver aborted";
    }
}

sub toolchain_modules_installed_check {
    my $this_perl = "$perldir/bin/perl";
    my($tmpfh,$tmpfile) = tempfile(SUFFIX => "setup_new_smoker_perl.txt", UNLINK => 1)
	or die $!;
    for my $toolchain_module (@toolchain_modules) {
	if ($toolchain_module eq 'Term::ReadLine::Perl') {
	    print $tmpfh "Term::ReadLine\n"; # hack needed here, see https://rt.cpan.org/Ticket/Display.html?id=89894
	}
	print $tmpfh "$toolchain_module\n";
    }
    close $tmpfh or die $!;

    my $total_success = 1;

    # CPAN::Reporter::PrereqCheck is really only for internal use, and
    # the call convention is different, but doing it as designed would
    # make the code unnecessarily more complicated...
    #
    # On first-time install there will be a "Can't location
    # CPAN/Reporter/PrereqCheck..." error.
    my $prereq_result = qx/$this_perl -MCPAN::Reporter::PrereqCheck -e "CPAN::Reporter::PrereqCheck::_run()" < $tmpfile/;
    unlink $tmpfile; # do it early

    if ($? != 0) {
	$total_success = 0; # probably no CPAN::Reporter::PrereqCheck available
    } else {
	for my $line (split "\n", $prereq_result) {
	    next unless length $line;
	    my(undef, $met, undef) = split " ", $line;
	    if (!$met) {
		$total_success = 0;
		last;
	    }
	}
    }
    $total_success;
}

sub step ($%) {
    my($step_name, %doings) = @_;
    my $ensure = $doings{ensure} || die "ensure => sub { ... } missing";
    my $using  = $doings{using}  || die "using => sub { ... } missing";
    return if $ensure->();
    set_term_title "Setup new smoker perl $perlver: $step_name";
    $using->();
    die "Step '$step_name' failed" if !$ensure->();
}

sub sudo (@) {
    my(@cmd) = @_;
    system 'sudo', '-v';
    if (!$sudo_validator_pid) {
	my $parent = $$;
	$sudo_validator_pid = fork;
	if ($sudo_validator_pid == 0) {
	    # child
	    while() {
		sleep 60; # assumes that sudo timeout is larger than one minute!!!
		if (!kill 0 => $parent) {
		    exit;
		}
		system 'sudo', '-v';
	    }
	}
    }
    system 'sudo', @cmd;
}

{
    my $can_xterm_title;

    sub check_term_title () {
	$can_xterm_title = 1;
	if (!eval { require XTerm::Conf; 1 }) {
	    if (!eval { require Term::Title; 1 }) {
		$can_xterm_title = 0;
	    }
	}
    }

    sub set_term_title ($) {
	return if !$can_xterm_title;
	my $string = shift;
	if (defined &XTerm::Conf::xterm_conf_string) {
	    print STDERR XTerm::Conf::xterm_conf_string(-title => $string);
	} else {
	    Term::Title::set_titlebar($string);
	}
    }
}

# REPO BEGIN
# REPO NAME save_pwd2 /home/e/eserte/work/srezic-repository 
# REPO MD5 456b25e69b899a5f4b7b7e61c4fccccf

{
    sub save_pwd2 () {
	require Cwd;
	bless {cwd => Cwd::cwd()}, __PACKAGE__ . '::SavePwd2';
    }
    my $DESTROY = sub {
	my $self = shift;
	chdir $self->{cwd}
	    or die "Can't chdir to $self->{cwd}: $!";
    };
    no strict 'refs';
    *{__PACKAGE__.'::SavePwd2::DESTROY'} = $DESTROY;
}
# REPO END

__END__
