package Search::Estraier;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.03';

=head1 NAME

Search::Estraier - pure perl module to use Hyper Estraier search engine

=head1 SYNOPSIS

=head2 Simple indexer

	use Search::Estraier;

	# create and configure node
	my $node = new Search::Estraier::Node;
	$node->set_url("http://localhost:1978/node/test");
	$node->set_auth("admin","admin");

	# create document
	my $doc = new Search::Estraier::Document;

	# add attributes
	$doc->add_attr('@uri', "http://estraier.gov/example.txt");
	$doc->add_attr('@title', "Over the Rainbow");

	# add body text to document
	$doc->add_text("Somewhere over the rainbow.  Way up high.");
	$doc->add_text("There's a land that I heard of once in a lullaby.");

	die "error: ", $node->status,"\n" unless ($node->put_doc($doc));

=head2 Simple searcher

	use Search::Estraier;

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

=head1 DESCRIPTION

This module is implementation of node API of Hyper Estraier. Since it's
perl-only module with dependencies only on standard perl modules, it will
run on all platforms on which perl runs. It doesn't require compilation
or Hyper Estraier development files on target machine.

It is implemented as multiple packages which closly resamble Ruby
implementation. It also includes methods to manage nodes.

There are few examples in C<scripts> directory of this distribution.

=cut

=head1 Inheritable common methods

This methods should really move somewhere else.

=head2 _s

Remove multiple whitespaces from string, as well as whitespaces at beginning or end

 my $text = $self->_s(" this  is a text  ");
 $text = 'this is a text';

=cut

sub _s {
	my $text = $_[1] || return;
	$text =~ s/\s\s+/ /gs;
	$text =~ s/^\s+//;
	$text =~ s/\s+$//;
	return $text;
}

package Search::Estraier::Document;

use Carp qw/croak confess/;

use Search::Estraier;
our @ISA = qw/Search::Estraier/;

=head1 Search::Estraier::Document

This class implements Document which is collection of attributes
(key=value), vectors (also key value) display text and hidden text.


=head2 new

Create new document, empty or from draft.

  my $doc = new Search::HyperEstraier::Document;
  my $doc2 = new Search::HyperEstraier::Document( $draft );

=cut

sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);

	$self->{id} = -1;

	my $draft = shift;

	if ($draft) {
		my $in_text = 0;
		foreach my $line (split(/\n/, $draft)) {

			if ($in_text) {
				if ($line =~ /^\t/) {
					push @{ $self->{htexts} }, substr($line, 1);
				} else {
					push @{ $self->{dtexts} }, $line;
				}
				next;
			}

			if ($line =~ m/^%VECTOR\t(.+)$/) {
				my @fields = split(/\t/, $1);
				for my $i ( 0 .. ($#fields - 1) ) {
					$self->{kwords}->{ $fields[ $i ] } = $fields[ $i + 1 ];
					$i++;
				}
				next;
			} elsif ($line =~ m/^%/) {
				# What is this? comment?
				#warn "$line\n";
				next;
			} elsif ($line =~ m/^$/) {
				$in_text = 1;
				next;
			} elsif ($line =~ m/^(.+)=(.+)$/) {
				$self->{attrs}->{ $1 } = $2;
				next;
			}

			warn "draft ignored: $line\n";
		}
	}

	$self ? return $self : return undef;
}


=head2 add_attr

Add an attribute.

  $doc->add_attr( name => 'value' );

Delete attribute using

  $doc->add_attr( name => undef );

=cut

sub add_attr {
	my $self = shift;
	my $attrs = {@_};

	while (my ($name, $value) = each %{ $attrs }) {
		if (! defined($value)) {
			delete( $self->{attrs}->{ $self->_s($name) } );
		} else {
			$self->{attrs}->{ $self->_s($name) } = $self->_s($value);
		}
	}

	return 1;
}


=head2 add_text

Add a sentence of text.

  $doc->add_text('this is example text to display');

=cut

sub add_text {
	my $self = shift;
	my $text = shift;
	return unless defined($text);

	push @{ $self->{dtexts} }, $self->_s($text);
}


=head2 add_hidden_text

Add a hidden sentence.

  $doc->add_hidden_text('this is example text just for search');

=cut

sub add_hidden_text {
	my $self = shift;
	my $text = shift;
	return unless defined($text);

	push @{ $self->{htexts} }, $self->_s($text);
}


=head2 id

Get the ID number of document. If the object has never been registred, C<-1> is returned.

  print $doc->id;

=cut

sub id {
	my $self = shift;
	return $self->{id};
}


=head2 attr_names

Returns array with attribute names from document object.

  my @attrs = $doc->attr_names;

=cut

sub attr_names {
	my $self = shift;
	return unless ($self->{attrs});
	#croak "attr_names return array, not scalar" if (! wantarray);
	return sort keys %{ $self->{attrs} };
}


=head2 attr

Returns value of an attribute.

  my $value = $doc->attr( 'attribute' );

=cut

sub attr {
	my $self = shift;
	my $name = shift;
	return unless (defined($name) && $self->{attrs});
	return $self->{attrs}->{ $name };
}


=head2 texts

Returns array with text sentences.

  my @texts = $doc->texts;

=cut

sub texts {
	my $self = shift;
	#confess "texts return array, not scalar" if (! wantarray);
	return @{ $self->{dtexts} } if ($self->{dtexts});
}


=head2 cat_texts

Return whole text as single scalar.

 my $text = $doc->cat_texts;

=cut

sub cat_texts {
	my $self = shift;
	return join(' ',@{ $self->{dtexts} }) if ($self->{dtexts});
}


=head2 dump_draft

Dump draft data from document object.

  print $doc->dump_draft;

=cut

sub dump_draft {
	my $self = shift;
	my $draft;

	foreach my $attr_name (sort keys %{ $self->{attrs} }) {
		$draft .= $attr_name . '=' . $self->{attrs}->{$attr_name} . "\n";
	}

	if ($self->{kwords}) {
		$draft .= '%%VECTOR';
		while (my ($key, $value) = each %{ $self->{kwords} }) {
			$draft .= "\t$key\t$value";
		}
		$draft .= "\n";
	}

	$draft .= "\n";

	$draft .= join("\n", @{ $self->{dtexts} }) . "\n" if ($self->{dtexts});
	$draft .= "\t" . join("\n\t", @{ $self->{htexts} }) . "\n" if ($self->{htexts});

	return $draft;
}


=head2 delete

Empty document object

  $doc->delete;

This function is addition to original Ruby API, and since it was included in C wrappers it's here as a
convinience. Document objects which go out of scope will be destroyed
automatically.

=cut

sub delete {
	my $self = shift;

	foreach my $data (qw/attrs dtexts stexts kwords/) {
		delete($self->{$data});
	}

	$self->{id} = -1;

	return 1;
}



package Search::Estraier::Condition;

use Carp qw/confess croak/;

use Search::Estraier;
our @ISA = qw/Search::Estraier/;

=head1 Search::Estraier::Condition

=head2 new

  my $cond = new Search::HyperEstraier::Condition;

=cut

sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);

	$self->{max} = -1;
	$self->{options} = 0;

	$self ? return $self : return undef;
}


=head2 set_phrase

  $cond->set_phrase('search phrase');

=cut

sub set_phrase {
	my $self = shift;
	$self->{phrase} = $self->_s( shift );
}


=head2 add_attr

  $cond->add_attr('@URI STRINC /~dpavlin/');

=cut

sub add_attr {
	my $self = shift;
	my $attr = shift || return;
	push @{ $self->{attrs} }, $self->_s( $attr );
}


=head2 set_order

  $cond->set_order('@mdate NUMD');

=cut

sub set_order {
	my $self = shift;
	$self->{order} = shift;
}


=head2 set_max

  $cond->set_max(42);

=cut

sub set_max {
	my $self = shift;
	my $max = shift;
	croak "set_max needs number, not '$max'" unless ($max =~ m/^\d+$/);
	$self->{max} = $max;
}


=head2 set_options

  $cond->set_options( SURE => 1 );

=cut

my $options = {
	# check N-gram keys skipping by three
	SURE => 1 << 0,
	# check N-gram keys skipping by two
	USUAL => 1 << 1,
	# without TF-IDF tuning
	FAST => 1 << 2,
	# with the simplified phrase
	AGITO => 1 << 3,
	# check every N-gram key
	NOIDF => 1 << 4,
	# check N-gram keys skipping by one
	SIMPLE => 1 << 10,
};

sub set_options {
	my $self = shift;
	my $option = shift;
	confess "unknown option" unless ($options->{$option});
	$self->{options} ||= $options->{$option};
}


=head2 phrase

Return search phrase.

  print $cond->phrase;

=cut

sub phrase {
	my $self = shift;
	return $self->{phrase};
}


=head2 order

Return search result order.

  print $cond->order;

=cut

sub order {
	my $self = shift;
	return $self->{order};
}


=head2 attrs

Return search result attrs.

  my @cond_attrs = $cond->attrs;

=cut

sub attrs {
	my $self = shift;
	#croak "attrs return array, not scalar" if (! wantarray);
	return @{ $self->{attrs} } if ($self->{attrs});
}


=head2 max

Return maximum number of results.

  print $cond->max;

C<-1> is returned for unitialized value, C<0> is unlimited.

=cut

sub max {
	my $self = shift;
	return $self->{max};
}


=head2 options

Return options for this condition.

  print $cond->options;

Options are returned in numerical form.

=cut

sub options {
	my $self = shift;
	return $self->{options};
}


package Search::Estraier::ResultDocument;

use Carp qw/croak/;

#use Search::Estraier;
#our @ISA = qw/Search::Estraier/;

=head1 Search::Estraier::ResultDocument

=head2 new

  my $rdoc = new Search::HyperEstraier::ResultDocument(
  	uri => 'http://localhost/document/uri/42',
	attrs => {
		foo => 1,
		bar => 2,
	},
	snippet => 'this is a text of snippet'
	keywords => 'this\tare\tkeywords'
  );

=cut

sub new {
	my $class = shift;
	my $self = {@_};
	bless($self, $class);

	croak "missing uri for ResultDocument" unless defined($self->{uri});

	$self ? return $self : return undef;
}


=head2 uri

Return URI of result document

  print $rdoc->uri;

=cut

sub uri {
	my $self = shift;
	return $self->{uri};
}


=head2 attr_names

Returns array with attribute names from result document object.

  my @attrs = $rdoc->attr_names;

=cut

sub attr_names {
	my $self = shift;
	croak "attr_names return array, not scalar" if (! wantarray);
	return sort keys %{ $self->{attrs} };
}


=head2 attr

Returns value of an attribute.

  my $value = $rdoc->attr( 'attribute' );

=cut

sub attr {
	my $self = shift;
	my $name = shift || return;
	return $self->{attrs}->{ $name };
}


=head2 snippet

Return snippet from result document

  print $rdoc->snippet;

=cut

sub snippet {
	my $self = shift;
	return $self->{snippet};
}


=head2 keywords

Return keywords from result document

  print $rdoc->keywords;

=cut

sub keywords {
	my $self = shift;
	return $self->{keywords};
}


package Search::Estraier::NodeResult;

use Carp qw/croak/;

#use Search::Estraier;
#our @ISA = qw/Search::Estraier/;

=head1 Search::Estraier::NodeResult

=head2 new

  my $res = new Search::HyperEstraier::NodeResult(
  	docs => @array_of_rdocs,
	hits => %hash_with_hints,
  );

=cut

sub new {
	my $class = shift;
	my $self = {@_};
	bless($self, $class);

	foreach my $f (qw/docs hints/) {
		croak "missing $f for ResultDocument" unless defined($self->{$f});
	}

	$self ? return $self : return undef;
}


=head2 doc_num

Return number of documents

  print $res->doc_num;

=cut

sub doc_num {
	my $self = shift;
	return $#{$self->{docs}} + 1;
}


=head2 get_doc

Return single document

  my $doc = $res->get_doc( 42 );

Returns undef if document doesn't exist.

=cut

sub get_doc {
	my $self = shift;
	my $num = shift;
	croak "expect number as argument, not '$num'" unless ($num =~ m/^\d+$/);
	return undef if ($num < 0 || $num > $self->{docs});
	return $self->{docs}->[$num];
}


=head2 hint

Return specific hint from results.

  print $rec->hint( 'VERSION' );

Possible hints are: C<VERSION>, C<NODE>, C<HIT>, C<HINT#n>, C<DOCNUM>, C<WORDNUM>,
C<TIME>, C<LINK#n>, C<VIEW>.

=cut

sub hint {
	my $self = shift;
	my $key = shift || return;
	return $self->{hints}->{$key};
}


package Search::Estraier::Node;

use Carp qw/carp croak confess/;
use URI;
use MIME::Base64;
use IO::Socket::INET;
use URI::Escape qw/uri_escape/;

=head1 Search::Estraier::Node

=head2 new

  my $node = new Search::HyperEstraier::Node;

or optionally with C<url> as parametar

  my $node = new Search::HyperEstraier::Node( 'http://localhost:1978/node/test' );

=cut

sub new {
	my $class = shift;
	my $self = {
		pxport => -1,
		timeout => 0,	# this used to be -1
		dnum => -1,
		wnum => -1,
		size => -1.0,
		wwidth => 480,
		hwidth => 96,
		awidth => 96,
		status => -1,
	};
	bless($self, $class);

	if ($#_ == 0) {
		$self->{url} = shift;
	} else {
		my $args = {@_};

		$self->{debug} = $args->{debug};
		warn "## Node debug on\n" if ($self->{debug});
	}

	$self ? return $self : return undef;
}


=head2 set_url

Specify URL to node server

  $node->set_url('http://localhost:1978');

=cut

sub set_url {
	my $self = shift;
	$self->{url} = shift;
}


=head2 set_proxy

Specify proxy server to connect to node server

  $node->set_proxy('proxy.example.com', 8080);

=cut

sub set_proxy {
	my $self = shift;
	my ($host,$port) = @_;
	croak "proxy port must be number, not '$port'" unless ($port =~ m/^\d+$/);
	$self->{pxhost} = $host;
	$self->{pxport} = $port;
}


=head2 set_timeout

Specify timeout of connection in seconds

  $node->set_timeout( 15 );

=cut

sub set_timeout {
	my $self = shift;
	my $sec = shift;
	croak "timeout must be number, not '$sec'" unless ($sec =~ m/^\d+$/);
	$self->{timeout} = $sec;
}


=head2 set_auth

Specify name and password for authentication to node server.

  $node->set_auth('clint','eastwood');

=cut

sub set_auth {
	my $self = shift;
	my ($login,$passwd) = @_;
	my $basic_auth = encode_base64( "$login:$passwd" );
	chomp($basic_auth);
	$self->{auth} = $basic_auth;
}


=head2 status

Return status code of last request.

  print $node->status;

C<-1> means connection failure.

=cut

sub status {
	my $self = shift;
	return $self->{status};
}


=head2 put_doc

Add a document

  $node->put_doc( $document_draft ) or die "can't add document";

Return true on success or false on failture.

=cut

sub put_doc {
	my $self = shift;
	my $doc = shift || return;
	return unless ($self->{url} && $doc->isa('Search::Estraier::Document'));
	$self->shuttle_url( $self->{url} . '/put_doc',
		'text/x-estraier-draft',
		$doc->dump_draft,
		undef
	) == 200;
}


=head2 out_doc

Remove a document

  $node->out_doc( document_id ) or "can't remove document";

Return true on success or false on failture.

=cut

sub out_doc {
	my $self = shift;
	my $id = shift || return;
	return unless ($self->{url});
	croak "id must be number, not '$id'" unless ($id =~ m/^\d+$/);
	$self->shuttle_url( $self->{url} . '/out_doc',
		'application/x-www-form-urlencoded',
		"id=$id",
		undef
	) == 200;
}


=head2 out_doc_by_uri

Remove a registrated document using it's uri

  $node->out_doc_by_uri( 'file:///document/uri/42' ) or "can't remove document";

Return true on success or false on failture.

=cut

sub out_doc_by_uri {
	my $self = shift;
	my $uri = shift || return;
	return unless ($self->{url});
	$self->shuttle_url( $self->{url} . '/out_doc',
		'application/x-www-form-urlencoded',
		"uri=" . uri_escape($uri),
		undef
	) == 200;
}


=head2 edit_doc

Edit attributes of a document

  $node->edit_doc( $document_draft ) or die "can't edit document";

Return true on success or false on failture.

=cut

sub edit_doc {
	my $self = shift;
	my $doc = shift || return;
	return unless ($self->{url} && $doc->isa('Search::Estraier::Document'));
	$self->shuttle_url( $self->{url} . '/edit_doc',
		'text/x-estraier-draft',
		$doc->dump_draft,
		undef
	) == 200;
}


=head2 get_doc

Retreive document

  my $doc = $node->get_doc( document_id ) or die "can't get document";

Return true on success or false on failture.

=cut

sub get_doc {
	my $self = shift;
	my $id = shift || return;
	return $self->_fetch_doc( id => $id );
}


=head2 get_doc_by_uri

Retreive document

  my $doc = $node->get_doc_by_uri( 'file:///document/uri/42' ) or die "can't get document";

Return true on success or false on failture.

=cut

sub get_doc_by_uri {
	my $self = shift;
	my $uri = shift || return;
	return $self->_fetch_doc( uri => $uri );
}


=head2 get_doc_attr

Retrieve the value of an atribute from object

  my $val = $node->get_doc_attr( document_id, 'attribute_name' ) or
  	die "can't get document attribute";

=cut

sub get_doc_attr {
	my $self = shift;
	my ($id,$name) = @_;
	return unless ($id && $name);
	return $self->_fetch_doc( id => $id, attr => $name );
}


=head2 get_doc_attr_by_uri

Retrieve the value of an atribute from object

  my $val = $node->get_doc_attr_by_uri( document_id, 'attribute_name' ) or
  	die "can't get document attribute";

=cut

sub get_doc_attr_by_uri {
	my $self = shift;
	my ($uri,$name) = @_;
	return unless ($uri && $name);
	return $self->_fetch_doc( uri => $uri, attr => $name );
}


=head2 etch_doc

Exctract document keywords

  my $keywords = $node->etch_doc( document_id ) or die "can't etch document";

=cut

sub etch_doc {
	my $self = shift;
	my $id = shift || return;
	return $self->_fetch_doc( id => $id, etch => 1 );
}

=head2 etch_doc_by_uri

Retreive document

  my $keywords = $node->etch_doc_by_uri( 'file:///document/uri/42' ) or die "can't etch document";

Return true on success or false on failture.

=cut

sub etch_doc_by_uri {
	my $self = shift;
	my $uri = shift || return;
	return $self->_fetch_doc( uri => $uri, etch => 1 );
}


=head2 uri_to_id

Get ID of document specified by URI

  my $id = $node->uri_to_id( 'file:///document/uri/42' );

=cut

sub uri_to_id {
	my $self = shift;
	my $uri = shift || return;
	return $self->_fetch_doc( uri => $uri, path => '/uri_to_id', chomp_resbody => 1 );
}


=head2 _fetch_doc

Private function used for implementing of C<get_doc>, C<get_doc_by_uri>,
C<etch_doc>, C<etch_doc_by_uri>.

 # this will decode received draft into Search::Estraier::Document object
 my $doc = $node->_fetch_doc( id => 42 );
 my $doc = $node->_fetch_doc( uri => 'file:///document/uri/42' );

 # to extract keywords, add etch
 my $doc = $node->_fetch_doc( id => 42, etch => 1 );
 my $doc = $node->_fetch_doc( uri => 'file:///document/uri/42', etch => 1 );

 # to get document attrubute add attr
 my $doc = $node->_fetch_doc( id => 42, attr => '@mdate' );
 my $doc = $node->_fetch_doc( uri => 'file:///document/uri/42', attr => '@mdate' );

 # more general form which allows implementation of
 # uri_to_id
 my $id = $node->_fetch_doc(
 	uri => 'file:///document/uri/42',
	path => '/uri_to_id',
	chomp_resbody => 1
 );

=cut

sub _fetch_doc {
	my $self = shift;
	my $a = {@_};
	return unless ( ($a->{id} || $a->{uri}) && $self->{url} );

	my ($arg, $resbody);

	my $path = $a->{path} || '/get_doc';
	$path = '/etch_doc' if ($a->{etch});

	if ($a->{id}) {
		croak "id must be numberm not '$a->{id}'" unless ($a->{id} =~ m/^\d+$/);
		$arg = 'id=' . $a->{id};
	} elsif ($a->{uri}) {
		$arg = 'uri=' . uri_escape($a->{uri});
	} else {
		confess "unhandled argument. Need id or uri.";
	}

	if ($a->{attr}) {
		$path = '/get_doc_attr';
		$arg .= '&attr=' . uri_escape($a->{attr});
		$a->{chomp_resbody} = 1;
	}

	my $rv = $self->shuttle_url( $self->{url} . $path,
		'application/x-www-form-urlencoded',
		$arg,
		\$resbody,
	);

	return if ($rv != 200);

	if ($a->{etch}) {
		$self->{kwords} = {};
		return +{} unless ($resbody);
		foreach my $l (split(/\n/, $resbody)) {
			my ($k,$v) = split(/\t/, $l, 2);
			$self->{kwords}->{$k} = $v if ($v);
		}
		return $self->{kwords};
	} elsif ($a->{chomp_resbody}) {
		return unless (defined($resbody));
		chomp($resbody);
		return $resbody;
	} else {
		return new Search::Estraier::Document($resbody);
	}
}


=head2 name

  my $node_name = $node->name;

=cut

sub name {
	my $self = shift;
	$self->_set_info unless ($self->{name});
	return $self->{name};
}


=head2 label

  my $node_label = $node->label;

=cut

sub label {
	my $self = shift;
	$self->_set_info unless ($self->{label});
	return $self->{label};
}


=head2 doc_num

  my $documents_in_node = $node->doc_num;

=cut

sub doc_num {
	my $self = shift;
	$self->_set_info if ($self->{dnum} < 0);
	return $self->{dnum};
}


=head2 word_num

  my $words_in_node = $node->word_num;

=cut

sub word_num {
	my $self = shift;
	$self->_set_info if ($self->{wnum} < 0);
	return $self->{wnum};
}


=head2 size

  my $node_size = $node->size;

=cut

sub size {
	my $self = shift;
	$self->_set_info if ($self->{size} < 0);
	return $self->{size};
}


=head2 search

Search documents which match condition

  my $nres = $node->search( $cond, $depth );

C<$cond> is C<Search::Estraier::Condition> object, while <$depth> specifies
depth for meta search.

Function results C<Search::Estraier::NodeResult> object.

=cut

sub search {
	my $self = shift;
	my ($cond, $depth) = @_;
	return unless ($cond && defined($depth) && $self->{url});
	croak "cond mush be Search::Estraier::Condition, not '$cond->isa'" unless ($cond->isa('Search::Estraier::Condition'));
	croak "depth needs number, not '$depth'" unless ($depth =~ m/^\d+$/);

	my $resbody;

	my $rv = $self->shuttle_url( $self->{url} . '/search',
		'application/x-www-form-urlencoded',
		$self->cond_to_query( $cond, $depth ),
		\$resbody,
	);
	return if ($rv != 200);

	my (@docs, $hints);

	my @lines = split(/\n/, $resbody);
	return unless (@lines);

	my $border = $lines[0];
	my $isend = 0;
	my $lnum = 1;

	while ( $lnum <= $#lines ) {
		my $line = $lines[$lnum];
		$lnum++;

		#warn "## $line\n";
		if ($line && $line =~ m/^\Q$border\E(:END)*$/) {
			$isend = $1;
			last;
		}

		if ($line =~ /\t/) {
			my ($k,$v) = split(/\t/, $line, 2);
			$hints->{$k} = $v;
		}
	}

	my $snum = $lnum;

	while( ! $isend && $lnum <= $#lines ) {
		my $line = $lines[$lnum];
		#warn "# $lnum: $line\n";
		$lnum++;

		if ($line && $line =~ m/^\Q$border\E/) {
			if ($lnum > $snum) {
				my $rdattrs;
				my $rdvector;
				my $rdsnippet;
				
				my $rlnum = $snum;
				while ($rlnum < $lnum - 1 ) {
					#my $rdline = $self->_s($lines[$rlnum]);
					my $rdline = $lines[$rlnum];
					$rlnum++;
					last unless ($rdline);
					if ($rdline =~ /^%/) {
						$rdvector = $1 if ($rdline =~ /^%VECTOR\t(.+)$/);
					} elsif($rdline =~ /=/) {
						$rdattrs->{$1} = $2 if ($rdline =~ /^(.+)=(.+)$/);
					} else {
						confess "invalid format of response";
					}
				}
				while($rlnum < $lnum - 1) {
					my $rdline = $lines[$rlnum];
					$rlnum++;
					$rdsnippet .= "$rdline\n";
				}
				#warn Dumper($rdvector, $rdattrs, $rdsnippet);
				if (my $rduri = $rdattrs->{'@uri'}) {
					push @docs, new Search::Estraier::ResultDocument(
						uri => $rduri,
						attrs => $rdattrs,
						snippet => $rdsnippet,
						keywords => $rdvector,
					);
				}
			}
			$snum = $lnum;
			#warn "### $line\n";
			$isend = 1 if ($line =~ /:END$/);
		}

	}

	if (! $isend) {
		warn "received result doesn't have :END\n$resbody";
		return;
	}

	#warn Dumper(\@docs, $hints);

	return new Search::Estraier::NodeResult( docs => \@docs, hints => $hints );
}


=head2 cond_to_query

Return URI encoded string generated from Search::Estraier::Condition

  my $args = $node->cond_to_query( $cond, $depth );

=cut

sub cond_to_query {
	my $self = shift;

	my $cond = shift || return;
	croak "condition must be Search::Estraier::Condition, not '$cond->isa'" unless ($cond->isa('Search::Estraier::Condition'));
	my $depth = shift;

	my @args;

	if (my $phrase = $cond->phrase) {
		push @args, 'phrase=' . uri_escape($phrase);
	}

	if (my @attrs = $cond->attrs) {
		for my $i ( 0 .. $#attrs ) {
			push @args,'attr' . ($i+1) . '=' . uri_escape( $attrs[$i] ) if ($attrs[$i]);
		}
	}

	if (my $order = $cond->order) {
		push @args, 'order=' . uri_escape($order);
	}
		
	if (my $max = $cond->max) {
		push @args, 'max=' . $max;
	} else {
		push @args, 'max=' . (1 << 30);
	}

	if (my $options = $cond->options) {
		push @args, 'options=' . $options;
	}

	push @args, 'depth=' . $depth if ($depth);
	push @args, 'wwidth=' . $self->{wwidth};
	push @args, 'hwidth=' . $self->{hwidth};
	push @args, 'awidth=' . $self->{awidth};

	return join('&', @args);
}


=head2 shuttle_url

This is method which uses C<LWP::UserAgent> to communicate with Hyper Estraier node
master.

  my $rv = shuttle_url( $url, $content_type, $req_body, \$resbody );

C<$resheads> and C<$resbody> booleans controll if response headers and/or response
body will be saved within object.

=cut

use LWP::UserAgent;

sub shuttle_url {
	my $self = shift;

	my ($url, $content_type, $reqbody, $resbody) = @_;

	$self->{status} = -1;

	warn "## $url\n" if ($self->{debug});

	$url = new URI($url);
	if (
			!$url || !$url->scheme || !$url->scheme eq 'http' ||
			!$url->host || !$url->port || $url->port < 1
		) {
		carp "can't parse $url\n";
		return -1;
	}

	my $ua = LWP::UserAgent->new;
	$ua->agent( "Search-Estraier/$Search::Estraier::VERSION" );

	my $req;
	if ($reqbody) {
		$req = HTTP::Request->new(POST => $url);
	} else {
		$req = HTTP::Request->new(GET => $url);
	}

	$req->headers->header( 'Host' => $url->host . ":" . $url->port );
	$req->headers->header( 'Connection', 'close' );
	$req->headers->header( 'Authorization', 'Basic ' . $self->{auth} );
	$req->content_type( $content_type );

	warn $req->headers->as_string,"\n" if ($self->{debug});

	if ($reqbody) {
		warn "$reqbody\n" if ($self->{debug});
		$req->content( $reqbody );
	}

	my $res = $ua->request($req) || croak "can't make request to $url: $!";

	warn "## response status: ",$res->status_line,"\n" if ($self->{debug});

	return -1 if (! $res->is_success);

	($self->{status}, $self->{status_message}) = split(/\s+/, $res->status_line, 2);

	$$resbody .= $res->content;

	warn "## response body:\n$$resbody\n" if ($resbody && $self->{debug});

	return $self->{status};
}


=head2 set_snippet_width

Set width of snippets in results

  $node->set_snippet_width( $wwidth, $hwidth, $awidth );

C<$wwidth> specifies whole width of snippet. It's C<480> by default. If it's C<0> snippet
is not sent with results. If it is negative, whole document text is sent instead of snippet.

C<$hwidth> specified width of strings from beginning of string. Default
value is C<96>. Negative or zero value keep previous value.

C<$awidth> specifies width of strings around each highlighted word. It's C<96> by default.
If negative of zero value is provided previous value is kept unchanged.

=cut

sub set_snippet_width {
	my $self = shift;

	my ($wwidth, $hwidth, $awidth) = @_;
	$self->{wwidth} = $wwidth;
	$self->{hwidth} = $hwidth if ($hwidth >= 0);
	$self->{awidth} = $awidth if ($awidth >= 0);
}


=head2 set_user

Manage users of node

  $node->set_user( 'name', $mode );

C<$mode> can be one of:

=over 4

=item 0

delete account

=item 1

set administrative right for user

=item 2

set user account as guest

=back

Return true on success, otherwise false.

=cut

sub set_user {
	my $self = shift;
	my ($name, $mode) = @_;

	return unless ($self->{url});
	croak "mode must be number, not '$mode'" unless ($mode =~ m/^\d+$/);

	$self->shuttle_url( $self->{url} . '/_set_user',
		'text/plain',
		'name=' . uri_escape($name) . '&mode=' . $mode,
		undef
	) == 200;
}


=head2 set_link

Manage node links

  $node->set_link('http://localhost:1978/node/another', 'another node label', $credit);

If C<$credit> is negative, link is removed.

=cut

sub set_link {
	my $self = shift;
	my ($url, $label, $credit) = @_;

	return unless ($self->{url});
	croak "mode credit be number, not '$credit'" unless ($credit =~ m/^\d+$/);

	my $reqbody = 'url=' . uri_escape($url) . '&label=' . uri_escape($label);
	$reqbody .= '&credit=' . $credit if ($credit > 0);

	$self->shuttle_url( $self->{url} . '/_set_link',
		'application/x-www-form-urlencoded',
		$reqbody,
		undef
	) == 200;
}


=head1 PRIVATE METHODS

You could call those directly, but you don't have to. I hope.

=head2 _set_info

Set information for node

  $node->_set_info;

=cut

sub _set_info {
	my $self = shift;

	$self->{status} = -1;
	return unless ($self->{url});

	my $resbody;
	my $rv = $self->shuttle_url( $self->{url} . '/inform',
		'text/plain',
		undef,
		\$resbody,
	);

	return if ($rv != 200 || !$resbody);

	# it seems that response can have multiple line endings
	$resbody =~ s/[\r\n]+$//;

	( $self->{name}, $self->{label}, $self->{dnum}, $self->{wnum}, $self->{size} ) =
		split(/\t/, $resbody, 5);

}

###

=head1 EXPORT

Nothing.

=head1 SEE ALSO

L<http://hyperestraier.sourceforge.net/>

Hyper Estraier Ruby interface on which this module is based.

=head1 AUTHOR

Dobrica Pavlinusic, E<lt>dpavlin@rot13.orgE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2006 by Dobrica Pavlinusic

This library is free software; you can redistribute it and/or modify
it under the GPL v2 or later.

=cut

1;
