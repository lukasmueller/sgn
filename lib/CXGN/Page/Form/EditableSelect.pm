
use strict;
use CXGN::Page::Form::Select;

package CXGN::Page::Form::EditableSelect;

use base qw / CXGN::Page::Form::Select /;

=head2 new

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub new {
    print STDERR "Instantiating new EditableSelect...\n";
    my $class = shift;
    my %args = @_;
    #foreach my $k (keys %args) { print "Args to add_select $k, $args{$k}\n<br />"; }
    my $self = $class->SUPER::new(%args);

    return $self;
    
}

sub render { 
    my $self = shift;
    print STDERR "Rendering Editable Select...\n";
	 my $select_id = $self->get_id();
    my $select_name = $self->get_field_name();
    my $box = qq { <select id="$select_id" name="$select_name"> };
    foreach my $s ($self->get_selections()) { 
	my $yes = "";
	#if (exists($s->[0])) { print STDERR "S0 = $s->[0]\n"; }
	#if (exists($s->[1])) { print STDERR "S1 = $s->[1] INPUT:".($self->get_contents()). "\n"; }
	
	if (exists($s->[1]) && ($s->[1]=~/\d+/) && ($s->[1] == $self->get_contents())) { 
	    $yes = "selected=\"selected\"";
	}
	elsif (exists($s->[1]) && ($s->[1]=~/\w+/) && ($s->[1] eq $self->get_contents())) { 
	    $yes = "selected=\"selected\"";
	}

	$box .= qq { <option value="$s->[1]" $yes>$s->[0]</option> };

    }
	$box .= qq { </select> };
    return $box;
}

return 1;
