#!/usr/bin/perl -w
# -*- perl -*-

use strict;
use DBI;
use Devel::Peek;
use Encode;

# Needs
#   grant all on test.* to test@localhost identified by 'test';

my $dbh = DBI->connect("dbi:mysql:test", "test", "test") or die $DBI::error;
$dbh->do("drop table utf8") or die;
$dbh->do("create table utf8 (a varchar(256))") or die;
#$dbh->do("insert into utf8 values (?)", undef, "\x{20ac}");
#$dbh->do("insert into utf8 values (?)", undef, "ä");
$dbh->do("insert into utf8 values (?)", undef, encode("utf-8", "ä"));
my $sth = $dbh->prepare("SELECT * from utf8");
$sth->execute or die $DBI::error;
while(my $row = $sth->fetchrow_hashref) {
    Dump $row->{a};
    my $a = decode("utf-8", $row->{a});
    Dump $a;
}

__END__
