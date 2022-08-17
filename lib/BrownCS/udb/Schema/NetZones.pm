package BrownCS::udb::Schema::NetZones;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_zones");
__PACKAGE__->add_columns(
  "zone_name",
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
  "description",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "last_updated" => { data_type => "timestamp without time zone", default_value => "now()", is_nullable => 0, size => 8, },
);
__PACKAGE__->set_primary_key("zone_name");
__PACKAGE__->add_unique_constraint("net_zones_pkey", ["zone_name"]);
__PACKAGE__->has_many(
  "net_addresses",
  "BrownCS::udb::Schema::NetAddresses",
  { "foreign.zone_name" => "self.zone_name" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_many(
  "net_vlans",
  "BrownCS::udb::Schema::NetVlans",
  { "foreign.zone_name" => "self.zone_name" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->belongs_to(
  "routing_type",
  "BrownCS::udb::Schema::RoutingTypes",
  { routing_type => "routing_type" },
);
__PACKAGE__->belongs_to(
  "equip_manager",
  "BrownCS::udb::Schema::ManagementTypes",
  { management_type => "equip_manager" },
);
__PACKAGE__->belongs_to(
  "zone_manager",
  "BrownCS::udb::Schema::ManagementTypes",
  { management_type => "zone_manager" },
);

1;
