#!/usr/bin/env perl
# -*- cperl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2014,2015,2016,2017,2018,2019 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use File::Basename qw(basename dirname);
use File::Path qw(mkpath);
use Getopt::Long;
use Time::HiRes ();

sub save_pwd2 ();
sub step ($%);
sub sudo (@);

sub check_term_title ();
sub set_term_title ($);

sub my_system (@);
sub my_chdir ($);
sub my_rename ($$);

my $argv_fingerprint;
{
    my @argv_fingerprint;
    for(my $i=0; $i<=$#ARGV; $i++) {
	my $arg = $ARGV[$i];
	if ($arg =~ m{^-j(?:obs)?(=.*)?$}) {
	    if (length $1) {
		# just skip
	    } else {
		$i++;
	    }
	} else {
	    push @argv_fingerprint, $arg;
	}
    }
    $argv_fingerprint = join ' ', @argv_fingerprint;
}

# -notypescript, because -typescript uses another terminal,
# and in this terminal the sudo_keeper is not active. Anyway,
# tests are run later again with -typescript turned on (or
# whatever the default is).
my @cpan_smoke_modules_common_install_opts = ('-minbuilddiravail', '0.5G', '-notypescript', '-install');
my @cpan_smoke_modules_common_opts         = ('-minbuilddiravail', '0.5G');

# Some interesting CPAN.pm versions:
# * 1.9463: with new config option prefer_external_tar
# * 2.07:   plugin support
my $min_CPAN_version = '2.07';

my $perlver;
my $build_debug;
my $build_threads;
my $morebits;
my $use_longdouble;
my $use_mallocwrap;
my $for_cpansand;
my $use_patchperl;
my $patchperl_path;
my $jobs;
my $download_url;
my $author;
my $use_pthread;
my $use_shared;
my $extra_config_opts;
my $cf_email;
my $use_sudo = 1;
my $use_sudo_v = 1;
my $use_cpm;
if ($ENV{USER} =~ m{eserte|slaven}) {
    $cf_email = 'srezic@cpan.org'; # XXX make configurable?
}
my $cc;
Getopt::Long::Configure("bundling_override");
GetOptions(
	   "perlver|pv=s" => \$perlver,
	   "debug"     => \$build_debug,
	   "threads"   => \$build_threads,
	   "morebits"  => \$morebits,
	   "longdouble" => \$use_longdouble,
	   "usemallocwrap!" => \$use_mallocwrap,
	   "cpansand"  => \$for_cpansand,
	   "patchperl" => \$use_patchperl,
	   "patchperlpath=s" => \$patchperl_path,
	   "j|jobs=i" => \$jobs,
	   'cpm!' => \$use_cpm,
	   "downloadurl=s" => \$download_url,
	   "author=s" => \$author,
	   "pthread!"  => \$use_pthread,
	   'shared!'   => \$use_shared,
	   'extraconfigopts=s' => \$extra_config_opts,
	   'cc=s' => \$cc,
	   'sudo!' => \$use_sudo,
	   'sudo-v!' => \$use_sudo_v,
	  )
    or die "usage: $0 [-debug] [-threads] [-pthread] [-shared] [-morebits] [-longdouble] [-cpansand] [-jobs ...] [-cpm] [-patchperl | -patchperlpath /path/to/patchperl] [-extraconfigopts ...] -downloadurl ... | -perlver 5.X.Y\n";

if ($author) {
    if (!$perlver) {
	die "-perlver (or -pv) is mandatory with -author\n";
    }
    if ($download_url) {
	die "Don't specify both -author and -downloadurl\n";
    }
    my($a2, $a1) = $author =~ m{^((.).)};
    $download_url = "https://cpan.metacpan.org/authors/id/$a1/$a2/$author/perl-$perlver.tar.gz";
    print "Translate to download URL $download_url\n";
}

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
my $term_title_prefix = "Setup new smoker perl $perlver";
set_term_title $term_title_prefix;

my $perldir = "/usr/perl$perlver";
if ($^O eq 'linux' || $^O eq 'darwin') {
    $perldir = "/opt/perl-$perlver";
}
my $perldir_suffix = '';
if ($build_debug)    { $perldir_suffix .= "d" }
if ($build_threads)  { $perldir_suffix .= "t" }
if ($use_longdouble) { $perldir_suffix .= 'D' }
if ($use_shared)     { $perldir_suffix .= 's' } # XXX suffix is also set to /usr/local/bin symlink (perl5.X.Ys) --- could be surprising!
$perldir .= $perldir_suffix;

if ($use_pthread) {
    if ($^O ne 'freebsd') {
	die "The -pthread hack is only for freebsd.\n";
    } else {
	if ($build_threads) {
	    die "The -pthread hack is not necessary if using threads, please use without.\n";
	} else {
	    # pthread hack is OK
	    $perldir .= "p";
	}
    }
}

my $main_pid = $$;

my $sudo_validator_pid;
sudo 'echo', 'Initialized sudo password';

# Start duration measurement after the sudo call, which is possibly
# interactive.
my $begin = Time::HiRes::time;
my %duration;
if (eval { require Tie::IxHash; 1 }) {
    tie %duration, 'Tie::IxHash';
}
END {
    if ($main_pid == $$) {
	my $end = Time::HiRes::time;
	print STDERR "\n";
	print STDERR "DURATIONS\n";
	print STDERR "---------\n";
	printf STDERR "Total:\t%.2fs\n", $end-$begin;
	while(my($step_name, $duration) = each %duration) {
	    printf STDERR "$step_name:\t%.2fs\n", $duration;
	}
    }
}

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
	    my $tmp_cpan_myconfig = "$cpan_myconfig.$$.tmp";
	    open my $ofh, ">", $tmp_cpan_myconfig
		or die "Cannot write to $tmp_cpan_myconfig: $!";
	    my $conf_contents = <<'EOF';
$CPAN::Config = {
  'colorize_output' => q[1],
  'colorize_print' => q[blue],
  'colorize_warn' => q[bold red],
  'index_expire' => q[0.05],
  'make_install_make_command' => q[sudo /usr/bin/make],
  'makepl_arg' => q[],
  'mbuild_install_build_command' => q[sudo ./Build],
  'mbuildpl_arg' => q[],
  'prefs_dir' => q[__HOME__/.cpan/prefs],
  'recommends_policy' => q[0],
  'test_report' => q[1],
  'urllist' => [q[http://cpan.cpantesters.org/], q[http://cpan.develooper.com/], q[ftp://ftp.funet.fi/pub/CPAN]],
  'yaml_module' => q[YAML::Syck],
};
1;
__END__
EOF
	    # Why YAML::Syck?
	    # -> https://github.com/ingydotnet/yaml-pm/issues/135

	    # Why explicitely set makepl_arg and mbuildpl_arg?
	    # If Debian's changed cpan runs first, then it created
	    # a CPAN/MyConfig.pm with the following settings:
	    #  'makepl_arg' => q[INSTALLDIRS=site],
	    #  'mbuildpl_arg' => q[--installdirs site],
	    # I guess the intention is to make sure that module
	    # installed by CPAN.pm never overwrite the default debian
	    # install. However, this settings cause at least two
	    # problems:
	    # - GD 2.56 struggles if it finds unexpected parameters to
	    #   the Build.PL call
	    # - perl 5.10 and earlier has site_perl after lib, so
	    #   installing core modules like Test::More fails

	    $conf_contents =~ s{__HOME__}{$ENV{HOME}};
	    print $ofh $conf_contents;
	    close $ofh
		or die "Error while writing to $tmp_cpan_myconfig: $!";
	    my_rename $tmp_cpan_myconfig, $cpan_myconfig;
	    require CPAN;
	    CPAN::HandleConfig->load; # this is a syntax check AND is hopefully non-interactive; if not, then at least the questions happen early
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
	    open my $ofh, ">", "$cpanreporter_config_ini~"
		or die "Can't write to $cpanreporter_config_ini~: $!";
	    my $conf_contents = <<'EOF';
edit_report=default:no
email_from=srezic@cpan.org
send_report=default:yes fail:ask/yes
transport = Metabase uri http://metabase.cpantesters.org/beta/ id_file /home/e/eserte/.cpanreporter/srezic_metabase_id.json
EOF
	    print $ofh $conf_contents;
	    close $ofh
		or die "Error while writing to $cpanreporter_config_ini~: $!";
	    my_rename "$cpanreporter_config_ini~", $cpanreporter_config_ini;
	}
    };

step "Download perl $perlver",
    ensure => sub {
	-f $downloaded_perl && -s $downloaded_perl
    },
    using => sub {
	my $save_pwd = save_pwd2;
	my_chdir $download_directory;
	my $tmp_perl_tar_gz = $perl_tar_gz.".~".$$."~";
	if (is_in_path('wget')) {
	    my_system 'wget', "-O", $tmp_perl_tar_gz, $download_url;
	} else {
	    my_system 'curl', '-o', $tmp_perl_tar_gz, $download_url;
	}
	my_rename $tmp_perl_tar_gz, $perl_tar_gz;
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
	my_chdir $src_dir;
	my_system "tar", "xf", $downloaded_perl;
	my_system "touch", "$perl_src_dir/.extracted";
    };

step 'Valid source directory',
    ensure => sub {
	if (open my $fh, "<", "$perl_src_dir/.valid_for") {
	    chomp(my $srcdir_argv_fingerprint = <$fh>);
	    if ($srcdir_argv_fingerprint eq $argv_fingerprint) {
		1;
	    } else {
		die <<EOF;
The source directory '$perl_src_dir' was probably configured with a different ARGV:
    $srcdir_argv_fingerprint
vs.
    $argv_fingerprint

Probably it's best to remove the directory:

    rm -rf '$perl_src_dir'

EOF
	    }
	} else {
	    0;
	}	
    },
    using => sub {
	open my $ofh, ">", "$perl_src_dir/.valid_for"
	    or die "Error while writing $perl_src_dir/.valid_for: $!";
	print $ofh $argv_fingerprint;
	close $ofh
	    or die "Error while writing $perl_src_dir/.valid_for: $!";
    };

if (defined $patchperl_path) {
    step "Patch perl",
	ensure => sub {
	    -f "$perl_src_dir/.patched";
	},
	using => sub {
	    my $save_pwd = save_pwd2;
	    my_chdir $perl_src_dir;
	    my_system $patchperl_path;
	    my_system "touch", ".patched";
	};
}

if ($use_pthread) {
    my $begin_marker = '# BEGIN --- PATCHED BY SETUP_NEW_SMOKER_PERL';
    my $end_marker   = '# END --- PATCHED BY SETUP_NEW_SMOKER_PERL';
    my $hints_file   = "$perl_src_dir/hints/freebsd.sh";
    step 'Enable pthread',
	ensure => sub {
	    system 'fgrep', '-sq', $end_marker, $hints_file;
	    return ($? == 0 ? 1 : 0);
	},
	using => sub {
	    chmod 0644, $hints_file;
	    open my $ofh, ">>", $hints_file
		or die "Error appending to $hints_file: $!";
	    print $ofh $begin_marker . "\n" . <<'EOF' . $end_marker . "\n";
case "$ldflags" in
    *-pthread*)
        # do nothing
        ;;
    *)
        ldflags="-pthread $ldflags"
        ;;
esac
EOF
	    close $ofh
		or die "Error appending to $hints_file: $!";
	};
}

my $built_file = "$perl_src_dir/.built" . (length $perldir_suffix ? '_' . $perldir_suffix : '');
step "Build perl",
    ensure => sub {
	-x "$perl_src_dir/perl" && -f $built_file;
    },
    using => sub {
	my $save_pwd = save_pwd2;
	for my $looks_like_built (glob(".built*")) {
	    unlink $looks_like_built;
	}
	my_chdir $perl_src_dir;
	{
	    my $need_usedevel;
	    if ($perlver =~ m{^5\.(\d+)} && $1 >= 7 && $1%2 == 1) {
		$need_usedevel = 1;
	    }
	    if (!defined $use_mallocwrap) {
		if ($need_usedevel) {
		    $use_mallocwrap = 0;
		} else {
		    $use_mallocwrap = 1;
		}
	    }
	    my @build_cmd = (
			     ($cc ? "env CC='$cc' " : '') .
			     "nice ./configure.gnu --prefix=$perldir" .
			     ($need_usedevel ? ' -Dusedevel' : '') .
			     (!$use_mallocwrap ? ' -Dusemallocwrap=no' : '') . # usemallocwrap=yes is probably default
			     ($build_debug ? ' -DDEBUGGING' : '') .
			     ($build_threads ? ' -Dusethreads' : '') .
			     ($morebits ? die("No support for morebits") : '') .
			     ($use_longdouble ? ' -Duselongdouble' : '') .
			     ($use_shared ? ' -Duseshrplib' : '') .
			     ($cf_email ? " -Dcf_email=$cf_email" : '') .
			     ($extra_config_opts ? ' ' . $extra_config_opts . ' ' : '') .
			     ($^O eq 'freebsd' ? ' -Doptimize="-O2 -pipe"' : '') .
			     ' && nice make' . ($jobs&&$jobs>1 ? " -j$jobs" : '') . ' all'
			    );
	    print STDERR "+ @build_cmd\n";
	    my_system @build_cmd;

	    set_term_title "$term_title_prefix: Test perl";
	    if (!eval {
		local $ENV{TEST_JOBS};
		$ENV{TEST_JOBS} = $jobs if $jobs > 1;
		my_system 'nice', 'make', 'test_harness'; # test_harness appeared in 2001
		1;
	    }) {
		while () {
		    set_term_title "$term_title_prefix: Test perl FAILED";
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
	my_system "touch", $built_file;
    };

my $state_dir = "$perldir/.install_state";
step "Install perl",
    ensure => sub {
	-d $perldir && -f "$state_dir/.installed"
    },
    using => sub {
	my $save_pwd = save_pwd2;
	my_chdir $perl_src_dir;
	sudo 'make', 'install';
	if (!-d $state_dir) {
	    sudo 'mkdir', $state_dir;
	    sudo 'chown', (getpwuid($<))[0], $state_dir;
	}
	my_system 'touch', "$state_dir/.installed";
    };

step "Symlink perl for devel perls",
    ensure => sub {
	-x "$perldir/bin/perl"
    },
    using => sub {
	sudo 'ln', '-s', "perl$perlver", "$perldir/bin/perl";
    };


my $symlink_src = "/usr/local/bin/perl$perlver" . $perldir_suffix;
if ($^O ne 'freebsd' || !-f $symlink_src) {
    step "Symlink in /usr/local/bin",
	ensure => sub {
	    -l $symlink_src
	},
	using => sub {
	    sudo 'ln', '-s', "$perldir/bin/perl", $symlink_src;
	};
} else {
    warn "Don't create symlink in /usr/local/bin, there's already a perl (system perl?)\n";
}

#- change ownership to cpansand:
#sudo chown -R cpansand:cpansand $MYPERLDIR && sudo chmod -R ugo+r $MYPERLDIR
#- switch now to cpansand (set again MYPERLDIR and MYPERLVER!)

# install CPAN.pm plugins early --- otherwise CPAN.pm refuses to work unless
# the plugin list is set to empty
my @cpan_pm_plugins = qw(CPAN::Plugin::Sysdeps);

# install both YAML::Syck and YAML, because it's not clear what's configured
# for CPAN.pm (by default it's probably YAML, but on cvrsnica/biokovo it's
# set to YAML::Syck)
my @toolchain_modules = qw(YAML::Syck YAML Term::ReadKey Expect Term::ReadLine::Perl Devel::Hide CPAN::Reporter);

if ($use_cpm) {
    # Add Term::ReadKey here because tests hang with cpm, but work
    # with CPAN.pm. Reason is probably the existence of a terminal
    # in the former (XXX need to find out the exact reason)
    my @cpm_modules = qw(App::cpm Term::ReadKey Term::ReadLine::Perl);

    step "Install cpm",
	ensure => sub {
	    my @missing_modules = modules_installed_check(\@cpm_modules);
	    return @missing_modules == 0;
	},
	using => sub {
	    my @missing_modules = modules_installed_check(\@cpm_modules);
	    local $ENV{HARNESS_OPTIONS};
	    $ENV{HARNESS_OPTIONS} = "j$jobs" if $jobs > 1;
	    local $ENV{PERL_MM_USE_DEFAULT} = 1;
	    my_system $^X, "$srezic_misc/scripts/cpan_smoke_modules", '-cpanconf-unchecked', 'plugin_list=', @cpan_smoke_modules_common_install_opts, "-nosignalend", @missing_modules, "-perl", "$perldir/bin/perl";
	};

    step "Install modules needed for CPAN::Reporter with cpm",
	ensure => sub {
	    my @missing_modules = modules_installed_check(\@toolchain_modules);
	    return @missing_modules == 0;
	}, 
	using => sub {
	    my @missing_modules = modules_installed_check(\@toolchain_modules);

	    # XXX Temporary (?) hack: use the stable
	    # RGIERSIG/Expect-1.21.tar.gz instead of Expect 1.31 because
	    # the latter does not always pass tests. Note that this
	    # may actually create a downgrade of an already installed
	    # Expect (but this should probably be unlikely)
	    # UPDATE: Expect 1.32 has also problematic tests.
	    my @to_install = map {
		$_ eq 'Expect' ? 'Expect~<1.31' : $_;
	    } @missing_modules;

	    local $ENV{PERL_MM_USE_DEFAULT} = 1;
	    my_system "$perldir/bin/cpm", "install", "--global", "--verbose", "--test", "--sudo", "--workers=$jobs", @to_install;
	};

    # The following two Install steps are hopefully no-ops, because
    # everything should work right.
}

step "Install CPAN.pm plugins",
    ensure => sub {
	my @missing_modules = modules_installed_check(\@cpan_pm_plugins);
	return @missing_modules == 0;
    },
    using => sub {
	my @missing_modules = modules_installed_check(\@cpan_pm_plugins);
	# Start CPAN.pm with plugin_list set to empty list
	my_system $^X, "$srezic_misc/scripts/cpan_smoke_modules", '-cpanconf-unchecked', 'plugin_list=', @cpan_smoke_modules_common_install_opts, "-nosignalend", @missing_modules, "-perl", "$perldir/bin/perl";
    };

step "Maybe upgrade CPAN.pm",
    ensure => sub {
	-f "$state_dir/.cpan_pm_upgrade_done"
    },
    using => sub {
	if (!eval { my_system "$perldir/bin/perl", "-MCPAN $min_CPAN_version", '-e1'; 1 }) {
	    my_system $^X, "$srezic_misc/scripts/cpan_smoke_modules", @cpan_smoke_modules_common_opts, '-signalend', 'CPAN', '-perl', "$perldir/bin/perl";
	}
	my_system "touch", "$state_dir/.cpan_pm_upgrade_done";
    };

step "Install modules needed for CPAN::Reporter",
    ensure => sub {
	my @missing_modules = modules_installed_check(\@toolchain_modules);
	return @missing_modules == 0;
    }, 
    using => sub {
	my @missing_modules = modules_installed_check(\@toolchain_modules);

	# XXX Temporary (?) hack: use the stable
	# RGIERSIG/Expect-1.21.tar.gz instead of Expect 1.31 because
	# the latter does not always pass tests. Note that this
	# may actually create a downgrade of an already installed
	# Expect (but this should probably be unlikely)
	# UPDATE: Expect 1.32 has also problematic tests.
	my @to_install = map {
	    $_ eq 'Expect' ? 'RGIERSIG/Expect-1.21.tar.gz' : $_;
	} @missing_modules;

	local $ENV{HARNESS_OPTIONS};
	$ENV{HARNESS_OPTIONS} = "j$jobs" if $jobs > 1;
	my_system $^X, "$srezic_misc/scripts/cpan_smoke_modules", @cpan_smoke_modules_common_install_opts, "-nosignalend", @to_install, "-perl", "$perldir/bin/perl";
    };

step "Install and report Kwalify",
    ensure => sub {
	-f "$state_dir/.reported_kwalify"
    },
    using => sub {
	my_system $^X, "$srezic_misc/scripts/cpan_smoke_modules", @cpan_smoke_modules_common_install_opts, "-nosignalend", qw(Kwalify), "-perl", "$perldir/bin/perl";
	# XXX unfortunately, won't fail if reporting did not work for some reason
	my_system "touch", "$state_dir/.reported_kwalify";
    };

my @maybe_sudo; # after this step, some commands have to be run as sudo
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
    @maybe_sudo = ('sudo');
} else {
    @maybe_sudo = ();
}

step "Report toolchain modules",
    ensure => sub {
	-f "$state_dir/.reported_toolchain"
    },
    using => sub {
	local $ENV{HARNESS_OPTIONS};
	$ENV{HARNESS_OPTIONS} = "j$jobs" if $jobs > 1;
	# note: as this is the last step (currently), explicitely use -signalend
	my_system $^X, "$srezic_misc/scripts/cpan_smoke_modules", @cpan_smoke_modules_common_opts, "-signalend", @cpan_pm_plugins, @toolchain_modules, "-perl", "$perldir/bin/perl";
	# XXX unfortunately, won't fail if reporting did not work for some reason
	my_system @maybe_sudo, "touch", "$state_dir/.reported_toolchain";
    };

step "Force a fail report",
    ensure => sub {
	-f "$state_dir/.reported_fail"
    },
    using => sub {
	eval { my_system $^X, "$srezic_misc/scripts/cpan_smoke_modules", @cpan_smoke_modules_common_opts, "-nosignalend", qw(Devel::Fail::MakeTest), "-perl", "$perldir/bin/perl"; };
	# XXX unfortunately, won't fail if reporting did not work for some reason
	my_system @maybe_sudo, "touch", "$state_dir/.reported_fail";
    };

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
    if (defined $main_pid && $main_pid == $$) {
	if ($sudo_validator_pid) {
	    kill $sudo_validator_pid;
	    undef $sudo_validator_pid;
	}

	if (defined $term_title_prefix) { # if undefined, then the term title was never set
	    if ($? == 0) {
		set_term_title "$term_title_prefix finished";
	    } else {
		set_term_title "$term_title_prefix aborted";
	    }
	}
    }
}

sub modules_installed_check {
    my $modules_ref = shift;
    my @missing_modules;
    my $this_perl = "$perldir/bin/perl";
    my @this_perl_INC;
    my @cmd = ($this_perl, '-e', 'print $_, "\n" for (@INC)');
    open my $fh, '-|', @cmd
	or die "Can't run @cmd: $!";
    while(<$fh>) {
	chomp;
	push @this_perl_INC, $_;
    }
    close $fh
	or die "Failed to run @cmd: $!";

    my $module_exists = sub {
	my($filename) = @_;
	$filename =~ s{::}{/}g;
	$filename .= ".pm";
	foreach my $prefix (@this_perl_INC) {
	    my $realfilename = "$prefix/$filename";
	    if (-r $realfilename) {
		return 1;
	    }
	}
	return 0;
    };

    for my $toolchain_module (@$modules_ref) {
	if (!$module_exists->($toolchain_module)) {
	    push @missing_modules, $toolchain_module;
	}
    }
    @missing_modules;
}

sub step ($%) {
    my($step_name, %doings) = @_;
    my $t0 = Time::HiRes::time;
    my $ensure = $doings{ensure} || die "ensure => sub { ... } missing";
    my $using  = $doings{using}  || die "using => sub { ... } missing";
    return if $ensure->();
    set_term_title "$term_title_prefix: $step_name";
    $using->();
    die "Step '$step_name' failed" if !$ensure->();
    my $t1 = Time::HiRes::time;
    $duration{$step_name} = $t1-$t0;
}

sub sudo (@) {
    my(@cmd) = @_;
    if (!$use_sudo) {
	my_system @cmd;
	return;
    }
    if ($use_sudo_v) {
	my_system 'sudo', '-v';
    }
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
		if ($use_sudo_v) {
		    my_system 'sudo', '-v';
		}
	    }
	}
    }
    my_system 'sudo', @cmd;
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

sub my_rename ($$) {
    my($from, $to) = @_;
    rename $from, $to
	or die "Error while renaming $from to $to: $!";
}

sub my_chdir ($) {
    my $dir = shift;
    chdir $dir
	or die "Error while changing to $dir: $!";
}

sub my_system (@) {
    my @cmd = @_;
    system @cmd;
    if ($? & 127) {
	my $signalNum = $? & 127;
	die sprintf "ERROR: Command '%s' died with signal %d, %s coredump", "@cmd", $signalNum, ($? & 128) ? 'with' : 'without';
    } elsif ($? != 0) {
	die "ERROR: Command '@cmd' exited with exit code " . ($?>>8);
    } else {
	# successful!
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

# REPO BEGIN
# REPO NAME is_in_path /Users/eserte/src/srezic-repository 
# REPO MD5 e18e6687a056e4a3cbcea4496aaaa1db

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
# REPO NAME file_name_is_absolute /Users/eserte/src/srezic-repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8

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

=head1 OPTIONS

Specification of built perl:

=over

=item -perlver X.Y.Z

Works once the link on www.cpan.org is created, typically some hours after release.

=item -perlver X.Y.Z -author PAUSEID

Works immediately; needs knowledge of the releaser's PAUSE id (uppercase).

=item -downloadurl URL

Works immediately; arbitrary URL may be used, but perl version (5.Y.Z)
has to be part of the URL.

=back

Other options:

=over

=item -jobs NUMBER

Use concurrency where possible. Currently building perl itself is done
using C<make -j>. Running the perl and CPAN module tests is also done
in parallel. Also see the L</-cpm> option.

=item -cpm

Do the initial toolchain module installing with L<App::cpm>. Number of
workers is set to the value of the C<-jobs> option. Unfortunately it
is far from perfect: installation of L<App::cpm> itself is done with
L<CPAN>, so only the test suite is parallelized, and the number of
L<App::cpm> dependencies seems to be larger than the number of the
toolchain module dependencies. Also some interactivity may occur.

=back

=head1 TROUBLESHOOTING

=over

=item wget refuses to download from metacpan because of certificate issues

Formerly it worked to replace the C<https> URL by a C<http> URL. This
does not work anymore, so make sure the required root certificates are
installed. For FreeBSD, install the security/ca_root_nss package, and
make sure that the /etc/ssl symlink is created (see the port options).
Double check if the port is creating this symlink at all.

=item CPAN.pm in perl 5.8.8 and older is too old

CPAN 1.76_xx is too old for L<cpan_smoke_modules>, so the module
installation step fails. Currently it's necessary to upgrade CPAN.pm
manually like this (change perl version here):

    cpan_smoke_modules -pv 5.8.1 -old-cpan-pm-hack -install CPAN
    cpan_smoke_modules -pv 5.8.8 -old-cpan-pm-hack -install CPAN

And then resume C<setup-new-smoker-perl.pl>.

In very pathological cases this does not work at all. Then just try to
unpack, build and install CPAN.pm manually.

=item perl test failures with older perls on debian/jessie

This can be solved by using gcc-4.8 (instead of gcc-4.9) and _not_
running parallel tests (-jobs is global, so don't specify it at all):

    setup-new-smoker-perl.pl -pv 5.16.3 -cc gcc-4.8 -patchperl

Problem seen with perl-5.16.3 and perl-5.8.8.

=item sudo unexpectedly asks for a password

This was observed on CentOS 7 systems with sudo 1.8.6p7 or 1.8.19p2:
the C<sudo -v> command asks for a password, even if the user is setup
to do passwordless sudo. Workaround: start this command with the
C<--no-sudo-v> option.

=back

=head1 DURATIONS

Here are some sample durations for a full perl+toolchain build:

=over

=item * Debian/jessie with i7-6700T @ 2.80GHz, for threaded perl 5.25.6 with -j3:

    DURATIONS
    ---------
    Total:  729.58s
    Extract in /usr/local/src:      0.51s
    Valid source directory: 0.00s
    Build perl:     360.35s
    Install perl:   21.39s
    Symlink perl for devel perls:   0.01s
    Symlink in /usr/local/bin:      0.01s
    Install CPAN.pm plugins:        18.21s
    Install modules needed for CPAN::Reporter:      191.37s
    Install and report Kwalify:     5.34s
    Report toolchain modules:       127.90s
    Force a fail report:    4.37s
    Maybe upgrade CPAN.pm:  0.13s

=item * Debian/jessie with i7-6700T @ 2.80GHz, for unthreaded perl 5.27.7 with -j3:

    DURATIONS
    ---------
    Total:  711.05s
    Download perl 5.27.7:   12.97s
    Extract in /usr/local/src:      0.55s
    Valid source directory: 0.00s
    Build perl:     333.56s
    Install perl:   22.20s
    Symlink perl for devel perls:   0.01s
    Symlink in /usr/local/bin:      0.01s
    Install CPAN.pm plugins:        14.39s
    Install modules needed for CPAN::Reporter:      190.08s
    Install and report Kwalify:     4.61s
    Report toolchain modules:       128.33s
    Force a fail report:    4.23s
    Maybe upgrade CPAN.pm:  0.13s

=item * CentOS6 on a VM with 4 CPUs, for unthreaded perl 5.27.7 with
-j3, script aborted during the CPAN phase, so two starts were
necessary:

    DURATIONS
    ---------
    (no total time, two starts were necessary)
    Build perl:     428.60s
    Extract in /tmp:        0.79s
    Download perl 5.27.7:   0.35s
    Symlink perl for devel perls:   0.01s
    Install perl:   25.06s
    Symlink in /usr/local/bin:      0.01s
    Valid source directory: 0.00s
    ---
    Install and report Kwalify:     1.86s
    Install CPAN.pm plugins:        8.94s
    chown for cpansand:     0.03s
    Report toolchain modules:       139.75s
    Maybe upgrade CPAN.pm:  0.15s
    Force a fail report:    5.00s
    Install modules needed for CPAN::Reporter:      184.05s

=item * Debian/stretch on a VM with 4 CPUs, for unthreaded perl 5.27.7 with -j3:

    DURATIONS
    ---------
    Total:  893.45s
    Download perl 5.27.7:   0.43s
    Extract in /tmp:        0.52s
    Valid source directory: 0.00s
    Build perl:     440.09s
    Install perl:   25.72s
    Symlink perl for devel perls:   0.01s
    Symlink in /usr/local/bin:      0.01s
    Install CPAN.pm plugins:        14.95s
    Install modules needed for CPAN::Reporter:      249.09s
    Install and report Kwalify:     5.75s
    Report toolchain modules:       151.56s
    Force a fail report:    5.13s
    Maybe upgrade CPAN.pm:  0.14s
    chown for cpansand:     0.03s

=item * FreeBSD 12.0-CURRENT on a VM with 1 CPU, for unthreaded perl 5.27.7 with -j3

    DURATIONS
    ---------
    Total:  2528.25s
    Install and report Kwalify:     8.98s
    Valid source directory: 0.00s
    Force a fail report:    7.59s
    Enable pthread: 0.01s
    chown for cpansand:     0.28s
    Build perl:     1224.12s
    Symlink perl for devel perls:   0.03s
    Download perl 5.27.7:   3.60s
    Symlink in /usr/local/bin:      0.05s
    Install perl:   68.84s
    Report toolchain modules:       374.52s
    Extract in /tmp:        5.07s
    Maybe upgrade CPAN.pm:  0.27s
    Install CPAN.pm plugins:        62.34s
    Install modules needed for CPAN::Reporter:      772.53s

=item * FreeBSD 11.1-RELEASE on a VM with 1 CPU, for unthreaded perl 5.27.7 with -j3

    DURATIONS
    ---------
    Total:  1938.84s
    Install modules needed for CPAN::Reporter:      453.14s
    Valid source directory: 0.00s
    Symlink in /usr/local/bin:      0.01s
    Maybe upgrade CPAN.pm:  0.19s
    Install perl:   34.87s
    Report toolchain modules:       328.01s
    Force a fail report:    5.95s
    Install CPAN.pm plugins:        20.11s
    Download perl 5.27.7:   2.50s
    chown for cpansand:     0.21s
    Build perl:     1084.11s
    Extract in /tmp:        2.77s
    Install and report Kwalify:     6.49s
    Symlink perl for devel perls:   0.01s
    Enable pthread: 0.47s

=back

=cut
