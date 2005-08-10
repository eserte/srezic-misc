#!/usr/local/bin/perl -w

use Tk;
use Tk::DragDrop;
use Tk::DropSite;
use Tk::HList;
use strict;
use vars qw($top $f $lb_src $lb_dest $dnd_token $drag_entry);

{package Tk::DragDrop;
sub Drop
{
 my $ewin  = shift;
 my $e     = $ewin->XEvent;
 my $token = $ewin->toplevel;
 my $site  = $token->FindSite($e->X,$e->Y,$e);
 Tk::catch { $token->grabRelease };
 if (defined $site)
  {
   my $seln = $token->cget('-selection');
   unless ($token->Callback(-predropcommand => $seln, $site))
    {
     warn "schedule done";
# XXX This is ugly, if the user again starts a drag within the 2000 ms:
#     my $id = $token->after(2000,[$token,'Done']);
     my $w = $token->parent;
     $token->InstallHandlers;
     $site->Drop($token,$seln,$e);
     $token->Callback(-postdropcommand => $seln);
     $token->Done;
    }
  }
 else
  {
   $token->Done;
  }
 $token->Callback('-endcommand');
}
}

$top = new MainWindow;

$top->Label(-text => "Drag items in the HList"
	   )->pack;
$f = $top->Frame->pack(-expand => 1, -fill => "both");
$lb_src  = $f->Scrolled('HList', -scrollbars => "osoe",
			-selectmode => 'dragdrop'
		       )
  ->pack(-side => "left", -expand => 1, -fill => "both");

my $folder = $top->Getimage("folder");
my $file = $top->Getimage("file");

my $i=0;
my $lastch;
my $last2ch;
foreach (sort keys %ENV) {
    my $ch = substr($_, 0, 1);
    my $ch2 = substr($_, 1, 1);
    if (!defined $lastch || $lastch ne $ch) {
	$lb_src->add($ch, -itemtype => "imagetext", -text => $ch, -image => $folder);
    }
    if (!defined $last2ch || $last2ch ne $ch2) {
	$lb_src->add($ch.".".$ch2, -itemtype => "imagetext", -text => $ch2, -image => $folder);
    }
    $lb_src->add("$ch.".$ch2.".".($i++), -itemtype => "imagetext", -text => $_, -data => "Additional data: $_", -image => $file);
    $lastch=$ch;
    $last2ch = $ch2;
}

# Define the source for drags.
# Drags are started while pressing the left mouse button and moving the
# mouse. Then the StartDrag callback is executed.
$dnd_token = $lb_src->DragDrop
  (-event     => '<B1-Motion>',
   -sitetypes => ['Local'],
   -startcommand => sub { StartDrag($dnd_token) },
   -endcommand   => sub { hlist_End_AutoScan($lb_src) },
  );

my $real_lb_src = $lb_src;
if ($real_lb_src->Subwidget("scrolled")) {
    $real_lb_src = $real_lb_src->Subwidget("scrolled");
}
$dnd_token->bind('<Any-Motion>', sub {
		     my $token = shift;
		     my $e = $token->XEvent;
		     my $X  = $e->X;
		     my $Y  = $e->Y;

		     my $lby = $real_lb_src->pointery - $real_lb_src->rooty;
		     my $nearest = $real_lb_src->nearest($lby);
		     if (defined $nearest) {
			 my(@bbox) = $real_lb_src->infoBbox($nearest);
			 if (@bbox && $lby > ($bbox[3]-$bbox[1])/2+$bbox[1]) {
			     $real_lb_src->anchorSet($nearest);
			 } else {
			     my $prev = $real_lb_src->info('prev', $nearest);
			     if (defined $prev) {
				 $nearest = $prev;
			     }
			     $real_lb_src->anchorSet($nearest);
			 }
		     }

		     if ($Y < $real_lb_src->rooty ||
			 $Y > $real_lb_src->rooty + $real_lb_src->height) {
			 if (!defined $lb_src->MainWindow->{_afterId_}) {
			     hlist_AutoScan($real_lb_src, $X, $Y);
			 }
		     } else {
			 hlist_End_AutoScan($real_lb_src);
		     }
		     $token->Drag(@_);
		 });

sub hlist_End_AutoScan
{
 my($w) = @_;
 if (defined $w->MainWindow->{_afterId_}) {
     $w->afterCancel($w->MainWindow->{_afterId_});
     delete $w->MainWindow->{_afterId_};
 }
}

sub hlist_AutoScan
{
 my ($w,$x,$y) = @_;
 if($y >= $w->rooty + $w->height)
  {
   $w->yview('scroll', 1, 'units');
  }
 elsif($y < $w->rooty)
  {
   $w->yview('scroll', -1, 'units');
  }
 else
  {
   return;
  }
 hlist_End_AutoScan($w);
 $w->MainWindow->{_afterId_} = $w->repeat(50, sub {
					    hlist_AutoScan($w, $w->pointerxy);
					});
}


# Define the target for drops.
$lb_src->DropSite
  (-droptypes     => ['Local'],
   -dropcommand   => [ \&Drop, $lb_src, $dnd_token ],
  );

MainLoop;

sub StartDrag {
    my($token) = @_;
    my $w = $token->parent; # $w is the source hlist
    my $e = $w->XEvent;
    $drag_entry = $w->nearest($e->y); # get the hlist entry under cursor
    if (defined $drag_entry) {
	# Configure the dnd token to show the hlist entry
	$token->configure(-text => $w->entrycget($drag_entry, '-text'));
	# Show the token
	my($X, $Y) = ($e->X, $e->Y);
	$token->MoveToplevelWindow($X, $Y);
	$token->raise;
	$token->deiconify;
	$token->FindSite($X, $Y, $e);
    }
}

# Accept a drop and insert a new item in the destination hlist and delete
# the item from the source hlist
sub Drop {
    my($lb, $dnd_source) = @_;
    my $end = ($lb->info("children"))[-1];
    my @pos = (-after => $end) if defined $end;
    my $y = $lb->pointery - $lb->rooty;
    my $nearest = $lb->nearest($y);
    if (defined $nearest) {
	my(@bbox) = $lb->infoBbox($nearest);
	if ($y > ($bbox[3]-$bbox[1])/2+$bbox[1]) {
	    if ($lb->entrycget($nearest, '-image') eq $folder) {
		@pos = (-in => $nearest);
	    } else {
		@pos = (-after => $nearest);
	    }
	} else {
	    @pos = (-before => $nearest);
	}
    }
    my $new_entry = $lb->moveentry($drag_entry, @pos);
    $lb->see($new_entry) if defined $new_entry;
    $lb->anchorClear;
}

sub Tk::HList::moveentry {
    my($w,$entry,@to) = @_;
    if (@to && $to[0] =~ /^-(after|before|in)$/ && $to[1] eq $entry) {
	return undef; # nothing to do
    }
    if ($w->info("children", $entry)) {
	$w->messageBox(-icon => "info",
		       -message => "Move of entries with children is not yet implemented");
	return undef;
    }
    my @info;
    foreach my $col (0 .. $w->cget(-columns)-1) {
	$info[$col] = [$w->itemConfigure($entry, $col)];
    }
    $w->delete("entry", $entry);
    my $to_dir;
    if ($to[0] eq '-in') {
	$to_dir = $to[1];
	my $to_dir_first_child = ($w->info('children', $to_dir))[0];
	if (defined $to_dir_first_child) {
	    @to = (-before => $to_dir_first_child);
	} else {
	    @to = ();
	}
    } else {
	$to_dir = $w->dirname($to[1]);
    }
    if ($w->dirname($entry) ne $to_dir) {
	my $base = $w->basename($entry);
	while(1) {
	    $entry = $w->catpath($to_dir, $base);
	    last if !$w->info('exists', $entry);
	    $base++;
	}
    }
    my @entry_config;
    for(my $i = 0; $i <= $#{$info[0]}; $i++) {
	if ($info[0]->[$i][0] =~ /^-(image|bitmap|itemtype)$/) {
	    push @entry_config, $info[0]->[$i][0], $info[0]->[$i][4];
	    splice @{ $info[0] }, $i, 1;
	    $i--;
	}
    }
    $w->add($entry, @to, @entry_config);
    for my $i (0 .. $#info) {
	my @config;
	foreach my $def (@{ $info[$i] }) {
	    push @config, $def->[0], $def->[4];
	}
	$w->itemConfigure($entry, $i, @config);
    }
    $entry;
}

sub Tk::HList::basename {
    my($w, $entry) = @_;
    my $sep = quotemeta($w->cget(-separator));
    $entry =~ s/(?:^|.*$sep)([^$sep]+)$/$1/;
    $entry;
}

sub Tk::HList::dirname {
    my($w, $entry) = @_;
    my $sep = quotemeta($w->cget(-separator));
    $entry =~ s/[^$sep]+$//;
    $entry =~ s/$sep$//;
    $entry;
}

sub Tk::HList::catpath {
    my($w, $dir, $file) = @_;
    my $sep = $w->cget(-separator);
    $dir . $sep . $file;
}

__END__
