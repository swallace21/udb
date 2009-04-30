package BrownCS::udb::Schema::SurplusDevices;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("surplus_devices");
__PACKAGE__->add_columns(
  "surplus_device_id",
  {
    data_type => "integer",
    default_value => "nextval('surplus_devices_surplus_device_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "parent_surplus_device_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "surplus_date",
  { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "purchased_on",
  { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "installed_on",
  { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "buyer",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
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
  "comments",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("surplus_device_id");
__PACKAGE__->add_unique_constraint("surplus_devices_pkey", ["surplus_device_id"]);
__PACKAGE__->might_have(
  "parent_surplus_device",
  "BrownCS::udb::Schema::SurplusDevices",
  { surplus_device_id => "parent_surplus_device_id" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_many(
  "surplus_devices",
  "BrownCS::udb::Schema::SurplusDevices",
  { "foreign.parent_surplus_device_id" => "self.surplus_device_id" },
  {
    cascade_delete => 0,
  }
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZoXtdFBmgz3SzoXJYFxO6w


# You can replace this text with custom content, and it will be preserved on regeneration
1;
