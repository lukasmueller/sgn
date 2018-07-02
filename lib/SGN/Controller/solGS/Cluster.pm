package SGN::Controller::solGS::Cluster;

use Moose;
use namespace::autoclean;

use File::Spec::Functions qw / catfile catdir/;
use File::Path qw / mkpath  /;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use JSON;

use CXGN::List;


BEGIN { extends 'Catalyst::Controller' }


sub kcluster_analysis :Path('/kcluster/analysis/') Args() {
    my ($self, $c, $id) = @_;

    $c->stash->{pop_id} = $id;

    $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $id); 
    my $combo_pops_list = $c->stash->{combined_pops_list};

    if ($combo_pops_list) 
    {
	$c->stash->{data_set_type} = 'combined_populations';	
    }
    
    $c->stash->{template} = '/kcluster/analysis.mas';

}


sub kcluster_check_result :Path('/kcluster/check/result/') Args() {
    my ($self, $c) = @_;

    my $training_pop_id  = $c->req->param('training_pop_id');
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $list_id          = $c->req->param('list_id');
    my $combo_pops_id    = $c->req->param('combo_pops_id');
    my $file_id;

    my $referer = $c->req->referer;
  
    if ($referer =~ /solgs\/selection\//)
    {
	if ($training_pop_id && $selection_pop_id) 
	{
	    my @pops_ids = ($training_pop_id, $selection_pop_id);
	    $c->stash->{pops_ids_list} = \@pops_ids;
	    $c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
	    $c->stash->{pop_id} =  $c->stash->{combo_pops_id};
	    $file_id = $c->stash->{combo_pops_id};
	}
    } 
    elsif ($list_id)
    {
	$c->stash->{pop_id} = $list_id;
	$file_id = $list_id;
	
	$list_id =~ s/list_//;		   	
	my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });

	my $list_type = $list->type();
	$c->stash->{list_id}   = $list_id;
	$c->stash->{list_type} = $list_type;

	if ($list_type =~ /trials/)
	{
	    $self->get_trials_list_ids($c);
	    my $trials_ids = $c->stash->{trials_ids};
	    
	    $c->stash->{pops_ids_list} = $trials_ids;
	    $c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
	    $c->stash->{pop_id} =  $c->stash->{combo_pops_id};
	    $file_id = $c->stash->{combo_pops_id};
	}	
    }
    elsif ($referer =~ /kcluster\/analysis\/|\/solgs\/model\/combined\/populations\//  && $combo_pops_id)
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	#$c->stash->{pop_id} = $combo_pops_id;
	$file_id = $combo_pops_id;
    }
    else 
    {
	$c->stash->{pop_id} = $training_pop_id;
	$file_id = $training_pop_id;	
    }

    $c->stash->{file_id} = $file_id;
    $self->kcluster_scores_file($c);
    my $kcluser_result_file = $c->stash->{kcluster_result_file};
    my $ret->{result} = undef;
   
    if (-s $kcluster_result_file && $file_id =~ /\d+/) 
    {
	$ret->{result} = 1;
	$ret->{list_id} = $list_id;
	$ret->{combo_pops_id} = $combo_pops_id;
#	$ret->{data_set_type} = $data_set_type;    
    }  
    

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub kcluster_result :Path('/kcluster/result/') Args() {
    my ($self, $c) = @_;
    
    my $training_pop_id  = $c->req->param('training_pop_id');
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $combo_pops_id    = $c->req->param('combo_pops_id');

    my $list_id     = $c->req->param('list_id');
    my $list_type   = $c->req->param('list_type');
    my $list_name   = $c->req->param('list_name');
    
    my $pop_id;
    my $file_id;
    my $referer = $c->req->referer;

    if ($referer =~ /solgs\/selection\//)
    {
	my @pops_ids = ($training_pop_id, $selection_pop_id);
	$c->stash->{pops_ids_list} = \@pops_ids;
	$c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
	$combo_pops_id =  $c->stash->{combo_pops_id};
	$c->stash->{pop_id} =  $combo_pops_id;
	$file_id = $combo_pops_id;
	$pop_id = $combo_pops_id;

	my $ids = join(',', @pops_ids);
	my $entry = "\n" . $combo_pops_id . "\t" . $ids;
        $c->controller('solGS::combinedTrials')->catalogue_combined_pops($c, $entry);
    }
    elsif ($referer =~ /kcluster\/analysis\/|\/solgs\/model\/combined\/populations\// && $combo_pops_id)
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$c->stash->{pop_id} = $combo_pops_id;
	$file_id = $combo_pops_id;
	$pop_id = $combo_pops_id;
	$c->stash->{data_set_type} = 'combined_populations';
    } 
    else 
    {
	$c->stash->{pop_id} = $training_pop_id;
	$file_id = $training_pop_id;
	$pop_id  = $training_pop_id;
    }

    $c->stash->{training_pop_id}  = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;

    if ($list_id) 
    {
	$c->stash->{data_set_type} = 'list';
	$c->stash->{list_id}       = $list_id;
	$c->stash->{list_type}     = $list_type;
    }
   
    $self->create_kcluster_genotype_data($c);
 
    $c->stash->{file_id} = $file_id;
    
    $self->kcluster_result_file($c);
    my $kcluster_result_file = $c->stash->{kcluster_result_file};

    my $ret->{status} = 'k-cluster analysis failed.';
    my $kcluster_result;
   
    if( !-s $kcluster_result_file)
    {	
	if (!$c->stash->{genotype_files_list} && !$c->stash->{genotype_file}) 
	{	  
	    $ret->{status} = 'There is no genotype data. Aborted K-Cluster analysis.';                
	}
	else 
	{
	    $self->run_kcluster($c);	    
	}	
    }
    
    $kcluster    = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $kcluster_result_file);
   
    my $host = $c->req->base;

    if ( $host !~ /localhost/)
    {
	$host =~ s/:\d+//; 
	$host =~ s/http\w?/https/;
    }
    
    my $output_link = $host . 'kcluster/analysis/' . $pop_id;

    if ($kcluster_result)
    {
        $ret->{kcluster} = $kcluster_result;
        $ret->{status} = 'success';  
	$ret->{pop_id} = $c->stash->{pop_id};# if $list_type eq 'trials';
	$ret->{trials_names} = $c->stash->{trials_names};
	$ret->{output_link}  = $output_link;
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}




sub kcluster_genotypes_list :Path('/kcluster/genotypes/list') Args(0) {
    my ($self, $c) = @_;
 
    my $list_id   = $c->req->param('list_id');
    my $list_name = $c->req->param('list_name');   
    my $list_type = $c->req->param('list_type');
    my $pop_id    = $c->req->param('population_id');
   
    $c->stash->{list_name} = $list_name;
    $c->stash->{list_id}   = $list_id;
    $c->stash->{pop_id}    = $pop_id;
    $c->stash->{list_type} = $list_type;

    $c->stash->{data_set_type} = 'list';
    $self->create_kcluster_genotype_data($c);

    my $geno_file = $c->stash->{genotype_file};

    my $ret->{status} = 'failed';
    if (-s $geno_file ) 
    {
        $ret->{status} = 'success';
    }
               
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}




sub create_kcluster_genotype_data {    
    my ($self, $c) = @_;
   
    my $data_set_type = $c->stash->{data_set_type};

    if ($data_set_type =~ /list/) 
    {
	$self->_kcluster_list_genotype_data($c);
	
    }
    else 
    {
	$self->_process_trials_details($c);
    }

}


sub _kcluster_list_genotype_data {
    my ($self, $c) = @_;
    
    my $list_id = $c->stash->{list_id};
    my $list_type = $c->stash->{list_type};
    my $pop_id = $c->stash->{pop_id};
    my $data_set_type = $c->stash->{data_set_type};
    my $referer = $c->req->referer;
    my $geno_file;
    
    if ($referer =~ /solgs\/trait\/\d+\/population\//) 
    {
	$c->controller('solGS::Files')->genotype_file_name($c, $pop_id);
	$geno_file  = $c->stash->{genotype_file_name};
	$c->stash->{genotype_file} = $geno_file; 
    }
    elsif ($referer =~ /solgs\/selection\//) 
    {
	my $training_pop_id  = $c->stash->{training_pop_id};
	my $selection_pop_id = $c->stash->{selection_pop_id};

	my @pops_ids = ($training_pop_id, $selection_pop_id);
	$c->stash->{pops_ids_list} = \@pops_ids;

	$self->_process_trials_details($c);
    }
    elsif ($referer =~ /kcluster\/analysis\// && $data_set_type =~ 'combined_populations')
    {
	my $combo_pops_id = $c->stash->{combo_pops_id};
    	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	#$c->stash->{pop_id} = $combo_pops_id;

	$self->_process_trials_details($c);
    }	   
    else
    {
	if ($list_type eq 'accessions') 
	{
	    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
	    my @genotypes_list = @{$list->elements};

	    $c->stash->{genotypes_list} = \@genotypes_list;	   
	    my $geno_data = $c->model('solGS::solGS')->genotypes_list_genotype_data(\@genotypes_list);
	    
	    my $tmp_dir = $c->stash->{solgs_lists_dir};
	    my $file = "genotype_data_list_${list_id}";     
	    $file = $c->controller('solGS::Files')->create_tempfile($tmp_dir, $file);    
	    
	    write_file($file, $geno_data);
	    $c->stash->{genotype_file} = $file; 	    
	} 
	elsif ( $list_type eq 'trials') 
	{
	    $self->get_trials_list_ids($c);
	    my $trials_ids = $c->stash->{trials_ids};

	    $c->stash->{pops_ids_list} = $trials_ids;
	    $self->_process_trials_details($c);
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
    }   
    
}


sub _process_trials_details {
    my ($self, $c) = @_;

    my $pops_ids = $c->stash->{pops_ids_list} || [$c->stash->{pop_id}];

    my @genotype_files;
    my %pops_names = ();

    foreach my $p_id (@$pops_ids)
    {
	$c->stash->{pop_id} = $p_id; 
	$self->_kcluster_trial_genotype_data($c);
	push @genotype_files, $c->stash->{genotype_file};

	if ($p_id =~ /list/) 
	{
	    $c->controller('solGS::solGS')->list_population_summary($c, $p_id);
	    $pops_names{$p_id} = $c->stash->{project_name};  
	}
	else
	{
	    my $pr_rs = $c->controller('solGS::solGS')->get_project_details($c, $p_id);
	    $pops_names{$p_id} = $c->stash->{project_name};  
	}      
    }    

    if (scalar(@$pops_ids) > 1 )
    {
	$c->stash->{pops_ids_list} = $pops_ids;
	$c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
	$c->stash->{pop_id} =  $c->stash->{combo_pops_id};
    }

    $c->stash->{genotype_files_list} = \@genotype_files;
    $c->stash->{trials_names} = \%pops_names;
  
}


sub _kcluster_trial_genotype_data {
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


sub combined_kcluster_trials_data_file {
    my ($self, $c) = @_;
    
    my $file_id = $c->stash->{file_id};
    my $tmp_dir = $c->stash->{kcluster_temp_dir};
    my $name = "combined_kcluster_data_file_${file_id}"; 
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    
    $c->stash->{combined_kcluster_data_file} = $tempfile;
    
}


sub run_kcluster {
    my ($self, $c) = @_;
    
    my $pop_id  = $c->stash->{pop_id};
    my $file_id = $c->stash->{file_id};
    
    $self->kcluster_output_files($c);
    my $output_file = $c->stash->{kcluster_output_files};

    $self->kcluster_input_files($c);
    my $input_file = $c->stash->{kcluster_input_files};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{kcluster_temp_dir};
    
    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "kcluster-${file_id}";
    $c->stash->{r_script}     = 'R/solGS/kcluster.r';
    
    $c->controller("solGS::solGS")->run_r_script($c);
    
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



__PACKAGE__->meta->make_immutable;

####
1;
####
