#!/usr/bin/perl -w

use strict;
use blib;

use Test::More tests => 22;
use Test::Exception;
#use Data::Dumper;

BEGIN { use_ok('Search::Estraier') };

ok(my $cond = new Search::Estraier::Condition, 'new');
isa_ok($cond, 'Search::Estraier::Condition');

cmp_ok($cond->max, '==', -1, 'max');
cmp_ok($cond->options, '==', 0, 'options');

ok($cond->set_phrase('search'), 'set_phrase');
ok($cond->add_attr('@foo BAR baz'), 'set_attr');
ok($cond->set_order('@foo ASC'), 'set_order');
ok($cond->set_max(42), 'set_max, number');
throws_ok { $cond->set_max('foo') } qr/number/, 'set_max, NaN';

foreach my $opt (qw/SURE USUAL FAST AGITO NOIDF SIMPLE/) {
	ok($cond->set_options( $opt ), 'set_option '.$opt);
}

my $v;
cmp_ok($v = $cond->phrase, 'eq', 'search', "phrase: $v");
cmp_ok($v = $cond->max, '==', 42, "max: $v");
cmp_ok($v = $cond->options, '!=', 0, "options: $v");

#diag "attrs: ",join(",",$cond->attrs);
cmp_ok($cond->attrs, '==', 1, 'one attrs');
ok($cond->add_attr('@foo2 BAR2 baz2'), 'set_attr');
#diag "attrs: ",join(",",$cond->attrs);
cmp_ok($cond->attrs, '==', 2, 'two attrs');
