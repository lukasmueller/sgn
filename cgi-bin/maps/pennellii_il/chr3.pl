use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr3.html','html2pl converter');
$page->header('L. Pennellii Chromosome 3');
print<<END_HEREDOC;

  <img alt="" src="/documents/maps/pennellii_il/Slide3.PNG" />
END_HEREDOC
$page->footer();
