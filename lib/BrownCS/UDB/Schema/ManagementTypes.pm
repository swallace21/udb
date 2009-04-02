package BrownCS::UDB::Schema::ManagementTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("management_types");
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
__PACKAGE__->add_unique_constraint("management_types_pkey", ["name"]);
__PACKAGE__->has_many(
  "equipments",
  "BrownCS::UDB::Schema::Equipment",
  { "foreign.managed_by" => "self.name" },
);
__PACKAGE__->has_many(
  "net_zones_equip_managers",
  "BrownCS::UDB::Schema::NetZones",
  { "foreign.equip_manager" => "self.name" },
);
__PACKAGE__->has_many(
  "net_zones_zone_managers",
  "BrownCS::UDB::Schema::NetZones",
  { "foreign.zone_manager" => "self.name" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MqfYbIBFkTnwwcuZsRzbJw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
