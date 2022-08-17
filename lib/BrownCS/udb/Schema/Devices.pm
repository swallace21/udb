package BrownCS::udb::Schema::Devices;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("devices");
__PACKAGE__->add_columns(
  "device_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "parent_device_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "place_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "status",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "usage",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "manager",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
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
  "last_updated" => { data_type => "timestamp without time zone", default_value => "now()", is_nullable => 0, size => 8, },
);
__PACKAGE__->set_primary_key("device_name");
__PACKAGE__->add_unique_constraint("devices_pkey", ["device_name"]);
__PACKAGE__->might_have(
  "computer",
  "BrownCS::udb::Schema::Computers",
  { "foreign.device_name" => "self.device_name" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->might_have(
  "comp_sysinfo",
  "BrownCS::udb::Schema::CompSysinfo",
  { "foreign.device_name" => "self.device_name" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_many(
  "users",
  "BrownCS::udb::Schema::DeviceUsers",
  { "foreign.device_name" => "self.device_name" },
  {
    cascade_delete => 0,
  }
);
# To suppress the warning about using might_have on a nullable column
# (see https://metacpan.org/pod/DBIx::Class::Relationship#might_have),
# we set DBIC_DONT_VALIDATE_RELS to true. This is okay for a 
# relationship between things in the same table (as is the case here).
__PACKAGE__->might_have(
  "parent",
  "BrownCS::udb::Schema::Devices",
  { "foreign.parent_device_name" => "self.device_name" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_many(
  "children",
  "BrownCS::udb::Schema::Devices",
  { "foreign.parent_device_name" => "self.device_name" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->belongs_to(
  "manager",
  "BrownCS::udb::Schema::ManagementTypes",
  { management_type => "manager" },
);
__PACKAGE__->belongs_to(
  "status",
  "BrownCS::udb::Schema::EquipStatusTypes",
  { equip_status_type => "status" },
);
__PACKAGE__->belongs_to(
  "usage",
  "BrownCS::udb::Schema::EquipUsageTypes",
  { equip_usage_type => "usage" },
);
__PACKAGE__->belongs_to(
  "place",
  "BrownCS::udb::Schema::Places",
  { place_id => "place_id" },
);
__PACKAGE__->has_many(
  "net_interfaces",
  "BrownCS::udb::Schema::NetInterfaces",
  { "foreign.device_name" => "self.device_name" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->might_have(
  "net_switch",
  "BrownCS::udb::Schema::NetSwitches",
  { "foreign.device_name" => "self.device_name" },
  {
    cascade_delete => 0,
  }
);

1;
