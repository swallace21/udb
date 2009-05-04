package BrownCS::udb::Schema::Computers;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("computers");
__PACKAGE__->add_columns(
  "device_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "os_type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "pxelink",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("device_name");
__PACKAGE__->add_unique_constraint("computers_pkey", ["device_name"]);
__PACKAGE__->has_many(
  "comp_classes_computers",
  "BrownCS::udb::Schema::CompClassesComputers",
  { "foreign.device_name" => "self.device_name" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->belongs_to(
  "os_type",
  "BrownCS::udb::Schema::OsTypes",
  { os_type => "os_type" },
);
__PACKAGE__->belongs_to(
  "device",
  "BrownCS::udb::Schema::Devices",
  { device_name => "device_name" },
);
__PACKAGE__->many_to_many(comp_classes => 'comp_classes_computers', 'comp_class');


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NcFKgrvMrWFX+wvGxLMEAg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
