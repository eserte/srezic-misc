#!/usr/bin/perl
# -*- perl -*-

#
# $Id: kwalify_as_param_validator.pl,v 1.1 2008/02/09 22:18:18 eserte Exp $
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
      -width => { type => 'int' },
     },
    };
sub foo {
    my $args = { @_ };
    Kwalify::validate($foo_schema, $args);
    warn $args->{-font};
    warn $args->{-width};
}

#foo(-width => 12);
#foo(-font => {"bla"=>1});
foo(-font => "bla", -width => 12);
foo(-font => "bla");


__END__
