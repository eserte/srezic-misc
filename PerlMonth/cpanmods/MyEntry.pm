# -*- perl -*-

#
# $Id: MyEntry.pm,v 1.1 2005/08/10 22:59:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package MyEntry;
use base Tk::Entry;
Construct Tk::Widget 'MyEntry';

sub Insert {
    my($w, $s) = @_;
    # $s is the string containing the new text to be inserted
    # here are now some examples for a restriction:
    $s =~ s/\D//g; # delete all non-digits
    $s = "" if length($w->get . $s ) > 10; # restrict length
    #$s = uc($s); # force uppercase letters
    $w->SUPER::Insert($s);
}

return 1 if caller; # return here if called from a script

package main; # test script
use Tk;
$top = new MainWindow;
$top->MyEntry->pack;
MainLoop;

__END__
