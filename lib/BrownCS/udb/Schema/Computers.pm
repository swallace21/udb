package BrownCS::udb::Schema::Computers;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("computers");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('computers_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "device_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "os_type_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "pxelink",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "num_cpus",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "cpu_type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "cpu_speed",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "memory",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "hard_drives",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "video_cards",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "last_updated",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("computers_pkey", ["id"]);
__PACKAGE__->has_many(
  "comp_classes_computers",
  "BrownCS::udb::Schema::CompClassesComputers",
  { "foreign.computer_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "device_id",
  "BrownCS::udb::Schema::Devices",
  { id => "device_id" },
);
__PACKAGE__->belongs_to(
  "os_type_id",
  "BrownCS::udb::Schema::OsTypes",
  { id => "os_type_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:x1ovP5z0tB1aoVOlWXYHQw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
