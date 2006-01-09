#!/usr/bin/perl -w

use strict;
use blib;

use Test::More tests => 95;
use Test::Exception;
use Data::Dumper;

BEGIN { use_ok('Search::Estraier') };

my $debug = 0;

# name of node for test
my $test_node = 'test1';
my $test1_node = 'test2';

ok(my $node = new Search::Estraier::Node( debug => $debug ), 'new');
isa_ok($node, 'Search::Estraier::Node');

ok($node->set_url("http://localhost:1978/node/$test_node"), "set_url $test_node");

ok($node->set_proxy('', 8080), 'set_proxy');
throws_ok {$node->set_proxy('proxy.example.com', 'foo') } qr/port/, 'set_proxy port NaN';

ok($node->set_timeout(42), 'set_timeout');
throws_ok {$node->set_timeout('foo') } qr/timeout/, 'set_timeout NaN';

ok($node->set_auth('admin','admin'), 'set_auth');

cmp_ok($node->status, '==', -1, 'status');

SKIP: {

skip "no $test_node node in Hyper Estraier", 85, unless($node->name);

my @res = ( -1, 200 );

my $nodelist;
foreach my $url (qw{?action=nodelist http://localhost:1978/master?action=nodelist}) {
	cmp_ok(
		$node->shuttle_url( $url, 'text/plain', undef, \$nodelist)
	,'==', shift @res, 'nodelist');
}

my $draft = <<'_END_OF_DRAFT_';
@uri=data001
@title=Material Girl

Living in a material world
And I am a material girl
You know that we are living in a material world
And I am a material girl
_END_OF_DRAFT_

#diag "draft:\n$draft";
ok(my $doc = new Search::Estraier::Document($draft), 'new doc from draft');

ok( $node->put_doc($doc), "put_doc data001");

for ( 1 .. 10 ) {
	$doc->add_attr('@uri', 'test' . $_);
	ok( $node->put_doc($doc), "put_doc test$_");
	#diag $doc->dump_draft;
}

my $id;
ok($id = $node->uri_to_id( 'data001' ), "uri_to_id = $id");

for ( 1 .. 5 ) {
	ok( $node->out_doc_by_uri( 'test' . $_ ), "out_doc_by_uri test$_");
}

ok($doc = $node->get_doc( $id ), 'get_doc for edit');
$doc->add_attr('foo', 'bar');
#diag Dumper($doc);
ok( $node->edit_doc( $doc ), 'edit_doc');

ok( $node->out_doc( $id ), "out_doc $id");

ok( ! $node->edit_doc( $doc ), "edit removed");

my $max = 3;

ok(my $cond = new Search::Estraier::Condition, 'new cond');
ok($cond->set_phrase('girl'), 'cond set_phrase');
ok($cond->set_max($max), "cond set_max $max");
ok($cond->set_order('@uri ASCD'), 'cond set_order');
ok($cond->add_attr('@title STRINC Material'), 'cond add_attr');

cmp_ok($node->cond_to_query( $cond ), 'eq' , 'phrase=girl&attr1=%40title%20STRINC%20Material&order=%40uri%20ASCD&max='.$max.'&wwidth=480&hwidth=96&awidth=96', 'cond_to_query');

ok( my $nrec = $node->search( $cond, 0 ), 'search');

isa_ok( $nrec, 'Search::Estraier::NodeResult' );

cmp_ok($nrec->doc_num, '==', $max, "doc_num = $max");

for ( 6 .. 10 ) {
	my $uri = 'test' . $_;
	ok( my $id = $node->uri_to_id( $uri ), "uri_to_id $uri");
	ok( $node->get_doc( $id ), "get_doc $id");
	ok( $node->get_doc_by_uri( $uri ), "get_doc_by_uri $uri");
	cmp_ok( $node->get_doc_attr( $id, '@uri' ), 'eq', $uri, "get_doc_attr $id");
	cmp_ok( $node->get_doc_attr_by_uri( $uri, '@uri' ), 'eq', $uri, "get_doc_attr $id");
	ok( my $k = $node->etch_doc( $id ), "etch_doc_by_uri $uri");
	ok( my $k2 = $node->etch_doc_by_uri( $uri ), "etch_doc_by_uri $uri");
	#diag Dumper($k, $k2);
	ok( eq_hash( $k, $k2 ), "keywords");
}

ok($node->_set_info, "refresh _set_info");

my $v;
ok($v = $node->name, "name: $v");
ok($v = $node->label, "label: $v");
ok($v = $node->doc_num, "doc_num: $v");
ok($v = $node->word_num, "word_num: $v");
ok($v = $node->size, "size: $v");

ok($node->set_snippet_width( 100, 10, 10 ), "set_snippet_width");

# user doesn't exist
ok(! $node->set_user('foobar', 1), 'set_user');

ok(my $node1 = new Search::Estraier::Node( "http://localhost:1978/node/$test1_node" ), "new $test1_node");
ok($node1->set_auth('admin','admin'), "set_auth $test1_node");

SKIP: {
	skip "no $test1_node in Hyper Estraier, skipping set_link", 2 unless (my $test1_label = $node1->label);

	ok($node->set_link("http://localhost:1978/node/$test1_node", $test1_label, 42), "set_link $test1_node ($test1_label) 42");
	ok($node->set_link("http://localhost:1978/node/$test1_node", $test1_label, 0), "set_link $test1_node ($test1_label) delete");
}	# SKIP 2

}	# SKIP 1

diag "over";
