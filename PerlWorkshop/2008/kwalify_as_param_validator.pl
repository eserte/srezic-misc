#!/usr/bin/perl
# -*- perl -*-

#
# $Id: kwalify_as_param_validator.pl,v 1.2 2008/02/09 22:22:39 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use Kwalify;

my $foo_schema =
    {
     type => "map",
     mapping =>
     {
      -font  => { type => 'str', required => 1 },
      -width => { type => 'int', range => {max=>20, min=>0} },
     },
    };
sub foo {
    my $args = { @_ };
    Kwalify::validate($foo_schema, $args);
    warn $args->{-font};
    warn $args->{-width};
}

#foo(-width => 12);                  #  - [/] Expected required key `-font'
#foo(-font => {"bla"=>1});           #  - [/-font] Non-valid data `HASH(0x5d91d8)', expected a str
#foo(-font => "bla", -width => -12); #  - [/-width] `-12' is too small (< min 0)
foo(-font => "bla", -width => 12);
foo(-font => "bla");

__END__
