package BrownCS::udb::Schema::OsTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("os_types");
__PACKAGE__->add_columns(
  "os_type",
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
__PACKAGE__->set_primary_key("os_type");
__PACKAGE__->add_unique_constraint("os_types_pkey", ["os_type"]);
__PACKAGE__->has_many(
  "comp_classes",
  "BrownCS::udb::Schema::CompClasses",
  { "foreign.os_type" => "self.os_type" },
);
__PACKAGE__->has_many(
  "computers",
  "BrownCS::udb::Schema::Computers",
  { "foreign.os_type" => "self.os_type" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IPvamFd3sin0Hmq931xFoA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
