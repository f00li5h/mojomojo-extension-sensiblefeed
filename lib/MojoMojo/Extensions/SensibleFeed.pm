package MojoMojo::Extensions::SensibleFeed;

use strict;
use warnings;
 
use base qw(MojoMojo::Extension); # ISA Catalyst::Controller

sub feed :Path('feed') :Args(0){
	my ($self, $c ) = @_;

	use DateTime;
	use XML::Feed;
	my $format = $c->req->param('format') || "Atom" ;
	 
	my @args = $format;
	push @args, ( version => $c->req->param('version') )
		if $c->req->param('version');
	 
	my $feed = XML::Feed->new(@args);
	$feed->id( $c->req->base . '/' );
	$feed->title($c->pref('name') || "Some Critter's MojoMojo");

	$feed->link(	  $c->req->base );
	$feed->self_link( $c->req->uri . '/.feed' );

	# $feed->modified( $c->model("DBIC::PageInFeed") ->get_column('feed_modified') ->max );

	$feed->modified( DateTime->now);# if not $feed->modified;

	my $mime = ("Atom" eq $feed->format) ? "application/atom+xml" : "application/rss+xml";
	$c->res->content_type( $mime );

	for my $pif ( $c->model("DBIC::PageInFeed")->all ) {
	 
		my $page    = $pif->page;
		my $content = $page->content;

		my $entry = XML::Feed::Entry->new();
			# $c->req->base 
		my $article_uri = $c->req->base->clone();
		$article_uri->path( $page->name );

		$entry->id(
			$pif->feed_id
			||  $article_uri
		);
		$entry->link(
			$pif->feed_link
			|| $article_uri
		);
		$entry->title(
			$pif->feed_title 
			|| $page->name_orig
			|| $c->pref('name') . ' home'
		);

		my $reasonable_summary = $page->name_orig;
		$reasonable_summary =~ y/-/ /;
	
		$entry->summary(
			$pif->feed_summary
			|| $content->abstract
			|| $reasonable_summary

		);
		$entry->content(
			XML::Feed::Content->wrap({
			type => "text/html",
			body => 
				$pif->feed_content 
				|| $content->formatted($c)
			})

		);

		$entry->modified(
			$pif->feed_modified 
			// $content->created
			// DateTime->from_epoch( epoch => 0 )
		);

		my $creator_string ; 
		$creator_string = 
		join ' ', map {
			$content->creator->can( $_ )->(
				$content->creator
			)
			} qw[ login email ]
			if defined  $content->creator;

		$entry->author(
			$pif->feed_author
			|| $creator_string
		);

		$feed->add_entry($entry);

	}
	 
	$c->res->body(
		$feed->as_xml
	);
}

1;
