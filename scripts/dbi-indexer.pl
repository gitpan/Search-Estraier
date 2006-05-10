#!/usr/bin/perl -w

use strict;
use Search::Estraier;
use DBI;
use Data::Dumper;
use Encode qw/from_to/;

=head1 NAME

dbi-indexer.pl - example indexer of DBI sources for Search::Estraier

=cut

my $node_url = 'http://localhost:1978/node/dbi';
my $dbi = 'Pg:dbname=azop';
my $sql = qq{
	select * from history_collection_view_cache
};
my $debug = 0;

# create and configure node
my $node = new Search::Estraier::Node(
	url => $node_url,
	user => 'admin',
	passwd => 'admin',
	croak_on_error => 1,
	debug => $debug,
);

# create DBI connection
my $dbh = DBI->connect("DBI:$dbi","","") || die $DBI::errstr;

my $sth = $dbh->prepare($sql) || die $dbh->errstr();
$sth->execute() || die $sth->errstr();

warn "# columns: ",join(",",@{ $sth->{NAME} }),"\n" if ($debug);

my $total = $sth->rows;
my $i = 1;

while (my $row = $sth->fetchrow_hashref() ) {

	warn "# row: ",Dumper($row) if ($debug);

	# create document
	my $doc = new Search::Estraier::Document;

	$doc->add_attr('@uri', $row->{_id});

	printf "%4d ",$i;

	while (my ($col,$val) = each %{$row}) {

		if ($val) {
			# change encoding?
			from_to($val, 'ISO-8859-2', 'UTF-8');

			# add attributes (make column usable from attribute search)
			$doc->add_attr($col, $val);

			# add body text to document (make it searchable using full-text index)
			$doc->add_text($val);

			print "R";
		} else {
			print ".";
		}

	}

	print " ", int(( $i++ / $total) * 100), "%\n";

	warn "# doc draft: ",$doc->dump_draft, "\n" if ($debug);

	die "error: ", $node->status,"\n" unless (eval { $node->put_doc($doc) });
}
