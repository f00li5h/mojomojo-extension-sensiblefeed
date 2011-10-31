package MojoMojo::CLI::Command::SF_from_feed;

use MojoMojo::CLI -command;
use strict; use warnings;


use constant {
	abstract	=> "extract pubdates and urls from a feed",
	description 	=> "if you are switching from an old feed to this one, you'll want your id/pubdate in both feeds to be the same, so you can avoid re-runs",
};

sub validate_args {
	my ($self, $opt, $args) = @_;
	eval 'use MojoMojo::Extensions::SensibleFeed;';

	$self->usage_error(
		"needs a page name/id as the first argument"
	) if ! @$args;

	$self->usage_error(
		"Not really useful without MojoMojo::Extensions::SensibleFeed."
	) if $@;

	$self->usage_error( 'which feed do you want to examine?' ) 
		if ! @$args;
}

sub opt_spec { return (
	 [ "dates", "set the page_in_feed's dates from the feed" ],
	 [ "ids", "set the page_in_feed's feed_id from the feed" ],
) }


use DateTime;
use Data::Dumper;


sub execute {
	my ($self, $opt, $args) = @_;
        my $schema      = $self->app->schema;

	# $opt->{'mojo_index'} 
	my $feed_url = shift @$args;

	# these arguments are mapped to attrs on the entry
	my @update_args = qw[ title link content summary category author id issued  ];

	use XML::Feed;
	my $feed = XML::Feed->parse(URI->new($feed_url));
	if (not defined $feed) {
		($feed) = XML::Feed->find_feeds($feed_url);
	}
	
	print "the feed is:\n",
	      "============\n",
		"id: ", $feed->id, "\n",
		"title: ",$feed->title, "\n",
		"description: ",$feed->description, "\n",
		;

	my $rs = $schema->resultset('Page');
	for my $entry ($feed->entries) {
		my $path = URI->new( $entry->id )->path ;
		$path =~ s{.html$}{};
		$path =~ s{^/?blog/?}{};
		use File::Basename qw[ basename ];
		my $name =  basename( $path );
		my @terms = grep {defined$_ and $_ ne ''} split qr{[/_.:-]},  $path;
		#my $direct_match = $rs->search({ name_orig => { like => "%$name%" } })->first;

		my ( $path_pages, $proto_pages ) = $rs->path_pages( $path );
		my $page = @$proto_pages > 0 ? undef : $path_pages->[-1] ;	

		if (defined $page ){
			warn "found by path" if 0;
			
		}
		else {
			$page = $rs->search({ name_orig => { like => "%$path%" } })->first;
			if (defined $page) { 
				warn "found by name" if 0 ;
			}
			else { 
				my $words_match  = 0==@terms    ? undef 
								: $rs->search({
				name_orig => [-and => map +{ like => "%$_%"} , @terms]
				});

				$page = $words_match->count == 1 ? $words_match->first 
								 : undef ;

				warn "cound be any of these: "
					. (join "\n\t", $words_match->get_column('name_orig')->all);
				next
			}


		}
		if (defined $page) { 
		printf "** Import: feed-id:%-100.100s\n"
		     . "             title:%-100.100s  modified: %s\n"#  --> terms:%-100s\n "
		     . "     Page: id: %-3u name: %s\n"
		     . "FeedEntry: %-8s%-100.100s   feedmod: %s",
				$entry->id,
				$entry->title, 
				$entry->modified,
				#(join ' ', @terms),
			$page->id, #$page->name_orig,
			$page->name,

			$page->in_feed ? 'id: '.$page->in_feed->id : '',
			$page->in_feed ? $page->in_feed->feed_id    || '(default id)' : '(not)',
			$page->in_feed ? $page->in_feed->feed_modified : '(na)',

		my %feed_entry = ();

		if ($opt->{dates} or $opt->{ids}) { 
			print "\n   >> snagging: ";
			if ($opt->{dates}) {
				print "dates ";
				@feed_entry{ qw[feed_modified feed_issued ] }  = ( $entry->modified ) x 2;
			}
			if ($opt->{ids}) {
				print "id ";
				$feed_entry{ feed_id } = $entry->id;
			}
			$page->update_or_create_related( in_feed => \%feed_entry )
		}
			
		print "\n";
		}
	}

}
1
__END__
	return warn "nope";
	my $id;

	my %update; #%update = (column_name => column_value )
	if ($opt) { # any arguments specified

		# only those that are specified
		@update_args = grep exists $opt->{ $_ }, @update_args;
		@update{ map "feed_$_", @update_args }  = @{ $opt }{ @update_args };
	}

	my $page;
	if ($id =~ m{/}) { 
		my ( $path_pages, $proto_pages ) = $schema->resultset('Page')->path_pages( $id );
		$page = @$proto_pages > 0 ? $proto_pages->[-1] : $path_pages->[-1] ;	
	}
	else{
		$page = $schema->resultset('Page')->find( { id => $id } );
	}
	return warn "lol, that's not a page" if not defined $page;
	$id=$page->id;
	my $page_path = $page->path;

	my %sensible;
	my $feed_entry = $page->in_feed;

	return warn "lol, that's not in a feed" if not defined $feed_entry and not keys %update;
	if ($opt->{'touch'}){
		$sensible{feed_modified} = $page->content->created ||   DateTime->now();
		$sensible{feed_issued }  = DateTime->now();
	}
	if ($opt->{'touch'}){
		$update{feed_modified} = 
		$update{feed_issued }  = DateTime->now();
	}
	if (defined $feed_entry){

		print "before messing with it:\n",$feed_entry->id,
		(join "\n",
		    map {;
			join '',
			" " , $_ , "=", ($feed_entry->can($_)->($feed_entry) // '' )
			}
		qw[
			page_id

			page_version

			feed_title
			feed_link
			feed_content
			feed_summary
			feed_category
			feed_author
			feed_id
			feed_issued
			feed_modified
		]),
		"\n" ;	
		if (keys %update) {
			$feed_entry->update({
				%sensible,
				%update,
			});
		}
		else {
			return "didn't update";
		}
	}
	else {
		print "not in a feed, adding\n";
		$feed_entry = $page->create_related( in_feed => {
					%sensible,
					%update,
					page_id => $id,
					});

	}
	print "now it looks like this:\n", $feed_entry->id,
		(join "\n",
	    map {;
		join '',
		" " , $_ , "=", ($feed_entry->can($_)->($feed_entry) // '' )
		}
		qw[
			page_id

			page_version

			feed_title
			feed_link
			feed_content
			feed_summary
			feed_category
			feed_author
			feed_id
			feed_issued
			feed_modified
		]),
	"\n"
	;	
}
1
