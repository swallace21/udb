package BrownCS::UDB::Schema::OsTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("os_types");
__PACKAGE__->add_columns(
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "pxe_boot",
  {
    data_type => "boolean",
    default_value => "false",
    is_nullable => 0,
    size => 1,
  },
);
__PACKAGE__->set_primary_key("name");
__PACKAGE__->add_unique_constraint("os_types_pkey", ["name"]);
__PACKAGE__->has_many(
  "comp_classes",
  "BrownCS::UDB::Schema::CompClasses",
  { "foreign.os" => "self.name" },
);
__PACKAGE__->has_many(
  "computers",
  "BrownCS::UDB::Schema::Computers",
  { "foreign.os" => "self.name" },
);

1;
