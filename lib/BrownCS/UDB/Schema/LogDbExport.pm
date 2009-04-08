package BrownCS::UDB::Schema::LogDbExport;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("log_db_export");
__PACKAGE__->add_columns(
  "script_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "last_run",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 1,
    size => 8,
  },
  "id",
  {
    data_type => "integer",
    default_value => "nextval('log_db_export_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("log_db_export_pkey", ["id"]);

1;
