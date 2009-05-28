package BrownCS::udb::Schema::OsTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("os_types");
__PACKAGE__->add_columns(
  "os_type"      => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "pxe_boot"     => { data_type => "boolean", default_value => "false", is_nullable => 0, size => 1, },
  "trusted_nfs"  => { data_type => "boolean", default_value => "false", is_nullable => 0, size => 1, },
  "wpkg"         => { data_type => "boolean", default_value => "false", is_nullable => 0, size => 1, },
  "last_updated" => { data_type => "timestamp without time zone", default_value => "now()", is_nullable => 0, size => 8, },
);
__PACKAGE__->set_primary_key("os_type");
__PACKAGE__->add_unique_constraint("os_types_pkey", ["os_type"]);
__PACKAGE__->has_many(
  "comp_classes",
  "BrownCS::udb::Schema::CompClasses",
  { "foreign.os_type" => "self.os_type" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_many(
  "computers",
  "BrownCS::udb::Schema::Computers",
  { "foreign.os_type" => "self.os_type" },
  {
    cascade_delete => 0,
  }
);

1;
