package BrownCS::udb::Schema::ManagementTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("management_types");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('management_types_id_seq'::regclass)",
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
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("management_types_name_key", ["name"]);
__PACKAGE__->add_unique_constraint("management_types_pkey", ["id"]);
__PACKAGE__->has_many(
  "devices",
  "BrownCS::udb::Schema::Devices",
  { "foreign.manager_id" => "self.id" },
);
__PACKAGE__->has_many(
  "net_zones_zone_manager_ids",
  "BrownCS::udb::Schema::NetZones",
  { "foreign.zone_manager_id" => "self.id" },
);
__PACKAGE__->has_many(
  "net_zones_equip_manager_ids",
  "BrownCS::udb::Schema::NetZones",
  { "foreign.equip_manager_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KO3LbjHycEiuuvSmPy0zgw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
