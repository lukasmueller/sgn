use strict;
use warnings;

use CXGN::Scrap::AjaxPage;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();
my ($locus_id, $individual_id) = $doc->get_encoded_arguments("locus_id", "individual_id");

my $dbh = CXGN::DB::Connection->new();

my $allele_query = $dbh->prepare("SELECT DISTINCT(allele.allele_id), allele.allele_symbol, allele.allele_name, is_default FROM phenome.allele LEFT JOIN phenome.individual_allele USING(allele_id) WHERE allele.obsolete = 'false' AND locus_id=? AND allele_id NOT IN (SELECT allele_id from phenome.individual_allele WHERE individual_id = ? AND obsolete = 'f' ) ORDER BY is_default DESC");
$allele_query->execute($locus_id, $individual_id);

my ($allele_id, $allele_symbol, $allele_name) = $allele_query->fetchrow_array();
my $available_alleles;

while($allele_id){
    if($allele_symbol eq ""){
	$allele_symbol = 'default';
    }
    $available_alleles .= "$allele_id*$allele_symbol|";
    ($allele_id, $allele_symbol, $allele_name) = $allele_query->fetchrow_array();
}

print "$available_alleles";
