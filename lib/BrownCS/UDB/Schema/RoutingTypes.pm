package BrownCS::UDB::Schema::RoutingTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("routing_types");
__PACKAGE__->add_columns(
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("name");
__PACKAGE__->add_unique_constraint("routing_types_pkey", ["name"]);
__PACKAGE__->has_many(
  "net_zones",
  "BrownCS::UDB::Schema::NetZones",
  { "foreign.routing_type" => "self.name" },
);

1;
