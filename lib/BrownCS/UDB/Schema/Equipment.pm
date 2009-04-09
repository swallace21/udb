package BrownCS::UDB::Schema::Equipment;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("equipment");
__PACKAGE__->add_columns(
  "name"            => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "parent_equip_id" => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "place_id"        => { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "equip_status"    => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "managed_by"      => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "protected"       => { data_type => "boolean", default_value => "false", is_nullable => 0, size => 1, },
  "purchased_on"    => { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "installed_on"    => { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "brown_inv_num"   => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "serial_num"      => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "po_num"          => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "owner"           => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "contact"         => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "comments"        => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
);
__PACKAGE__->set_primary_key("name");
__PACKAGE__->add_unique_constraint("equipment_pkey", ["name"]);
__PACKAGE__->might_have(
  "computer",
  "BrownCS::UDB::Schema::Computers",
  { "foreign.name" => "self.name" },
);
__PACKAGE__->belongs_to(
  "parent",
  "BrownCS::UDB::Schema::Equipment",
  { name => "parent_equip_id" },
);
__PACKAGE__->has_many(
  "children",
  "BrownCS::UDB::Schema::Equipment",
  { "foreign.parent_equip_id" => "self.name" },
);
__PACKAGE__->belongs_to(
  "equip_status",
  "BrownCS::UDB::Schema::EquipStatusTypes",
  { name => "equip_status" },
);
__PACKAGE__->belongs_to(
  "managed_by",
  "BrownCS::UDB::Schema::ManagementTypes",
  { name => "managed_by" },
);
__PACKAGE__->belongs_to(
  "location",
  "BrownCS::UDB::Schema::Places",
  { id => "place_id" },
);
__PACKAGE__->has_many(
  "equipment_people",
  "BrownCS::UDB::Schema::EquipmentPeople",
  { "foreign.equipment_name" => "self.name" },
);
__PACKAGE__->has_many(
  "net_interfaces",
  "BrownCS::UDB::Schema::NetInterfaces",
  { "foreign.equip_name" => "self.name" },
);
__PACKAGE__->might_have(
  "switch",
  "BrownCS::UDB::Schema::NetSwitches",
  { "foreign.name" => "self.name" },
);

1;
