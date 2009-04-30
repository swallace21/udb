package BrownCS::udb::Schema::Places;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("places");
__PACKAGE__->add_columns(
  "place_id",
  {
    data_type => "integer",
    default_value => "nextval('places_place_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "city",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "building",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "room",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("place_id");
__PACKAGE__->add_unique_constraint("places_pkey", ["place_id"]);
__PACKAGE__->has_many(
  "devices",
  "BrownCS::udb::Schema::Devices",
  { "foreign.place_id" => "self.place_id" },
);
__PACKAGE__->has_many(
  "net_ports",
  "BrownCS::udb::Schema::NetPorts",
  { "foreign.place_id" => "self.place_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tsLol0hx8mxp42chogA/Dw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
