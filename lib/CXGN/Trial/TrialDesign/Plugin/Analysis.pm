
package CXGN::Trial::TrialDesign::Plugin::Analysis;

use Moose::Role;

sub create_design {
#    sub _get_averaged_trial_design {
    my $self = shift;
    my %avg_design;

    my @accession_list = sort @{ $self->get_stock_list() };
    my $trial_name = $self->get_trial_name;
    my %num_accession_hash;

    my @plot_numbers = (1..scalar(@accession_list));
    for (my $i = 0; $i < scalar(@plot_numbers); $i++) {
        my %plot_info;
        $plot_info{'stock_name'} = $accession_list[$i];
        $plot_info{'plot_name'} = "averaged_accession_$accession_list[$i]";
        $avg_design{$plot_numbers[$i]} = \%plot_info;
    }
    %avg_design = %{_build_plot_names($self,\%avg_design)};

    foreach my $plot_num (keys %avg_design) {
        my @plant_names;
        my $plot_name = $avg_design{$plot_num}->{'plot_name'};
        my $stock_name = $avg_design{$plot_num}->{'stock_name'};
        for my $n (1..$num_accession_hash{$stock_name}) {
            my $plant_name = $plot_name."_plant_$n";
            push @plant_names, $plant_name;
        }
        $avg_design{$plot_num}->{'plant_names'} = \@plant_names;
    }

    #print STDERR Dumper \%greenhouse_design;
    return \%avg_design;
}

1;
