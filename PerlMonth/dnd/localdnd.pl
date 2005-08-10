#!/usr/local/bin/perl -w

use Tk;
use Tk::DragDrop;
use Tk::DropSite;
use strict;
use vars qw($top $f $lb_src $lb_dest $dnd_token);

$top = new MainWindow;

$top->Label(-text => "Drag items from the left listbox to the right one"
	   )->pack;
$f = $top->Frame->pack;
$lb_src  = $f->Scrolled('Listbox', -scrollbars => "osoe")
  ->pack(-side => "left");
$lb_dest = $f->Scrolled('Listbox', -scrollbars => "osoe")
  ->pack(-side => "left");

$lb_src->insert("end", sort keys %ENV);

# Define the source for drags.
# Drags are started while pressing the left mouse button and moving the
# mouse. Then the StartDrag callback is executed.
$dnd_token = $lb_src->DragDrop
  (-event     => '<B1-Motion>',
   -sitetypes => ['Local'],
   -startcommand => sub { StartDrag($dnd_token) },
  );
# Define the target for drops.
$lb_dest->DropSite
  (-droptypes     => ['Local'],
   -dropcommand   => [ \&Drop, $lb_dest, $dnd_token ],
  );

MainLoop;

sub StartDrag {
    my($token) = @_;
    my $w = $token->parent; # $w is the source listbox
    my $e = $w->XEvent;
    my $idx = $w->nearest($e->y); # get the listbox entry under cursor
    if (defined $idx) {
	# Configure the dnd token to show the listbox entry
	$token->configure(-text => $w->get($idx));
	# Show the token
	my($X, $Y) = ($e->X, $e->Y);
	$token->MoveToplevelWindow($X, $Y);
	$token->raise;
	$token->deiconify;
	$token->FindSite($X, $Y, $e);
    }
}

# Accept a drop and insert a new item in the destination listbox.
sub Drop {
    my($lb, $dnd_source) = @_;
    $lb->insert("end", $dnd_source->cget(-text));
    $lb->see("end");
}

__END__
