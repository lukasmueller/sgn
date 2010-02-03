


=head1 NAME

CXGN::Cview::Map::SGN::Contig - a class to generate maps of contigs aligned to the genome           
           
=head1 SYNOPSYS

 my $map = CXGN::Cview::Map::SGN::Contig->new($dbh, $id);
 my $chr = $map->get_chromosome(1);
 # etc...
      
=head1 DESCRIPTION

The FPC data is currently stored in a berkeleydb database. It is accessed using the following methods:

my $db = Bio::DB::GFF->new( -adaptor => 'berkeleydb',
-dsn => '/data/local/cxgn/core/sgn/documents/gbrowse/databases/fpc/SGN_2009');

and then you can do all the Bio::DB::GFF things with it, do 'perldoc Bio::DB::GFF' to see.

=head1 AUTHOR(S)

Lukas Mueller <lam87@cornell.edu>

=head1 FUNCTIONS

This class implements the following functions:

=cut

use strict;

package CXGN::Cview::Map::SGN::Contig;

use Bio::DB::GFF;
use CXGN::Cview::Map::SGN::Genetic;
use CXGN::Cview::Chromosome::Physical;
use CXGN::Cview::Marker::Physical;


use base qw | CXGN::Cview::Map::SGN::Genetic |;

=head2 function new

  Synopsis:	
  Arguments:	a database handle (preferably generated through
                CXGN::DB::Connection) and a map id. Currently,
                only one map_id is supported, with the alpha-
                numeric id of "contig".
  Returns:	
  Side effects:	
  Description:	

=cut

sub new {
    my $class = shift;
    my $dbh = shift;
    my $id = shift;

    my $db_version_id = get_db_id($dbh, $id);
    my $self = $class -> SUPER::new($dbh, $db_version_id);

#    if (!defined($self)) { return undef; }
    $self->set_preferred_chromosome_width(18);
    $self->set_short_name("Tomato FPC map SGN2009");
    $self->set_long_name("Solanum lycopersicum Contig Map SGN2009");

#    $self->fetch_contig_data();
   
    $self->set_id($id);
    return $self;
}

sub fetch_contig_data { 
    my $self =shift;
    $self->{gffdb} = Bio::DB::GFF->new( 
					-adaptor => 'berkeleydb',
					-dsn => '/data/prod/public/tomato_genome/physical_mapping/fpc/SGN_2009/gbrowse/curr' #'/data/prod/tomato_genome/fpc/SGN_2009'    # tomato_R12_dQ'
					);

   # foreach my $m ($chromosome->get_markers()) { 
#	# get contig associated with $m...
#    }

}

=head2 function get_chromosome()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_chromosome {
    my $self = shift;
    my $chr_nr = shift;

    my $map_factory = CXGN::Cview::MapFactory->new($self->get_dbh());
    my $id = get_db_id($self->get_dbh(), $self->get_id());
    print STDERR "get_chromosome $id.\n";
    my $genetic_map = $map_factory->create({map_version_id=>$id});
    my $genetic=$genetic_map->get_chromosome($chr_nr);
    my $chromosome = CXGN::Cview::Chromosome::Physical->new();

    my $largest_offset = 0;


    my $basepath = CXGN::VHost->new()->get_conf("basepath");
    my $gff = Bio::DB::GFF->new(
			   -adaptor => 'berkeleydb',
			   -dsn     => '/data/prod/public/tomato_genome/physical_mapping/fpc/SGN_2009/gbrowse/curr' #$basepath."/documents/gbrowse/databases/fpc/SGN_2009", #tomato_R12_dQ",
			  );


    foreach my $m ($genetic->get_markers()) { 
	$m->set_chromosome($chromosome);
	$chromosome->add_marker($m);
	my $offset = $m->get_offset();
	if ($offset > $largest_offset) { 
	    $largest_offset=$offset;
	}
	$m->hide();
	
	my @gff_markers = $gff->features(-method => 'marker',
		       -attributes => { Name => $m->get_name() },
		       );
	my @contigs = ();
	foreach my $gm (@gff_markers) { 
	    @contigs = $gm->refseq();
	}
	my $count = 0;
	foreach my $c (@contigs) { 
	    my $contig = CXGN::Cview::Marker::Physical->new();
	    $contig->set_chromosome($chromosome);
	    $contig->set_name($c);
	    
	    #my $url = "/gbrowse/gbrowse/sanger_tomato_fpc/?name=$c";
	    my $url = "/gbrowse/gbrowse/fpc_tomato_sgn_2009/?name=$c";
	    $contig->set_marker_name($c);
	    $contig->set_marker_type("contig");
	    $contig->set_url("$url");
	    $contig->set_offset($m->get_offset());
	    $contig->get_label()->set_name($c);
	    $contig->get_label()->set_url($url);
	    $contig->set_tooltip("Contig: $c. Anchored to: ".($m->get_name()).".");
	    $chromosome -> add_marker($contig);
	    $count++;
	}   
    }
    $chromosome->set_length($largest_offset);
    $self->{chr}->[$chr_nr]=$chromosome;
    return $chromosome;
   
}

=head2 function get_overview_chromosome()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_overview_chromosome {
    my $self = shift;
    my $chr_nr = shift;
    
    my $bargraph = CXGN::Cview::Chromosome::BarGraph->new();

    my $largest_offset = 0;
    
    my $chromosome = $self->get_chromosome($chr_nr);
    
    foreach my $m ($chromosome->get_markers()) { 
	if ($m->get_marker_type() eq "contig") { 
	    
	    my $offset = $m->get_offset();
	    $bargraph -> add_association("manual", $offset, 1);
	    if ($offset>$largest_offset) { $largest_offset = $offset; }
	}
    }   
    return $bargraph;
}

=head2 function get_chromosome_connections()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_chromosome_connections {
    my $self = shift;
    my $chr_nr = shift;
    my @list = ();
    # this map has no connections.!!!!
#    push @list, { map_version_id=>CXGN::Cview::Map::Tools::find_current_version($self->get_dbh(), CXGN::Cview::Map::Tools::current_tomato_map_id), lg_name=>$chr_nr, marker_count=>"?", short_name=>"F2-2000" };
    return @list;
}

sub get_db_id { 
    my $dbh = shift;
    my $id = shift;
    my $db_id = $id;
    $db_id=~s/^.*(\d+)$/$1/;
    return CXGN::Cview::Map::Tools::find_current_version($dbh, $db_id);
}


sub can_zoom { 
    return 0;
}

sub get_marker_link { 
    my $self = shift;
    my $clone_id= shift; 
    if ($clone_id) { return ""; }
    else { return ""; }
}

sub get_marker_count { 
    my $self = shift;
    my $chr_nr = shift;

    my @markers = $self->{chr}->[$chr_nr]->get_markers();
   
    my $count = 0;
    foreach my $m (@markers) { 
	if ($m->get_marker_name()=~ /^ctg/) { 
	    $count++;
	}
    }
    

    return $count; 
}

sub get_map_stats { 
    my $self = shift;

    my $count = 0;
    foreach my $c (1..12) { 
	$count += $self->get_marker_count($c);
    }
    
    return "$count contigs have been assigned to this map";


}

=head2 get_abstract

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_abstract {



#<p>This map shows the contig positions of the Sanger 2006 combined HindIII/MboI contigs, based on the information in the FPC build files. The marker positions are shown as they appear on the most current <a href="/cview/map.pl?map_id=9">EXPEN2000</a> map. </p>

    return <<ABSTRACT;

<p>This map shows the contig positions of the SGN2009 physical map constructed at the Arizona Genome Institute in late 2009. The marker positions shown are from the latest <a href="/cview/map.pl?map_id=9">EXPEN2000 map</a>.</p>

<p>This physical map contains clones from the HindIII, EcoRI, MboI and sheared BAC library.</p>

<p>This overview shows the counts of contigs along the chromosome. Click on any chromosome to view the individual contigs. More information on each contig can be obtained by by clicking on a specific contig.

<p>Specific contig IDs, including contigs that are not mapped, can be searched on the <a href="/gbrowse/gbrowse/fpc_tomato_sgn_2009/">FPC viewer page</a>.</p>
<br />



ABSTRACT



}




return 1;
