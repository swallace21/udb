package BrownCS::UDB::Schema::Computers;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("computers");
__PACKAGE__->add_columns(
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "os",
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
  "num_cpus",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 1,
    size => 4
  },
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
    is_nullable => 1,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("name");
__PACKAGE__->add_unique_constraint("computers_pkey", ["name"]);
__PACKAGE__->has_many(
  "comp_classes_computers",
  "BrownCS::UDB::Schema::CompClassesComputers",
  { "foreign.computer" => "self.name" },
);
__PACKAGE__->belongs_to("device", "BrownCS::UDB::Schema::Equipment", { name => "name" });
__PACKAGE__->belongs_to("os", "BrownCS::UDB::Schema::OsTypes", { name => "os" });
__PACKAGE__->many_to_many('classes' => 'comp_classes_computers', 'comp_class');
1;
