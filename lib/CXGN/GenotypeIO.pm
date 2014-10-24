
package CXGN::GenotypeIO;

use Moose;
use JSON::Any;
use CXGN::Genotype;

use CXGN::GenotypeIOmain;

has 'count' => ( isa => 'Int',
		 is  => 'rw',
    );

has 'current' => ( isa => 'Int',
		   is  => 'rw',
    );

has 'header' => ( isa => 'ArrayRef',
		  is  => 'rw',
    );

has 'file'  => ( isa => 'Str',
		 is  => 'rw',
		 required => 1,
    );

has 'format' => ( isa => 'Str',
		  is  => 'rw',
		  default => 'vcf', # or dosage
    );

has 'plugin' => ( isa => 'Ref',
		  is  => 'rw',
    );

sub BUILD { 
    my $self = shift;
    my $args = shift;

    my $plugin = CXGN::GenotypeIOmain->new( { file => $args->{file} });

    if ($args->{format} eq "vcf") { 
	$plugin->load_plugin("VCF");
    }
    my $data = $plugin->init($args);    
    
    $self->plugin($plugin);

    print STDERR "count = $data->{count}\n";
    $self->count($data->{count});
    $self->header($data->{header});
    $self->current(0);
}

sub next { 
    my $self  =shift;
   
    my $data = $self->plugin()->next($self->file(), $self->current());

    my $gt = CXGN::Genotype->new();

    $gt->markerscores($data);
    my @markers = keys(%$data);
    $gt->markers(\@markers);

    $self->current( $self->current() + 1 );

    return $gt;

}

1;
