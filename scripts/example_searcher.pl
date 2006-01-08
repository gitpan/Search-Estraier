#!/usr/bin/perl -w

use strict;
use Search::Estraier;

=head1 NAME

example_searcher.pl - example searcher for Search::Estraier

=cut

# create and configure node
my $node = new Search::Estraier::Node;
$node->set_url("http://localhost:1978/node/test");
$node->set_auth("admin","admin");

# create condition
my $cond = new Search::Estraier::Condition;

# set search phrase
$cond->set_phrase("rainbow AND lullaby");

my $nres = $node->search($cond, 0);
if (defined($nres)) {
	# for each document in results
	for my $i ( 0 ... $nres->doc_num - 1 ) {
		# get result document
		my $rdoc = $nres->get_doc($i);
		# display attribte
		print "URI: ", $rdoc->attr('@uri'),"\n";
		print "Title: ", $rdoc->attr('@title'),"\n";
		print $rdoc->snippet,"\n";
	}
} else {
	die "error: ", $node->status,"\n";
}
