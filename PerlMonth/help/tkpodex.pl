#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: tkpodex.pl,v 1.1 2005/08/10 22:59:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use Tk;
use FindBin;

$top = new MainWindow;

$mb = $top->Menu;
$top->configure(-menu => $mb);

$mb->cascade(-label => "~File");
$mb->cascade(-label => "~Edit");
$help_menu = $mb->cascade(-label => "~Help");

$help_menu->command
  (-label => "~Online documentation",
   -command => sub {
       eval {
           require Tk::Pod;
	   require File::Basename;
           $top->Pod(-file => $0,
                     -title => 'Documentation for ' .
		               File::Basename::basename($0));
       };
       if ($@) {
           my $r;
           my $doc_html = "$FindBin::RealBin/$FindBin::RealScript.html";
           my $url;
           if (defined $doc_html && -r $doc_html) {
               $url = "file:$doc_html";
	       system("netscape $url&");
           }
       }
   },
  );


MainLoop;

__END__

=head1 NAME

Blah Foo - an application to demonstrate online help

=head1 DESCRIPTION

Congratulations! You can see this documentation. Now you can navigate
further following the L<tkpod> link, or the L<perl> link, or using the
fulltext search (which itself uses L<Text::English>).

=head1 AUTHOR

M. R. Jupiter, m.r.jupiter@olymp.gr

=head1 SEE ALSO

L<tkpod>.

=cut
