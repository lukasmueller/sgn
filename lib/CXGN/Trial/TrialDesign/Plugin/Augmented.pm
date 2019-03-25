
package CXGN::Trial::TrialDesign::Plugin::Augmented;

use Moose::Role;

sub create_design {
    my $self = shift;
    my %augmented_design;
    my $rbase = R::YapRI::Base->new();
    my @stock_list;
    my @control_list;
    my $maximum_block_size;
    my $number_of_blocks;
    my $stock_data_matrix;
    my $control_stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my %control_names_lookup;
    
    if ($self->has_stock_list()) {
	@stock_list = @{$self->get_stock_list()};
    } else {
	die "No stock list specified\n";
    }
    
    if ($self->has_control_list()) {
	@control_list = @{$self->get_control_list()};
	%control_names_lookup = map { $_ => 1 } @control_list;
	$self->_check_controls_and_accessions_lists;
    } else {
	die "No list of control stocks specified.  Required for augmented design.\n";
    }
    
    if ($self->has_maximum_block_size()) {
	$maximum_block_size = $self->get_maximum_block_size();
	if ($maximum_block_size <= scalar(@control_list)) {
	    die "Maximum block size must be greater the number of control stocks for augmented design\n";
	}
	if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
	    die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
	}
	$number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
    } else {
	die "No block size specified\n";
    }
    
    $stock_data_matrix =  R::YapRI::Data::Matrix->new(
	{
	    name => 'stock_data_matrix',
	    rown => 1,
	    coln => scalar(@stock_list),
	    data => \@stock_list,
	}
	);
    
    $control_stock_data_matrix =  R::YapRI::Data::Matrix->new(
	{
	    name => 'control_stock_data_matrix',
	    rown => 1,
	    coln => scalar(@control_list),
	    data => \@control_list,
	}
	);
    $r_block = $rbase->create_block('r_block');
    $stock_data_matrix->send_rbase($rbase, 'r_block');
    $control_stock_data_matrix->send_rbase($rbase, 'r_block');
    $r_block->add_command('library(agricolae)');
    $r_block->add_command('trt <- stock_data_matrix[1,]');
    $r_block->add_command('control_trt <- control_stock_data_matrix[1,]');
    $r_block->add_command('number_of_blocks <- '.$number_of_blocks);
    $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
    if ($self->has_randomization_seed()){
	$r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
	$r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=3,kinds=randomization_method, seed=randomization_seed)');
    }
    else {
	$r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=3,kinds=randomization_method)');
    }
    $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output
    $r_block->add_command('augmented<-as.matrix(augmented)');
    
    $r_block->run_block();
    $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');
    @plot_numbers = $result_matrix->get_column("plots");
    @block_numbers = $result_matrix->get_column("block");
    @stock_names = $result_matrix->get_column("trt");
    my $max = max( @block_numbers );
    @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers, \@block_numbers, $max)};
    
    my %seedlot_hash;
    if($self->get_seedlot_hash){
	%seedlot_hash = %{$self->get_seedlot_hash};
    }
    for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
	my %plot_info;
	$plot_info{'stock_name'} = $stock_names[$i];
	$plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
	if ($plot_info{'seedlot_name'}){
	    $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
	}
	$plot_info{'block_number'} = $block_numbers[$i];
	$plot_info{'plot_name'} = $converted_plot_numbers[$i];
	$plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
	$plot_info{'plot_number'} = $converted_plot_numbers[$i];
	$plot_info{'plot_num_per_block'} = $converted_plot_numbers[$i];
	$augmented_design{$converted_plot_numbers[$i]} = \%plot_info;
    }
    %augmented_design = %{_build_plot_names($self,\%augmented_design)};
    return \%augmented_design;
}

1;
