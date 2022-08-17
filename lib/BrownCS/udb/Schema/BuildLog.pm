package BrownCS::udb::Schema::BuildLog;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("build_log");
__PACKAGE__->add_columns(
  "table_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "last_build",
  {
    data_type => "timestamp without time zone",
    default_value => undef,
    is_nullable => 0,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("table_name");
__PACKAGE__->add_unique_constraint("build_log_pkey", ["table_name"]);

1;
