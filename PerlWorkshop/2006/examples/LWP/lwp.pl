#!/usr/bin/perl -w
# -*- perl -*-

use LWP::UserAgent;
use HTML::Parser;
use Encode;

$ua = LWP::UserAgent->new;
$resp = $ua->get("http://www.w3c.org");
$content = $resp->content;
#use Devel::Peek; Dump $resp;

($ct, @add) = $resp->content_type;
for (@add) {
    ($key,$val) = split /=/, $_, 2;
    if ($key eq 'charset') {
	$content = decode($val, $content);
    }
}

$p = HTML::Parser->new(api_version => 3,
		       text_h => [ \&dtextcb, "dtext" ]
		      );
$p->parse($content);
$p->eof;

sub dtextcb {
    my($dtext) = @_;
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$dtext],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX
}

__END__
