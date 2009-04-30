package BrownCS::udb::Schema::ManagementTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("management_types");
__PACKAGE__->add_columns(
  "management_type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("management_type");
__PACKAGE__->add_unique_constraint("management_types_pkey", ["management_type"]);
__PACKAGE__->has_many(
  "devices",
  "BrownCS::udb::Schema::Devices",
  { "foreign.manager" => "self.management_type" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_many(
  "net_zones_equip_managers",
  "BrownCS::udb::Schema::NetZones",
  { "foreign.equip_manager" => "self.management_type" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_many(
  "net_zones_zone_managers",
  "BrownCS::udb::Schema::NetZones",
  { "foreign.zone_manager" => "self.management_type" },
  {
    cascade_delete => 0,
  }
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:A1qlAzgET3LRF4Ttu8lZVQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
