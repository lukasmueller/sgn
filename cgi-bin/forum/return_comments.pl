#!/usr/bin/perl
use strict; 

# this script is for ajax use. It just returns the comment html, nothing else.

print "Content-type: text/html\n\n";



use CXGN::Page;
use CXGN::DB::Connection;

my $page = CXGN::Page->new();
my $dbh = CXGN::DB::Connection->new();

my %things = $page->get_all_encoded_arguments();


use CXGN::People::PageComment;
my $referer = $things{referer} || $page->{request}->uri()."?".$page->{request}->args();
warn "referer is $referer\n";
my $ch = CXGN::People::PageComment->new($dbh, $things{type},$things{id})->get_html($referer);
warn "html is $ch";

print '<!-- brought to you by ajax -->'.$ch;

