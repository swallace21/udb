package BrownCS::UDB::Schema::NetZones;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_zones");
__PACKAGE__->add_columns(
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "zone_manager",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "equip_manager",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "routing_type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "dynamic_dhcp",
  {
    data_type => "boolean",
    default_value => "true",
    is_nullable => 0,
    size => 1,
  },
);
__PACKAGE__->set_primary_key("name");
__PACKAGE__->add_unique_constraint("net_zones_pkey", ["name"]);
__PACKAGE__->has_many(
  "net_addresses",
  "BrownCS::UDB::Schema::NetAddresses",
  { "foreign.zone" => "self.name" },
);
__PACKAGE__->has_many(
  "net_vlans",
  "BrownCS::UDB::Schema::NetVlans",
  { "foreign.zone" => "self.name" },
);
__PACKAGE__->belongs_to(
  "routing_type",
  "BrownCS::UDB::Schema::RoutingTypes",
  { name => "routing_type" },
);
__PACKAGE__->belongs_to(
  "equip_manager",
  "BrownCS::UDB::Schema::ManagementTypes",
  { name => "equip_manager" },
);
__PACKAGE__->belongs_to(
  "zone_manager",
  "BrownCS::UDB::Schema::ManagementTypes",
  { name => "zone_manager" },
);

1;
