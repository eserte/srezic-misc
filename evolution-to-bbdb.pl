#!/usr/bin/perl

use strict;
our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use DB_File;
use Encode;
use Getopt::Long;

use Text::vCard;
use Text::vCard::Addressbook;

my %opt = (adrdb => "$ENV{HOME}/evolution/local/Contacts/addressbook.db",
	  );

GetOptions(\%opt, "adrdb=s", "add-header!")
    or die "usage: $0 [-adrdb dbfile] [-add-header]";

tie my %adr, "DB_File", $opt{adrdb}, O_RDONLY, 0644
    or die "Can't tie $opt{adrdb}: $!";

my @l = localtime;
my $today = sprintf "%04d-%02d-%02d", $l[5]+1900, $l[4]+1, $l[3];

print ";;; file-version: 6\n" if $opt{"add-header"};

while(my($k,$v) = each %adr) {
    if ($k =~ /^pas-id/) {
	$v =~ s/\0//g;
	$v = Encode::decode("utf-8", $v);
	
	my $address_book = Text::vCard::Addressbook->new
	    ({ 'source_text' => $v });
	foreach my $vcard ($address_book->vcards) {
	    my $fullname = $vcard->fullname;
	    my($firstname,$lastname) = split /\s+/, $fullname, 2;
	    my @email = map { $_->value } $vcard->get("email");
	    my @tel   = $vcard->get("tel");
	    print qq{["$firstname" "$lastname" nil nil nil nil ("$email[0]") ((creation-date . "$today") (timestamp . "$today")) nil]\n};
	}
    }
}
