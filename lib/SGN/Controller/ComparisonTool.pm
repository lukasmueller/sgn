
package SGN::Controller::ComparisonTool;

use Moose;
use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller'; }


sub trial_comparison_input :Path('/tools/ComparisonTools') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user) {
        $c->res->redirect(uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }
    $c->stash->{template} = '/tools/ComparisonTools/Index.mas';
    
}

1;
