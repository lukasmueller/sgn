
use strict;
use lib 't/lib';

use Data::Dumper;
use Test::More qw | no_plan |;
use SGN::Test::Fixture;
use CXGN::Cview::MapFactory;
use CXGN::Cview::Map::Genotype;

my $f = SGN::Test::Fixture->new();

print STDERR "Creating the MapFactory...\n";
my $mf = CXGN::Cview::MapFactory->new($f->dbh());

print STDERR "Initializing a map...\n";
my $map = $mf->create({ map_id => 'g1622' });
 
print STDERR "Done.\n";
my $chr = $map->get_chromosome("S8265");
my @markers = $chr->get_markers();

#print STDERR "CHROMOSOME: ".Dumper($chr)."\n";
print STDERR "Marker count: ".scalar(@markers)."\n";

done_testing();
