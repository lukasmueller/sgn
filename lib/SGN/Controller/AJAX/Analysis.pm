
package SGN::Controller::AJAX::Analysis;

use Moose;

use CXGN::Phenotypes::StorePhenotypes;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub store_analysis : Path('/ajax/analysis/store') Args(0) {
    my $self = shift;
    my $c = shift;
    my $file = $c->req->param("file");
    my $analysis_name = $c->req->param("analysis_name");
    my $analysis_type = $c->req->param("analysis_type");
    
    if (! $c->user()) {
	$c->stash->{error} = "You need to be logged in to store data";
	return;
    }
    
    if (! $c->user()->check_roles("submitter") || ! $c->user()->check_roles("curator")) {
	$c->stash->{error} = "You have insufficient privileges to store the data in the database";
	return;
    }

    my $user_id = $c->user()->get_object()->sp_person_id();
    
    my $analysis_type_row = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), $analysis_type, 'analysis_type');
    if (! $analysis_type_row) { die "Provided analysis type does not exist in the database. Exiting." }

    my @plots;
    my @stocks;
    my @traits;
    my %values;

    my $analysis_type_id = $analysis_type_row->cvterm_id();    
    push @traits, $analysis_type_id;
    
    my @lines = slurp($file);

    foreach my $line (@lines) {
	my ($acc, $value) = split /\t/, $line;
	my $plot_name = $analysis_name."_".$acc;
	push @plots, $plot_name;
	push @stocks, $acc;
        $values{$plot_name}->{$traits[0]} = $value;
    }

    my $phenotype_metadata = {};
    
    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
	{
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
	    phenome_schema => $c->dbic_schema("CXGN::Phenome::Schema"),
	    user_id => $user_id,
	    stock_list => \@plots,
	    trait_list => \@traits, 
	    values_hash => \%values,
	    has_timestamps => 0,
	    overwrite_values => 0,
	    metadata_hash => $phenotype_metadata
	});
    
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();

    if ($verified_warning || $verified_error) {
	$c->stash->{rest} = { warnings => $verified_warning, error => $verified_error };
	return;
    }
    
    my ($stored_phenotype_error, $stored_Phenotype_success) = $store_phenotypes->store();

    if ($stored_phenotype_error) { $c->stash->{rest} = { error => $stored_phenotype_error }; }
    else {
	$c->stash->{rest} = { success => 1 };
    }
}
