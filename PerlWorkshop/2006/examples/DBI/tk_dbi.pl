#!/usr/bin/perl
# -*- perl -*-

use strict;
use warnings;

use Tk;
use DBI;
use Encode;

my $mw = tkinit;
my $dbh = DBI->connect("dbi:mysql:test", "test", "test") or die $DBI::error;
$dbh->do("drop table utf8") or die;
$dbh->do("create table utf8 (a varchar(256))") or die;

my $e;
$mw->Entry(-textvariable => \$e)->pack;
$mw->Button(-text => "In die DB schreiben",
	    -command => sub {
		$dbh->do("delete from utf8");
		$dbh->do("insert into utf8 values (?)", undef, encode("utf-8", $e));
	    })->pack;
$mw->Button(-text => "Aus der DB lesen",
	    -command => sub {
		my $sth = $dbh->prepare("SELECT * from utf8");
		$sth->execute or die $DBI::error;
		my $row = $sth->fetchrow_hashref;
		$e =decode("utf-8", $row->{a});
		$sth->finish;
	    })->pack;

MainLoop;

__END__
