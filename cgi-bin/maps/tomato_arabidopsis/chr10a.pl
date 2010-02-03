use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr10a.html','html2pl converter');
$page->header('Chromosome 10');
print<<END_HEREDOC;

  <br />
  <br />

  <center>
<h1><a href="chr10_split.pl">Chromosome 10</a></h1>
  <h3>- Section A -</h3>

    <br />
    <br />

    <table summary="">
      <tr>
        <td align="right" valign="top"><img alt="" align="left"
        src="/documents/maps/tomato_arabidopsis/map_images/chr10a.png" border="none" /></td>

      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();