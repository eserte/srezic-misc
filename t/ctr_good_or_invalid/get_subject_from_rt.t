#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Getopt::Long;
use Test::More;

GetOptions("doit" => \my $doit)
    or die "usage: $0 [--doit]\n";

plan skip_all => "Please specify --doit to run live tests" if !$doit;
plan 'no_plan';

my $scripts_dir = "$FindBin::RealBin/../../scripts";
{
    local $FindBin::RealBin = $scripts_dir;
    require "$scripts_dir/ctr_good_or_invalid.pl";
}

is
    get_subject_from_rt('https://rt.cpan.org/Ticket/Display.html?id=123073'),
    'Tests fail (with older Exception::DB and/or QBit::Application::Model::DB?)',
    'rt.cpan ticket';

is
    get_subject_from_rt('https://rt.perl.org/Ticket/Display.html?id=132142'),
    'Bleadperl v5.27.3-34-gf6107ca24b breaks MLEHMANN/AnyEvent-HTTP-2.23.tar.gz',
    'rt.perl ticket';

is
    get_subject_from_rt('https://rt.perl.org/rt3/Ticket/Display.html?id=132142'),
    'Bleadperl v5.27.3-34-gf6107ca24b breaks MLEHMANN/AnyEvent-HTTP-2.23.tar.gz',
    'rt.perl ticket, alternative URL';
    
__END__
