package MojoMojo::CLI::Command::SF_by_page;

use MojoMojo::CLI -command;
use strict; use warnings;


use constant {
	abstract	=> "work with Extensions::SensibleFeed",
	description 	=> "put things in your SensibleFeed.",
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
}

sub opt_spec {
return (
	#[ "page:s",  "page path (/name, / is important) or id (numeric) " ],

	 [ "title:s", " " ],
	 [ "link:s", " " ],
	 [ "content:s", " " ],
	 [ "summary:s", " " ],
	 [ "category:s", " " ],
	 [ "author:s", " " ],
	 [ "id:s", " " ],
	 [ "issued:s", " " ],

	 [ "touch", "just bump issue/mod dates" ],

       );
}


			use DateTime;
	use Data::Dumper;


sub execute {
	my ($self, $opt, $args) = @_;
        my $schema      = $self->app->schema;

# $opt->{'mojo_index'} 
	my $id = shift @$args;

	# these arguments are mapped to attrs on the entry
	my @update_args = qw[ title link content summary category author id issued  ];

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

	return warn "lol, that's not in a feed" if not defined $feed_entry and not keys %update and not $opt->{touch};
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
