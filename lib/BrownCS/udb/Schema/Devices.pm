package BrownCS::udb::Schema::Devices;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("devices");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('devices_id_seq'::regclass)",
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
  "parent_device_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "place_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "equip_status_type_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "equip_usage_type_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "manager_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "protected",
  {
    data_type => "boolean",
    default_value => "false",
    is_nullable => 0,
    size => 1,
  },
  "purchased_on",
  { data_type => "date", default_value => "now()", is_nullable => 1, size => 4 },
  "installed_on",
  { data_type => "date", default_value => "now()", is_nullable => 1, size => 4 },
  "last_contacted_on",
  { data_type => "date", default_value => "now()", is_nullable => 1, size => 4 },
  "brown_inv_num",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "serial_num",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "po_num",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "owner",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "contact",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "comments",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("devices_pkey", ["id"]);
__PACKAGE__->add_unique_constraint("devices_name_key", ["name"]);
__PACKAGE__->has_many(
  "computers",
  "BrownCS::udb::Schema::Computers",
  { "foreign.device_id" => "self.id" },
);
__PACKAGE__->has_many(
  "device_users",
  "BrownCS::udb::Schema::DeviceUsers",
  { "foreign.device_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "parent_device_id",
  "BrownCS::udb::Schema::Devices",
  { id => "parent_device_id" },
);
__PACKAGE__->has_many(
  "devices",
  "BrownCS::udb::Schema::Devices",
  { "foreign.parent_device_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "equip_status_type_id",
  "BrownCS::udb::Schema::EquipStatusTypes",
  { id => "equip_status_type_id" },
);
__PACKAGE__->belongs_to(
  "manager_id",
  "BrownCS::udb::Schema::ManagementTypes",
  { id => "manager_id" },
);
__PACKAGE__->belongs_to(
  "equip_usage_type_id",
  "BrownCS::udb::Schema::EquipUsageTypes",
  { id => "equip_usage_type_id" },
);
__PACKAGE__->belongs_to(
  "place_id",
  "BrownCS::udb::Schema::Places",
  { id => "place_id" },
);
__PACKAGE__->has_many(
  "net_interfaces",
  "BrownCS::udb::Schema::NetInterfaces",
  { "foreign.device_id" => "self.id" },
);
__PACKAGE__->has_many(
  "net_switches",
  "BrownCS::udb::Schema::NetSwitches",
  { "foreign.device_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pTMIzVRQo5oQw5r/wYhcHA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
