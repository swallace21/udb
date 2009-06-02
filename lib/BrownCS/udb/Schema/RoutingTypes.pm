package BrownCS::udb::Schema::RoutingTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("routing_types");
__PACKAGE__->add_columns(
  "routing_type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("routing_type");
__PACKAGE__->add_unique_constraint("routing_types_pkey", ["routing_type"]);
__PACKAGE__->has_many(
  "net_zones",
  "BrownCS::udb::Schema::NetZones",
  { "foreign.routing_type" => "self.routing_type" },
  {
    cascade_delete => 0,
  }
);

1;
