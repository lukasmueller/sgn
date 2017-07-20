
package CXGN::Genotype;

use Moose;
use Data::Dumper;

use JSON::Any;
use Math::Round qw | :all |;


has 'id' => ( isa => 'Int',
	      is => 'rw',
    );

has 'name' => ( isa => 'Str',
		is => 'rw',
    );

has 'method' => (isa => 'Str',
		 is => 'rw',
    );

has 'markerscores' => ( isa => 'HashRef',
			is  => 'rw',
    );

has 'rawscores' => (isa => 'HashRef',
		    is => 'rw',
    );

has 'markers' => (isa => 'ArrayRef',
		  is => 'rw',
    );

has 'dosages' => (isa => 'HashRef',
		  is => 'rw',
    );


sub from_json {
    my $self = shift;
    my $json = shift;

    my $data = JSON::Any->decode($json);

    $self->markerscores($data);

    my @markers = keys(%$data);
    $self->markers( \@markers );

}

sub to_json {


}



sub calculate_consensus_scores {
    my $self = shift;
    my $other_genotype = shift;

    my $other_scores = $other_genotype->markerscores();
    my $this_scores = $self->markerscores();
    my $consensus_scores = {};
    foreach my $m (@{$self->markers()}) {
	if (! exists($other_scores->{$m}) ||
	    ! defined($other_scores->{$m}) ||
	    ! $other_scores->{$m} ||
	    $other_scores->{$m} eq "NA") {
	    $consensus_scores->{$m} = $this_scores->{$m};
	}
    }
    return $consensus_scores;
}


sub calculate_distance {
    my $self = shift;
    my $other_genotype = shift;

    my $total_matches = 0;
    my $total_mismatches = 0;
    my $other_genotype_score = $other_genotype->markerscores();
    my $this_genotype_score = $self->markerscores();

    foreach my $m (@{$self->markers()}) {
	if ($self->good_score($other_genotype_score->{$m}) && $self->good_score($this_genotype_score->{$m})) {
	    if ($self->scores_are_equal($other_genotype_score->{$m}, $this_genotype_score->{$m})) {
		$total_matches++;
		#print STDERR "$m: $other_genotype_score->{$m} matches $this_genotype_score->{$m}\n";
	    }
	    else {
		$total_mismatches++;
		#print STDERR "$m: $other_genotype_score->{$m} no match with $this_genotype_score->{$m}\n";
	    }

	}
	else {    #print STDERR "$m has no valid scores\n";
	}
    }
    return $total_matches / ($total_matches + $total_mismatches);
}

sub read_counts {
    my $self = shift;
    my $marker = shift;

    my $raw = $self->rawscores->{$marker};
    #print STDERR "RAW: $raw\n";
    my $counts = (split /\:/, $raw)[1];

    my ($c1, $c2) = split /\,/, $counts;

    return ($c1, $c2);

}

sub good_call {
    my $self = shift;
    my $marker = shift;
    my ($c1, $c2) = $self->read_counts($marker);
    if ( ($c1 + $c2) < 2) {
	return 0;
    }
    return 1;
}

sub percent_good_calls {
    my $self = shift;

    my $good_calls = 0;
    foreach my $m (@{$self->markers()}) {
	if ($self->good_call($m)) {
	    $good_calls++;
	}
    }
    return $good_calls / scalar(@{$self->markers()});
}

sub good_score {
    my $self = shift;
    my $score = shift;

    if (!defined($score)) { return 0; }

    if ($score =~ /^[A-Za-z?]+$/) { return 0; }

    $score = round($score);

    if ($score == 0 || $score == 1 || $score ==2 || $score == -1) {
	return 1;
    }
    else {
	return 0;
    }
}

sub scores_are_equal {
    my $self = shift;
    my $score1 = shift;
    my $score2 = shift;

    if ($self->good_score($score1)
	&& $self->good_score($score2)) {
	if (round($score1) == round($score2)) {
	    return 1;
	}
    }
    return 0;
}


sub calculate_encoding_type {


}

sub compare_parental_genotypes {
    my $self = shift;
    my $female_parent_genotype = shift;
    my $male_parent_genotype = shift;

    my $self_markers = $self->markerscores();
    my $mom_markers = $female_parent_genotype->markerscores();
    my $dad_markers = $male_parent_genotype->markerscores();

    my $non_informative =0;
    my $concordant =0;
    my $non_concordant =0;
    foreach my $m (keys %$self_markers) {

	my @matrix; #mom, dad, self, 1=possible 0=impossible

	$matrix[ 0 ][ 0 ][ 2 ] =0;
	$matrix[ 2 ][ 2 ][ 0 ] =0;
	$matrix[ 0 ][ 0 ][ 0 ] =1;
	$matrix[ 2 ][ 2 ][ 2 ] =1;

	$matrix[ 0 ][ 0 ][ 1 ] =-1;
	$matrix[ 0 ][ 1 ][ 2 ] =-1;
	$matrix[ 1 ][ 0 ][ 2 ] =-1;
	$matrix[ 2 ][ 2 ][ 1 ] =-1;
	$matrix[ 2 ][ 1 ][ 0 ] =-1;
	$matrix[ 1 ][ 2 ][ 0 ] =-1;
	$matrix[ 2 ][ 0 ][ 2 ] =-1;
	$matrix[ 2 ][ 0 ][ 0 ] =-1;
	$matrix[ 0 ][ 2 ][ 0 ] =-1;
	$matrix[ 0 ][ 2 ][ 2 ] =-1;
	$matrix[ 0 ][ 2 ][ 1 ] =-1;
	$matrix[ 1 ][ 0 ][ 0 ] =-1;
	$matrix[ 1 ][ 0 ][ 1 ] =-1;
	$matrix[ 1 ][ 1 ][ 0 ] =-1;
	$matrix[ 1 ][ 1 ][ 1 ] =-1;
	$matrix[ 1 ][ 1 ][ 2 ] =-1;
	$matrix[ 1 ][ 2 ][ 1 ] =-1;
	$matrix[ 1 ][ 2 ][ 2 ] =-1;
	$matrix[ 0 ][ 1 ][ 0 ] =-1;
	$matrix[ 0 ][ 1 ][ 1 ] =-1;
	$matrix[ 2 ][ 0 ][ 1 ] =-1;
  	$matrix[ 2 ][ 1 ][ 1 ] =-1;
	$matrix[ 2 ][ 1 ][ 2 ] =-1;

	#print "self markers". Dumper $self_markers;

	#print STDERR "checking $mom_markers->{$m} and $dad_markers->{$m} against $self_markers->{$m}\n";

	if (defined($mom_markers->{$m}) && defined($dad_markers->{$m}) && defined($self_markers->{$m})) {

	    my $score = $matrix[ round($mom_markers->{$m})]->[ round($dad_markers->{$m})]->[ round($self_markers->{$m})];
	    if ($score == 1) {
		$concordant++;
	#print STDERR "Plausible. \n";
	    }
	    elsif ($score == -1)  {
		$non_informative++;
	    }
	    else {

		$non_concordant++;
	#print STDERR "NOT Plausible. \n";
	    }
	}
    }
		print STDERR "concordant is $concordant, non_concordant is $non_concordant, non-informative is $non_informative\n";
    return ($concordant, $non_concordant, $non_informative);
}


__PACKAGE__->meta->make_immutable;

1;
