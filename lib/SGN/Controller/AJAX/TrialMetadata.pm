
package SGN::Controller::AJAX::TrialMetadata;

use Moose;
use Data::Dumper;
use List::Util 'max';

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);


sub trial : Chained('/') PathPart('ajax/breeders/trial') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    $c->stash->{trial_id} = $trial_id;
    $c->stash->{trial} = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id });

    if (!$c->stash->{trial}) { 
	$c->stash->{rest} = { error => "The specified trial with id $trial_id does not exist" };
	return;
    }
    
}

=head2 delete_trial_by_file

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete_trial_data : Local() ActionClass('REST');

sub delete_trial_data_GET : Chained('trial') PathPart('delete') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $datatype = shift;

    if ($self->delete_privileges_denied($c)) { 
	$c->stash->{rest} = { error => "You have insufficient access privileges to delete trial data." };
	return;
    }

    my $error = "";

    if ($datatype eq 'phenotypes') { 
	$error = $c->stash->{trial}->delete_metadata($c->dbic_schema("CXGN::Metadata::Schema"), $c->dbic_schema("CXGN::Phenome::Schema"));
	$error .= $c->stash->{trial}->delete_phenotype_data();
    }

    elsif ($datatype eq 'layout') { 
	$error = $c->stash->{trial}->delete_field_layout();
    }
    elsif ($datatype eq 'entry') { 
	$error = $c->stash->{trial}->delete_project_entry();
    }
    else { 
	$c->stash->{rest} = { error => "unknown delete action for $datatype" };
	return;
    }
    if ($error) { 
	$c->stash->{rest} = { error => $error };
	return;
    }
    $c->stash->{rest} = { message => "Successfully deleted trial data.", success => 1 };
}

sub trial_description : Local() ActionClass('REST');

sub trial_description_GET : Chained('trial') PathPart('description') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $trial = $c->stash->{trial};

    $c->stash->{rest} = { description => $trial->get_description() };
   
}

sub trial_description_POST : Chained('trial') PathPart('description') Args(1) {  
    my $self = shift;
    my $c = shift;
    my $description = shift;
    
    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) { 
	$c->stash->{rest} = { error => 'You do not have the required privileges to edit the trial type of this trial.' };
	return;
    }

    my $trial_id = $c->stash->{trial_id};
    my $trial = $c->stash->{trial};

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $breeding_program = $p->get_breeding_programs_by_trial($trial_id);

    if (! ($c->user() &&  ($c->user->check_roles("curator") || $c->user->check_roles($breeding_program)))) { 
	$c->stash->{rest} = { error => "You need to be logged in with sufficient privileges to change the description of a trial." };
	return;
    }
    
    $trial->set_description($description);

    $c->stash->{rest} = { success => 1 };
}

# sub get_trial_type :Path('/ajax/breeders/trial/type') Args(1) { 
#     my $self = shift;
#     my $c = shift;
#     my $trial_id = shift;

#     my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id } );

#     $c->stash->{rest} = { type => $t->get_project_type() };

# }
    

sub trial_location : Local() ActionClass('REST');

sub trial_location_GET : Chained('trial') PathPart('location') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $t = $c->stash->{trial};

    $c->stash->{rest} = { location => [ $t->get_location()->[0], $t->get_location()->[1] ] };
    
}

sub trial_location_POST : Chained('trial') PathPart('location') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $location_id = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) { 
	$c->stash->{rest} = { error => 'You do not have the required privileges to edit the trial type of this trial.' };
	return;
    }

    my $t = $c->stash->{trial};
    my $trial_id = $c->stash->{trial_id};

    # remove old location
    #
    $t->remove_location($t->get_location()->[0]);

    # add new one
    #
    $t->add_location($location_id);

    $c->stash->{rest} =  { message => "Successfully stored location for trial $trial_id",
			   trial_id => $trial_id };

}

sub trial_year : Local()  ActionClass('REST');

sub trial_year_GET : Chained('trial') PathPart('year') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $t = $c->stash->{trial};
    
    $c->stash->{rest} = { year => $t->get_year() };
    
}

sub trial_year_POST : Chained('trial') PathPart('year') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $year = shift;
    
    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) { 
	$c->stash->{rest} = { error => 'You do not have the required privileges to edit the trial type of this trial.' };
	return;
    }
    
    my $t = $c->stash->{trial};

    eval { 
	$t->set_year($year);
    };
    if ($@) { 
	$c->stash->{rest} = { error => "An error occurred. $@" };
	return;
    }

    $c->stash->{rest} = { message => "Year set successfully" };
}

sub trial_type : Local() ActionClass('REST');

sub trial_type_GET : Chained('trial') PathPart('type') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $t = $c->stash->{trial};
    
    my $type = $t->get_project_type();
    $c->stash->{rest} = { type => $type };
}

sub trial_type_POST : Chained('trial') PathPart('type') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $type = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) { 
	$c->stash->{rest} = { error => 'You do not have the required privileges to edit the trial type of this trial.' };
	return;
    }

    my $t = $c->stash->{trial};
    my $trial_id = $c->stash->{trial_id}; 

    # remove previous associations
    #
    $t->dissociate_project_type();
    
    # set the new trial type
    #
    $t->associate_project_type($type);
    
    $c->stash->{rest} = { success => 1 };
}

sub phenotype_summary : Chained('trial') PathPart('phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;
    
    my $dbh = $c->dbc->dbh();
    my $trial_id = $c->stash->{trial_id};

    my $h = $dbh->prepare("SELECT distinct(cvterm.name),  cvterm.cvterm_id, count(*) FROM cvterm JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE project_id=? GROUP BY cvterm.name, cvterm.cvterm_id");

    $h->execute($c->stash->{trial_id});

    my @phenotype_data;
    while (my ($trait, $trait_id, $count,) = $h->fetchrow_array()) { 
	push @phenotype_data, [ qq { <a href="/chado/cvterm?cvterm_id=$trait_id">$trait</a> },  qq{ <a href="/breeders_toolbox/trial/$trial_id/trait/$trait_id">$count [more stats]</a> } ];
    }

    $c->stash->{rest} = { data => \@phenotype_data };
}


sub get_spatial_layout : Chained('trial') PathPart('coords') Args(0) {
    
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    
    my $layout = CXGN::Trial::TrialLayout->new(
	{ 
	    schema => $schema,
	    trial_id =>$c->stash->{trial_id}
	});
    
    my $design = $layout-> get_design();
    
    print STDERR Dumper($design);
         
    my @layout_info;
    foreach my $plot_id (keys %{$design}) {
	push @layout_info, { plot_id => $plot_id,
			row_number => $design->{$plot_id}->{row_number},
			col_number => $design->{$plot_id}->{col_number}, 
			block_number=> $design->{$plot_id}-> {block_number},
			rep_number =>  $design->{$plot_id}-> {rep_number},
			plot_name => $design->{$plot_id}-> {plot_name},
			accession_name => $design->{$plot_id}-> {accession_name},
	};

    } 
	
	my @row_numbers;
	my @col_numbers;
	my @rep_numbers;
	my @block_numbers;
	my @accession_name;
	my @plot_name;
	my @plot_id;
	my @array_msg;
	my $my_hash;
	my $plot_id;
	foreach $my_hash (@layout_info) {
		$array_msg[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = "rep_number: ".$my_hash->{'rep_number'}."\nblock_number: ".$my_hash->{'block_number'}."\naccession_name: ".$my_hash->{'accession_name'};
		#print "row: ".$my_hash->{'row_number'}.", col: ".$my_hash->{'col_number'}."\n";
	}


 # Looping through the hash and printing out all the hash elements.

	foreach $my_hash (@layout_info) {
	push @col_numbers, $my_hash->{'col_number'};
	push @row_numbers, $my_hash->{'row_number'};
	push @plot_id, $my_hash->{'plot_id'};
	push @rep_numbers, $my_hash->{'rep_number'};
	push @block_numbers, $my_hash->{'block_number'};
	push @accession_name, $my_hash->{'accession_name'};
	push @plot_name, $my_hash->{'plot_name'};
	
	}

	#print "@col_numbers\n";
	my $max_col = max( @col_numbers );
	print "$max_col\n";
	my $max_row = max( @row_numbers );
	print "$max_row\n";
	

	$c->stash->{rest} = { coord_row =>  \@row_numbers, 
			      coords =>  \@layout_info, 
			      coord_col =>  \@col_numbers,
			      max_row => $max_row,
			      max_col => $max_col,
			      plot_msg => \@array_msg,
			      rep => \@rep_numbers,
			      block => \@block_numbers,
			      accessions => \@accession_name,
			      plot_name => \@plot_name,
			      plot_id => \@plot_id
          		   };
	
}


sub delete_privileges_denied { 
    my $self = shift;
    my $c = shift;

    my $trial_id = $c->stash->{trial_id};

    if (! $c->user) { return "Login required for delete functions."; }
    my $user_id = $c->user->get_object->get_sp_person_id();

    if ($c->user->check_roles('curator')) { 
	return 0;
    }

    my $breeding_programs = $c->stash->{trial}->get_breeding_programs();

    if ( ($c->user->check_roles('submitter')) && ( $c->user->check_roles($breeding_programs->[0]->[1]))) { 
	return 0;
    }
    return "You have insufficient privileges to delete a trial.";
}



1;
