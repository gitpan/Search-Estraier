#!/usr/bin/perl -w

use strict;
use blib;

use Test::More tests => 115;
use Test::Exception;
use Data::Dumper;

BEGIN { use_ok('Search::Estraier') };

my $debug = 0;

# name of node for test
my $test1_node = 'test1';
my $test2_node = 'test2';

ok(my $node = new Search::Estraier::Node( debug => $debug ), 'new');
isa_ok($node, 'Search::Estraier::Node');

ok($node->set_url("http://localhost:1978/node/$test1_node"), "set_url $test1_node");

ok($node->set_proxy('', 8080), 'set_proxy');
throws_ok {$node->set_proxy('proxy.example.com', 'foo') } qr/port/, 'set_proxy port NaN';

ok($node->set_timeout(42), 'set_timeout');
throws_ok {$node->set_timeout('foo') } qr/timeout/, 'set_timeout NaN';

ok($node->set_auth('admin','admin'), 'set_auth');

cmp_ok($node->status, '==', -1, 'status');

SKIP: {

skip "no $test1_node node in Hyper Estraier", 105, unless($node->name);

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

my $data_max = 5;

for ( 1 .. $data_max ) {
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

ok( my $nres = $node->search( $cond, 0 ), 'search');

isa_ok( $nres, 'Search::Estraier::NodeResult' );

cmp_ok($nres->doc_num, '==', $max, "doc_num = $max");

cmp_ok($nres->hits, '==', $data_max, "hits");

for my $i ( 0 .. ($nres->hits - 1) ) {
	my $uri = 'test' . ($i + $data_max + 1);

	if ($i < $nres->doc_num) {
		ok( my $rdoc = $nres->get_doc( $i ), "get_doc $i");

		cmp_ok( $rdoc->attr('@uri'), 'eq', $uri, "\@uri = $uri");
		ok( my $k = $rdoc->keywords( $id ), "rdoc keywords");
	}

	ok( my $id = $node->uri_to_id( $uri ), "uri_to_id($uri) = $id");
	ok( $node->get_doc( $id ), "get_doc $id");
	ok( $node->get_doc_by_uri( $uri ), "get_doc_by_uri $uri");
	cmp_ok( $node->get_doc_attr( $id, '@uri' ), 'eq', $uri, "get_doc_attr $id");
	cmp_ok( $node->get_doc_attr_by_uri( $uri, '@uri' ), 'eq', $uri, "get_doc_attr $id");
	ok( my $k1 = $node->etch_doc( $id ), "etch_doc_by_uri $uri");
	ok( my $k2 = $node->etch_doc_by_uri( $uri ), "etch_doc_by_uri $uri");
	#diag Dumper($k, $k2);
	ok( eq_hash( $k1, $k2 ), "keywords");
}

ok(my $hints = $nres->hints, 'hints');
diag Dumper($hints);

ok($node->_set_info, "refresh _set_info");

my $v;
ok($v = $node->name, "name: $v");
ok($v = $node->label, "label: $v");
ok($v = $node->doc_num, "doc_num: $v");
ok(defined($v = $node->word_num), "word_num: $v");
ok($v = $node->size, "size: $v");

ok($node->set_snippet_width( 100, 10, 10 ), "set_snippet_width");

# user doesn't exist
ok(! $node->set_user('foobar', 1), 'set_user');

ok(my $node2 = new Search::Estraier::Node( "http://localhost:1978/node/$test2_node" ), "new $test2_node");
ok($node2->set_auth('admin','admin'), "set_auth $test2_node");

# croak_on_error

ok($node = new Search::Estraier::Node( url => "http://localhost:1978/non-existant", croak_on_error => 1 ), "new non-existant");
throws_ok { $node->name } qr/404/, 'croak on error';

# croak_on_error
ok($node = new Search::Estraier::Node( url => "http://localhost:1978/node/$test1_node", croak_on_error => 1 ), "new $test1_node");

ok(! $node->uri_to_id('foobar'), 'uri_to_id without croak');

# test users

ok(! $node->admins, 'no admins');
ok(! $node->guests, 'no guests');

SKIP: {
	skip "no $test2_node in Hyper Estraier, skipping set_link", 5 unless (my $test2_label = $node2->label);

	my $link_url = "http://localhost:1978/node/$test2_node";

	ok($node->set_link( $link_url, $test2_label, 42), "set_link $test2_node ($test2_label) 42");

	ok(my $links = $node->links, 'links');

	cmp_ok($#{$links}, '==', 0, 'one link');

	like($links->[0], qr/^$link_url/, 'link correct');

	ok($node->set_link("http://localhost:1978/node/$test2_node", $test2_label, 0), "set_link $test2_node ($test2_label) delete");
}	# SKIP 2

}	# SKIP 1

diag "over";
