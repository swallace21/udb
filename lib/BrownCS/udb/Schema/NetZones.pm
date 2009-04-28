package BrownCS::udb::Schema::NetZones;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_zones");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_zones_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "zone_manager_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "equip_manager_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "routing_type_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "dynamic_dhcp",
  {
    data_type => "boolean",
    default_value => "true",
    is_nullable => 0,
    size => 1,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_zones_pkey", ["id"]);
__PACKAGE__->add_unique_constraint("net_zones_name_key", ["name"]);
__PACKAGE__->has_many(
  "net_addresses",
  "BrownCS::udb::Schema::NetAddresses",
  { "foreign.zone_id" => "self.id" },
);
__PACKAGE__->has_many(
  "net_vlans",
  "BrownCS::udb::Schema::NetVlans",
  { "foreign.zone_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "routing_type_id",
  "BrownCS::udb::Schema::RoutingTypes",
  { id => "routing_type_id" },
);
__PACKAGE__->belongs_to(
  "zone_manager_id",
  "BrownCS::udb::Schema::ManagementTypes",
  { id => "zone_manager_id" },
);
__PACKAGE__->belongs_to(
  "equip_manager_id",
  "BrownCS::udb::Schema::ManagementTypes",
  { id => "equip_manager_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:t8s9gIyEY/K9UigFYgK+KQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
