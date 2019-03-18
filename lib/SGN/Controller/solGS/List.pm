=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 DESCRIPTION

SGN::Controller::solGS::List - Controller for list based training and selection populations

=cut


package SGN::Controller::solGS::List;

use Moose;
use namespace::autoclean;
use Carp qw/ carp confess croak /;
use CXGN::List::Transform;
use CXGN::Tools::Run;
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use File::Temp qw / tempfile tempdir /;
use JSON;
use List::MoreUtils qw /uniq/;
use POSIX qw(strftime);
use Storable qw/ nstore retrieve /;
use String::CRC;
use Try::Tiny;



BEGIN { extends 'Catalyst::Controller' }



sub generate_check_value :Path('/solgs/generate/checkvalue') Args(0) {
    my ($self, $c) = @_;
    
    my $file_name = $c->req->param('string');
    my $check_value = crc($file_name);

    my $ret->{status} = 'failed';
    
    if ($check_value) 
    {
        $ret->{status} = 'success';
        $ret->{check_value} = $check_value;
    }
               
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_predicted_list_selection :Path('/solgs/check/predicted/list/selection') Args(0) {
    my ($self, $c) = @_;
    
    my $args = $c->req->param('arguments');

    my $json = JSON->new();
    $args = $json->decode($args);
    
    my $training_pop_id  = $args->{training_pop_id};
    my $selection_pop_id = $args->{selection_pop_id};
    
    $c->stash->{list_prediction} = 1;
   
    $c->controller("solGS::solGS")->download_prediction_urls($c, $training_pop_id, $selection_pop_id);
   
    my $ret->{output} = $c->stash->{download_prediction};

    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub load_genotypes_list_selection :Path('/solgs/load/genotypes/list/selection') Args(0) {
    my ($self, $c) = @_;
 
    my $args = $c->req->param('arguments');
    
    my $json = JSON->new();
    $args = $json->decode($args);
    
    my $training_pop_id  = $args->{training_pop_id}[0];
    my $selection_pop_id = $args->{selection_pop_id}[0];
    my $trait_id         =  $args->{trait_id}[0];
    $c->stash->{list}                = $args->{list};
    $c->stash->{list_name}           = $args->{list_name};
    $c->stash->{list_id}             = $args->{list_id};
    $c->stash->{data_set_type}       = $args->{data_set_type}; 
    $c->stash->{training_pop_id}     = $training_pop_id;
    $c->stash->{model_id}            = $training_pop_id; 
    $c->stash->{pop_id}              = $training_pop_id; 
    $c->stash->{selection_pop_id}    = $selection_pop_id;  
    $c->stash->{list_prediction} = $args->{population_type};
    $c->stash->{trait_id}            = $trait_id;

    if ($args->{data_set_type} =~ /combined populations/) 
    {
	 $c->stash->{combo_pops_id}  = $training_pop_id;
    }
   
    $self->get_genotypes_list_details($c);

    my $genotypes_list = $c->stash->{genotypes_list};
    my $genotypes_ids = $c->stash->{genotypes_ids};

    $self->genotypes_list_genotype_file($c, $selection_pop_id);
    my $genotype_file = $c->stash->{genotypes_list_genotype_file};

    $self->create_list_population_metadata_file($c, $selection_pop_id);
 
    my $ret->{status} = 'failed';
    
    if (-s $genotype_file) 
    {
	$self->predict_list_selection_gebvs($c);

        $ret->{status} = $c->stash->{status};
	$ret->{output} = $c->stash->{download_prediction};
    }
               
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub solgs_list_login_message :Path('/solgs/list/login/message') Args(0) {
    my ($self, $c) = @_;

    my $page = $c->req->param('page');

    my $message = "This is a private data. If you are the owner, "
	. "please <a href=\"/user/login?goto_url=$page\">login</a> to view it.";

    $c->stash->{message} = $message;

    $c->stash->{template} = "/generic_message.mas"; 
   
}


sub get_trial_id :Path('/solgs/get/trial/id') Args(0) {
    my ($self, $c) = @_;
    
    my @trials_names = $c->req->param('trials_names[]');

    my $tr_rs = $c->model('solGS::solGS')->project_details_by_exact_name(\@trials_names);

    my @trials_ids;
    
    while (my $rw = $tr_rs->next) 
    {
	push @trials_ids, $rw->project_id;
    }
 
    my $ret->{trials_ids} = \@trials_ids;
           
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub get_selection_genotypes_list_from_file {
    my ($self, $file) = @_;
    my @clones;

    open my $fh, $file or die "Can't open file $file: $!";

    while (<$fh>) 
    {
        $_ =~ s/\n//;
        push @clones, $_;
    }

    return \@clones;

}


sub get_genotypes_list {
    my ($self, $c) = @_;

    my $list_id = $c->stash->{list_id};
    
    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
    my @genotypes_list = @{$list->elements};

    $c->stash->{genotypes_list} = \@genotypes_list;
    
}


sub transform_genotypes_unqiueids {
    my ($self, $c, $genotypes) = @_;
    
    my $transform = CXGN::List::Transform->new();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $genotypes_t = $transform->can_transform("accessions", "accession_ids");
    my $genotypes_id_hash = $transform->transform($schema, $genotypes_t, $genotypes);
    my @genotypes_ids = @{$genotypes_id_hash->{transform}};

    return \@genotypes_ids;
    
}


sub transform_uniqueids_genotypes{
    my ($self, $c, $genotypes_ids) = @_;
    
    my $transform = CXGN::List::Transform->new();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $genotypes_t = $transform->can_transform("stock_ids", "stocks");
    my $genotypes_hash = $transform->transform($schema, $genotypes_t, $genotypes_ids);
    my @genotypes = @{$genotypes_hash->{transform}};

    return \@genotypes;
    
}

sub get_genotypes_list_details {
    my ($self, $c) = @_;

    my $list_id = $c->stash->{list_id};

    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
    my $list_type = $list->type;
    my $genotypes_names;

    if ($list->type =~ /accessions/) {
	$self->get_list_elements_names($c);
	$genotypes_names = $c->stash->{list_elements_names};
    } elsif ($list->type =~ /plots/) {
	$self->transform_plots_genotypes_names($c);
	$genotypes_names = $c->stash->{genotypes_list};
    }
   
    my @genotypes_names = uniq(@$genotypes_names);
    my $genotypes_ids = $self->transform_genotypes_unqiueids($c, \@genotypes_names);
    

    $c->stash->{genotypes_list} = $genotypes_names;
    $c->stash->{genotypes_ids}  = $genotypes_ids;
    
}


sub create_list_pop_data_files {
    my ($self, $c, $dir, $file_id) = @_;

    $file_id = $c->stash->{file_id} if !$file_id;

    $file_id = 'list_' . $file_id if $file_id !~ /list|dataset/;
    
    my $pheno_name = "phenotype_data_${file_id}.txt";
    my $geno_name  = "genotype_data_${file_id}.txt";  
    my $pheno_file = catfile($dir, $pheno_name);
    my $geno_file  = catfile($dir, $geno_name);

    write_file($pheno_file);
    write_file($geno_file);
    
    my $files = { pheno_file => $pheno_file, geno_file => $geno_file};
    
    return $files;

}


sub create_list_population_metadata {
    my ($self, $c) = @_;
    my $metadata = 'key' . "\t" . 'value';
    $metadata .= "\n" . 'user_id' . "\t" . $c->user->id;
    $metadata .= "\n" . 'list_name' . "\t" . $c->{stash}->{list_name};
    $metadata .= "\n" . 'description' . "\t" . 'Uploaded on: ' . strftime "%a %b %e %H:%M %Y", localtime;
    
    $c->stash->{user_list_population_metadata} = $metadata;
  
}


sub create_list_population_metadata_file {
    my ($self, $c, $list_pop_id) = @_;
    
    my $user_id = $c->user->id;
    my $tmp_dir = $c->stash->{solgs_lists_dir};
              
    my $file = catfile ($tmp_dir, "metadata_${user_id}_${list_pop_id}");
   
    $self->create_list_population_metadata($c);
    my $metadata = $c->stash->{user_list_population_metadata};
    
    write_file($file, $metadata);
 
    $c->stash->{user_list_population_metadata_file} = $file;
 
  
}


sub predict_list_selection_pop_single_pop_model {
    my ($self, $c) = @_;

    my $trait_id         = $c->stash->{trait_id};
    my $training_pop_id  = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
    
    $c->stash->{list_prediction} = 1;

    my $identifier = $training_pop_id . '_' . $selection_pop_id;
    $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $identifier, $trait_id);
    my $rrblup_selection_gebvs_file = $c->stash->{rrblup_selection_gebvs_file};
   
    if (!-s $rrblup_selection_gebvs_file)
    {
	$c->controller('solGS::Files')->phenotype_file_name($c, $training_pop_id);
	$c->stash->{phenotype_file} =$c->stash->{phenotype_file_name};

	$c->controller('solGS::Files')->genotype_file_name($c, $training_pop_id);
	$c->stash->{genotype_file} =$c->stash->{genotype_file_name};

	$self->user_selection_population_file($c, $selection_pop_id); 

	$c->stash->{pop_id} = $c->stash->{training_pop_id};
	$c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
	$c->controller('solGS::solGS')->get_rrblup_output($c);
	$c->stash->{status} = 'success';
    }
    else 
    {
	$c->stash->{status} = 'success';	
    }   

}


sub predict_list_selection_pop_multi_traits {
    my ($self, $c) = @_;
    
    my $data_set_type    = $c->stash->{data_set_type};
    my $training_pop_id  = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
  
    $c->stash->{pop_id} = $training_pop_id;    
    $c->controller('solGS::solGS')->traits_with_valid_models($c);
    my @traits_with_valid_models = @{$c->stash->{traits_with_valid_models}};

    foreach my $trait_abbr (@traits_with_valid_models) 
    {
	$c->stash->{trait_abbr} = $trait_abbr;
	$c->controller('solGS::solGS')->get_trait_details_of_trait_abbr($c);
	$self->predict_list_selection_pop_single_pop_model($c);
    }

    $c->controller("solGS::solGS")->download_prediction_urls($c, $training_pop_id, $selection_pop_id );
    my $download_prediction = $c->stash->{download_prediction};
    
}


sub predict_list_selection_pop_combined_pops_model {
    my ($self, $c) = @_;
         
    my $data_set_type     = $c->stash->{data_set_type}; 
    my $combo_pops_id     = $c->stash->{combo_pops_id};
    my $training_pop_id   = $c->stash->{training_pop_id};                          
    my $selection_pop_id  = $c->stash->{selection_pop_id};
    my $trait_id          = $c->stash->{trait_id};
   
    $c->stash->{prediction_pop_id} = $c->stash->{selection_pop_id};
    $c->stash->{pop_id} = $training_pop_id;
    $c->stash->{list_prediction} = 1;

    my $identifier = $training_pop_id . '_' . $selection_pop_id;
    $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $identifier, $trait_id);        
    my $rrblup_selection_gebvs_file = $c->stash->{rrblup_selection_gebvs_file};
  
    if (!-s $rrblup_selection_gebvs_file)
    {    
	$c->controller("solGS::solGS")->get_trait_details($c, $trait_id); 
	
	$c->controller("solGS::combinedTrials")->cache_combined_pops_data($c);
	    
	my $pheno_file = $c->stash->{trait_combined_pheno_file};
	my $geno_file  = $c->stash->{trait_combined_geno_file};
	
	$self->user_selection_population_file($c, $selection_pop_id);
	
	$c->controller("solGS::solGS")->get_rrblup_output($c);
	$c->stash->{status} = 'success';
    } 
    else
    {
	$c->stash->{status} = 'success';
    }
    
    $c->controller("solGS::solGS")->download_prediction_urls($c, $training_pop_id, $selection_pop_id ); 
  
}


sub predict_list_selection_gebvs {
    my ($self, $c) = @_;

    my $referer = $c->req->referer;

    if ($referer =~ /solgs\/trait\//) 
    {
	$self->predict_list_selection_pop_single_pop_model($c);
    }
    elsif ($referer =~ /solgs\/traits\/all\//) 
    {
	$self->predict_list_selection_pop_multi_traits($c);
    }
    elsif ($referer =~ /solgs\/models\/combined\/trials\//) 
    {
	$c->stash->{pop_id} = $c->stash->{training_pop_id};
	$c->controller("solGS::solGS")->traits_with_valid_models($c);
	my @traits_with_valid_models = @{$c->stash->{traits_with_valid_models}};
   
	foreach my $trait_abbr (@traits_with_valid_models) 
	{
	    $c->stash->{trait_abbr} = $trait_abbr;
	    $c->controller("solGS::solGS")->get_trait_details_of_trait_abbr($c);
     
	    $self->predict_list_selection_pop_combined_pops_model($c); 
	}
    }
    elsif ($referer =~ /solgs\/model\/combined\/populations\//)
    {
	$self->predict_list_selection_pop_combined_pops_model($c); 	
    }
    else 
    {
	$c->stash->{status} = "calling predict_list_selection_gebvs..no matching type analysis.";
    }
}


sub user_selection_population_file {
    my ($self, $c, $pred_pop_id) = @_;
 
    my $list_dir = $c->stash->{solgs_lists_dir};
   
    my ($fh, $tempfile) = tempfile("selection_population_${pred_pop_id}-XXXXX", 
                                   DIR => $list_dir
        );

    
    $c->controller('solGS::Files')->genotype_file_name($c, $pred_pop_id);
    my $pred_pop_file = $c->stash->{genotype_file_name};

    $c->stash->{genotypes_list_genotype_file} = $pred_pop_file;
   
    $fh->print($pred_pop_file);
    $fh->close; 

    $c->stash->{selection_population_file} = $tempfile;
  
}


sub get_list_elements_names {
    my ($self, $c) = @_;

    my $list_id = $c->stash->{list_id};

    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
    my $names = $list->elements;
   
    $c->stash->{list_elements_names} = $names;

}


sub get_plots_list_elements_ids {
    my ($self, $c) = @_;

    my $list = $c->stash->{list_id};
    my $plots;
    if ($c->stash->{plots_names}) 
    {
	$plots = $c->stash->{plots_names};
    }
    else
    {
	$self->get_list_elements_names($c);
	$plots = $c->stash->{list_elements_names};
    }
	
    my $transform = CXGN::List::Transform->new();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $plots_t = $transform->can_transform("plots", "plot_ids");
    my $plots_id_hash = $transform->transform($schema, $plots_t, $plots);
    my @plots_ids = @{$plots_id_hash->{transform}};

    $c->stash->{list_elements_ids} = \@plots_ids;

}


sub map_plots_genotypes {
    my ($self, $c) = @_;
  
    my  $plots = $c->stash->{plots_names};
   
    if (!@$plots) 
    { 
	die "No plots list provided $!\n"; 
    }
    else
    {
	my $genotypes_rs = $c->model('solGS::solGS')->get_genotypes_from_plots($plots);
	
	my @genotypes;
	while (my $genotype = $genotypes_rs->next) 
	{
	    my $name = $genotype->uniquename;
	    push @genotypes, $name;
	}

	@genotypes = uniq(@genotypes); 
	
	$c->stash->{genotypes_list} = \@genotypes;
    }	    
        
}


sub load_plots_list_training :Path('/solgs/load/plots/list/training') Args(0) {
    my ($self, $c) = @_;
     
    my $args = $c->req->param('arguments');

    my $json = JSON->new();
    $args = $json->decode($args);
  
    $c->stash->{list_name}       = $args->{list_name};
    $c->stash->{list_id}         = $args->{list_id};
    $c->stash->{model_id}        = $args->{training_pop_id};
    $c->stash->{population_type} = $args->{population_type};
    $c->stash->{list_id}         = $args->{list_id};

    my $model_id = $c->stash->{model_id};

    $self->plots_list_phenotype_file($c); 
    my $pheno_file = $c->stash->{plots_list_phenotype_file};
    
    $self->genotypes_list_genotype_file($c, $model_id); 
    my $geno_file  = $c->stash->{genotypes_list_genotype_file};

    $self->create_list_population_metadata_file($c, $model_id);
 
    my $ret->{status} = 'failed';
    
    if (-s $geno_file && -s $pheno_file) 
    {
        $ret->{status} = 'success';
    }
               
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub transform_plots_genotypes_names {
    my ($self, $c) = @_;
    
    $self->get_list_elements_names($c); 
    $c->stash->{plots_names} = $c->stash->{list_elements_names};

    $self->get_plots_list_elements_ids($c);
    $c->stash->{plots_ids} = $c->stash->{list_elements_ids};

    $self->map_plots_genotypes($c);
    
}
    

sub genotypes_list_genotype_file {
    my ($self, $c, $pop_id) = @_;

    my $list_id = $c->stash->{list_id};
    my $dataset_id = $c->stash->{dataset_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
   
    $pop_id = $c->stash->{pop_id} || $c->stash->{model_id} if !$pop_id;

    if ($list_id)
    {       
	$self->get_genotypes_list_details($c);
    }
    elsif ($dataset_id)
    {
	$pop_id = 'dataset_' . $dataset_id;
    }
      
    my $genotypes_list = $c->stash->{genotypes_list};
    my $genotypes_ids = $c->stash->{genotypes_ids};
   
    my $data_dir  = $c->stash->{solgs_lists_dir};

    my $files = $self->create_list_pop_data_files($c, $data_dir, $pop_id);
    my $geno_file = $files->{geno_file};
    
    my $args = {
	'list_pop_id'    => $pop_id,
	'genotypes_list' => $genotypes_list,	 
	'genotypes_ids'  => $genotypes_ids,
	'list_data_dir'  => $data_dir,
	'genotype_file'  => $geno_file,
    };
    
    $self->submit_list_genotype_data_query($c, $args);
    
    $c->stash->{genotype_file} = $geno_file;
    
}


sub submit_list_genotype_data_query {
    my ($self, $c, $args) = @_;

    $c->stash->{r_temp_file} = 'genotypes-list-genotype-data-query';
    $c->controller('solGS::solGS')->create_cluster_accesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $report_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, 'geno-data-query-report-args');
    $c->stash->{report_file} = $report_file;

    my $status;

     my $config_args = {
	'temp_dir' => $temp_dir,
	'out_file' => $out_temp_file,
	'err_file' => $err_temp_file
     };
    
    my $config = $c->controller('solGS::solGS')->create_cluster_config($c, $config_args);
    
    my $args_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, 'geno-data-query-report-args');
    $c->stash->{report_file} = $args_file;

    nstore $args, $args_file 
		or croak "data query script: $! serializing model details to $args_file ";
	
    my $cmd = 'mx-run solGS::Cluster ' 
	. ' --data_type genotype '
	. ' --population_type genotypes_list '
	. ' --args_file ' . $args_file;
    

    my $job_args = {
	'cmd' => $cmd,
	'config' => $config,
	'background_job'=> $background_job,
	'temp_dir' => $temp_dir,
    };
    
    $c->controller('solGS::solGS')->submit_job_cluster($c, $job_args);
  
}


sub plots_list_phenotype_file {
    my ($self, $c) = @_;

    my $model_id = $c->stash->{model_id};
    my $list     = $c->stash->{list}; 
    my $list_id  = $c->stash->{list_id};
 
    my $dataset_id  = $c->stash->{dataset_id};
    my $plots_names = $c->stash->{plots_list};
    my $plots_ids   = $c->stash->{plots_ids};

    if (!$plots_ids)
    {
	#$self->get_list_elements_names($c);
	#$plots_names = $c->stash->{list_elements_names};
	
	$self->get_plots_list_elements_ids($c);
	$plots_ids = $c->stash->{list_elements_ids};
    }
    
    $c->stash->{pop_id} = $dataset_id ? 'dataset_' . $dataset_id : 'list_' . $list_id;
    my $file_id = $c->stash->{pop_id};
    $c->controller('solGS::Files')->traits_list_file($c);    
    my $traits_file =  $c->stash->{traits_list_file};
  
    my $data_dir = $c->stash->{solgs_lists_dir};

    $c->stash->{r_temp_file} = 'plots-phenotype-data-query';
    $c->controller('solGS::solGS')->create_cluster_accesible_tmp_files($c);
     
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $temp_data_files = $self->create_list_pop_data_files($c, $data_dir, $file_id);
    my $pheno_file = $temp_data_files->{pheno_file};
    $c->stash->{plots_list_phenotype_file} = $pheno_file;

    $c->controller('solGS::Files')->phenotype_metadata_file($c);
    my $metadata_file = $c->stash->{phenotype_metadata_file};
    
    my $status;

     my $args = {
	'list_id'        => $list_id,
	#'plots_names'    => $plots_names,
	'plots_ids'      => $plots_ids,
	'traits_file'    => $traits_file,
	'list_data_dir'  => $data_dir,
	'phenotype_file' => $pheno_file,
	'metadata_file'  => $metadata_file
    };
    
    my $args_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, 'pheno-data-query-report-args');
    $c->stash->{report_file} = $args_file;
  
    nstore $args, $args_file 
		or croak "data query script: $! serializing data query details to $args_file ";
	
    my $cmd = 'mx-run solGS::Cluster ' 
	. ' --data_type phenotype '
	. ' --population_type plots_list '
	. ' --args_file ' . $args_file;

     my $config_args = {
	'temp_dir' => $temp_dir,
	'out_file' => $out_temp_file,
	'err_file' => $err_temp_file
     };
    
    my $config = $c->controller('solGS::solGS')->create_cluster_config($c, $config_args);

    my $job_args = {
	'cmd' => $cmd,
	'config' => $config,
	'background_job'=> $background_job,
	'temp_dir' => $temp_dir,
    };
    
    $c->controller('solGS::solGS')->submit_job_cluster($c, $job_args);
    $c->stash->{phenotype_file} = $c->stash->{plots_list_phenotype_file};

}


sub list_population_summary {
    my ($self, $c, $list_pop_id) = @_;
    
    my $tmp_dir = $c->stash->{solgs_lists_dir};
   
    if (!$c->user)
    {
	my $page = "/" . $c->req->path;
	$c->res->redirect("/solgs/list/login/message?page=$page");
	$c->detach;
    }
    else
    {
	my $user_name = $c->user->id;
    
	#my $model_id = $c->stash->{model_id};
	#my $selection_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
 
        my $protocol = $c->controller('solGS::solGS')->create_protocol_url($c);

	if ($list_pop_id) 
	{
	    my $metadata_file_tr = catfile($tmp_dir, "metadata_${user_name}_${list_pop_id}");
       
	    my @metadata_tr = read_file($metadata_file_tr) if $list_pop_id;
       
	    my ($key, $list_name, $desc);
     
	    ($desc)        = grep {/description/} @metadata_tr;       
	    ($key, $desc)  = split(/\t/, $desc);
      
	    ($list_name)       = grep {/list_name/} @metadata_tr;      
	    ($key, $list_name) = split(/\t/, $list_name); 
	   
	    $c->stash(project_id          => $list_pop_id,
		      project_name        => $list_name,
		      prediction_pop_name => $list_name,
		      project_desc        => $desc,
		      owner               => $user_name,
		      protocol            => $protocol,
		);  
	}
    }
}


sub get_trials_list_ids {
    my ($self, $c) = @_;

    my $list_id = $c->stash->{list_id};
    my $list_type = $c->stash->{list_type};
  
    if ($list_type =~ /trials/)
    {
	my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
	my @trials_names = @{$list->elements};

	my $list_type = $list->type();
	
	my @trials_ids;

	foreach my $t_name (@trials_names) 
	{
	    my $trial_id = $c->model("solGS::solGS")
		->project_details_by_name($t_name)
		->first
		->project_id;
		
	    push @trials_ids, $trial_id;
	}

	$c->stash->{trials_ids} = \@trials_ids;
	$c->stash->{pops_ids_list} = \@trials_ids;
    }   
    
}


sub get_trials_list_pheno_data {
    my ($self, $c) = @_;

    my $trials_ids = $c->stash->{pops_ids_list};

    $c->controller('solGS::combinedTrials')->multi_pops_phenotype_data($c, $trials_ids);
    $c->controller('solGS::combinedTrials')->multi_pops_pheno_files($c, $trials_ids);
    my @pheno_files = split("\t", $c->stash->{multi_pops_pheno_files});
    $c->stash->{phenotype_files_list} = \@pheno_files;
    
}


sub get_trials_list_geno_data {
    my ($self, $c) = @_;

    my $trials_ids = $c->stash->{pops_ids_list};

    $c->controller('solGS::combinedTrials')->multi_pops_genotype_data($c, $trials_ids);
    $c->controller('solGS::combinedTrials')->multi_pops_geno_files($c, $trials_ids);
    my @geno_files = split("\t", $c->stash->{multi_pops_geno_files});
    $c->stash->{genotype_files_list} = \@geno_files;
    
}


sub process_trials_list_details {
    my ($self, $c) = @_;

    my $pops_ids = $c->stash->{pops_ids_list} || $c->stash->{trials_ids} ||  [$c->stash->{pop_id}];

    my %pops_names = ();

    foreach my $p_id (@$pops_ids)
    {
	if ($p_id =~ /list/) 
	{
	    $c->controller('solGS::List')->list_population_summary($c, $p_id);
	    $pops_names{$p_id} = $c->stash->{project_name};  
	}
	else
	{
	    my $pr_rs = $c->controller('solGS::solGS')->get_project_details($c, $p_id);
	    $pops_names{$p_id} = $c->stash->{project_name};  
	}  
	my $name = $c->stash->{project_name};
    }    

    if (scalar(@$pops_ids) > 1 )
    {
	$c->stash->{pops_ids_list} = $pops_ids;
	$c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
    }

    $c->stash->{trials_names} = \%pops_names;
  
}


sub get_trial_genotype_data {
    my ($self, $c) = @_;
  
    my $pop_id = $c->stash->{pop_id};

    $c->controller('solGS::Files')->genotype_file_name($c, $pop_id);
    my $geno_file = $c->stash->{genotype_file_name};

    if (-s $geno_file)
    {  
	$c->stash->{genotype_file} = $geno_file;
    }
    else
    {
	$c->controller('solGS::solGS')->genotype_file($c);	
    }
   
}



sub register_trials_list  {
    my ($self, $c) = @_;

    my $trials_ids = $c->stash->{pops_ids_list};

    if ($trials_ids)
    {
	$c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
	my $combo_pops_id =  $c->stash->{combo_pops_id};

	my $ids = join(',', @$trials_ids);
	my $entry = "\n" . $combo_pops_id . "\t" . $ids;
	$c->controller('solGS::combinedTrials')->catalogue_combined_pops($c, $entry);
    }
    
}

sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



1;

