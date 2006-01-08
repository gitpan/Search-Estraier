#!/usr/bin/perl -w

use strict;
use blib;

use Test::More tests => 37;
use Test::Exception;
use Data::Dumper;

BEGIN { use_ok('Search::Estraier') };

#print Search::Estraier::Document::_s('foo');

#cmp_ok(Search::Estraier::Document::_s("  this  is a  text  "), 'eq', 'this is a text', '_s - strip spaces');


my $attr_data = {
	'@uri' => 'http://localhost/Search-Estraier/',
	'size' => 42,
};

my @test_texts = (
	'This is a test',
	'of pure-perl bindings',
	'for HyperEstraier'
);

ok(my $doc = new Search::Estraier::Document, 'new');

isa_ok($doc, 'Search::Estraier::Document');

cmp_ok($doc->id, '==', -1, 'id');

ok($doc->delete, "delete");

ok($doc = new Search::Estraier::Document, 'new');

foreach my $a (keys %{$attr_data}) {
	my $d = $attr_data->{$a} || die;
	ok($doc->add_attr($a, $d), "add_attr $a");
	cmp_ok($doc->attr($a), 'eq', $d, "attr $a = $d");
}

foreach my $t (@test_texts) {
	ok($doc->add_text($t), "add_text: $t");
}

ok($doc->add_hidden_text('This is hidden text'), 'add_hidden_text');

ok(my @texts = $doc->texts, 'texts');

ok(my $draft = $doc->dump_draft, 'dump_draft');

#diag "dump_draft:\n$draft";

ok(my $doc2 = new Search::Estraier::Document($draft), 'new from draft');
cmp_ok($doc2->dump_draft, 'eq', $draft, 'drafts same');

cmp_ok($doc->id, '==', -1, 'id');
cmp_ok($doc2->id, '==', -1, 'id');

ok(my @attr = $doc->attr_names, 'attr_names');
#diag "attr_names: ", join(',',@attr), "\n";

cmp_ok(scalar @attr, '==', 2, 'attr_names');

ok(! $doc->attr('foobar'), "non-existant attr");

foreach my $a (keys %{$attr_data}) {
	cmp_ok($attr_data->{$a}, 'eq', $doc->attr($a), "attr $a = ".$attr_data->{$a});
	ok($doc->add_attr($a, undef), "delete attribute");
}

@attr = $doc->attr_names;
#diag "attr_names left: ", join(',',$doc->attr_names), "\n";
cmp_ok(@attr, '==' , 0, "attributes removed");

#diag "texts: ", join(',',@texts), "\n";
ok(eq_array(\@test_texts, \@texts), 'texts');

ok(my $cat_text = $doc->cat_texts, 'cat_text');
#diag "cat_texts: $cat_text";

ok($doc = new Search::Estraier::Document, 'new empty');
ok(! $doc->texts, 'texts');
cmp_ok($doc->dump_draft, 'eq', "\n", 'dump_draft');
cmp_ok($doc->id, '==', -1, 'id');
ok(! $doc->attr_names, 'attr_names');
ok(! $doc->attr(undef), 'attr');
ok(! $doc->cat_texts, 'cat_texts');

#diag Dumper($doc);
