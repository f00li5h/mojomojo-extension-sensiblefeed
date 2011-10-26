package MojoMojo::Schema::Result::PageInFeed;

 
use strict;
use warnings;
use Carp qw/croak/;
 
use parent qw/MojoMojo::Schema::Base::Result/;
 
__PACKAGE__->load_components(
	'DateTime::Epoch',
# 'TimeStamp',
'Core'
);
__PACKAGE__->table("page_in_feed");
__PACKAGE__->add_columns(
    "id" => {
        data_type         => "INTEGER",
        is_nullable       => 0,
        size              => undef,
        is_auto_increment => 1
    },
    "page_id" =>  { 
        data_type         => "INTEGER",
        is_nullable       => 1,
	is_foreign_key    => 1,
    },

    # this likely won't work
    # mostly good for pulling autohr

    "page_version" => {
	data_type => "INTEGER", is_nullable => 1,
	size => undef
    },
	# mirrors the type o fcontent->created
    "feed_modified" => {
        data_type                 => "BIGINT",
        is_nullable               => 0,
        size                      => 100,
        default_value             => undef,
        inflate_datetime          => 'epoch',
        datetime_undef_if_invalid => 1,
        # set_on_create    => 1,
        # set_on_update    => 1,
    },
    "feed_issued" => {
        # set_on_create    => 1,
        data_type                 => "BIGINT",
        is_nullable               => 0,
        size                      => 100,
        default_value             => undef,
        inflate_datetime          => 'epoch',
        datetime_undef_if_invalid => 1,
    },

    map {(
	"feed_$_" => {
		data_type => "VARCHAR",
		is_nullable => 1,
	    }
	)}
	qw[
		title
		link
		content
		summary
		category
		author
		id
	]
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
	page =>  'MojoMojo::Schema::Result::Page'
		=>{ 'foreign.id' => 'self.page_id' }
);
MojoMojo::Schema::Result::Page->might_have(
	in_feed => __PACKAGE__ 
		=>{ 'foreign.page_id' => 'self.id' }
);


warn "i'm messing with your schema." if $ENV{'MOJOMOJO_DEBUG'};
1
