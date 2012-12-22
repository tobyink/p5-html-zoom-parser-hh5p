package HTML::Zoom::Parser::HH5P;

use 5.008;
use strict;
use warnings;
use utf8;

BEGIN {
	$HTML::Zoom::Parser::HH5P::AUTHORITY = 'cpan:TOBYINK';
	$HTML::Zoom::Parser::HH5P::VERSION   = '0.000_01';
}

use HTML::HTML5::Parser;
use HTML::HTML5::Entities;
use namespace::clean;

# Yes, keep these constants...
use XML::LibXML 2 ':libxml';
use constant {
	EVENT_OPEN_TAG  => 'OPEN',
	EVENT_CLOSE_TAG => 'CLOSE',
	EVENT_TEXT      => 'TEXT',
	EVENT_DTD       => 'SPECIAL',
	EVENT_PI        => 'SPECIAL',
	EVENT_OTHER     => 'MYSTERYMEAT',
};

use Moo;
extends qw(HTML::Zoom::SubObject);

has _zconfig => (
	is       => 'ro',
	weaken   => 1,
	init_arg => 'zconfig',
	writer   => 'with_zconfig',
);

has parse_as_fragment => (
	is       => 'rw',
	default  => sub { +undef },
);

has ignore_implied_elements => (
	is       => 'rw',
	default  => sub { 1 },
);

# Stoled from HTML::Zoom::Parser::HTML::BuiltIn!
sub html_to_events
{
	my ($self, $text) = @_;
	my @events;
	$self->_parser($text => sub { push @events, $_[0] });
	return \@events;
}

# Stoled from HTML::Zoom::Parser::HTML::BuiltIn!
sub html_to_stream
{
	my ($self, $text) = @_;
	return $self
		-> _zconfig
		-> stream_utils
		-> stream_from_array( @{$self->html_to_events($text)} );
}

sub _parser
{
	my ($self, $text, $handler) = @_;
	
	# Decide whether we have a document fragment or a full document.
	my $is_frag = $self->parse_as_fragment;
	defined $is_frag
		or $is_frag = !(substr($text,0,512) =~ /<html/i);
	
	my $dom = $is_frag
		? HTML::HTML5::Parser::->new->parse_balanced_chunk($text)
		: HTML::HTML5::Parser::->load_html(string => $text);
	
	$self->_visit($dom, $handler);
}

sub _visit
{
	my ($self, $node, $handler, $continuation) = @_;
	$continuation ||= $self->can('_visit');
	
	my $type = $node->nodeType;
	
	if ($type == XML_ELEMENT_NODE)
	{
		my $ignore = $self->ignore_implied_elements;
		if ($ignore)
		{
			my ($line, $col, $implied) = HTML::HTML5::Parser::->source_line($node);
			$ignore = 0 unless $implied;
		}
		
		$handler->({
			type       => EVENT_OPEN_TAG,
			libxml     => $node,
			name       => $node->localname,
			attrs      => $node,
			attr_names => [ sort keys %$node ],
		}) unless $ignore;
		
		$continuation->($self, $_, $handler, $continuation)
			for $node->childNodes;
		
		$handler->({
			type       => EVENT_CLOSE_TAG,
			libxml     => $node,
			name       => $node->localname,
			attrs      => $node,
			attr_names => [ sort keys %$node ],
		}) unless $ignore;
	}
	elsif ($type == XML_TEXT_NODE)
	{
		$handler->({
			type       => EVENT_TEXT,
			libxml     => $node,
			raw        => $node->data,
		});
	}
	elsif ($type == XML_DOCUMENT_NODE)
	{
		my %dtd;
		for my $bit (qw/ dtd_element dtd_system_id dtd_public_id /) {
			$dtd{$bit} = HTML::HTML5::Parser::->$bit($node);
		}
		if ($dtd{dtd_system_id} and $dtd{dtd_public_id}) {
			$dtd{raw} = sprintf(
				qq[<!DOCTYPE %s PUBLIC "%s" "%s">\n],
				uc($dtd{dtd_element} || 'HTML'),
				$dtd{dtd_public_id},
				$dtd{dtd_system_id},
			);
		}
		elsif ($dtd{dtd_system_id}) {
			$dtd{raw} = sprintf(
				qq[<!DOCTYPE %s SYSTEM "%s">\n],
				uc($dtd{dtd_element} || 'HTML'),
				$dtd{dtd_system_id},
			);
		}
		elsif ($dtd{dtd_public_id}) {
			$dtd{raw} = sprintf(
				qq[<!DOCTYPE %s PUBLIC "%s">\n],
				uc($dtd{dtd_element} || 'HTML'),
				$dtd{dtd_public_id},
			);
		}
		$handler->({
			type       => EVENT_DTD,
			%dtd,
		}) if $dtd{raw};
		
		$continuation->($self, $_, $handler, $continuation)
			for $node->childNodes;
	}
	elsif ($type == XML_DOCUMENT_FRAG_NODE)
	{
		$continuation->($self, $_, $handler, $continuation)
			for $node->childNodes;
	}
	else
	{
		warn "OTHER: $type";
		$handler->({
			type       => EVENT_OTHER,
			libxml     => $node,
		});
	}
}

sub html_escape   { encode_entities($_[1]) }
sub html_unescape { decode_entities($_[1]) }

1

__END__

=head1 NAME

HTML::Zoom::Parser::HH5P - use HTML::HTML5::Parser with HTML::Zoom

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=HTML-Zoom-Parser-HH5P>.

=head1 SEE ALSO

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2012 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

