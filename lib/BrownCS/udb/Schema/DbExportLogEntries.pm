package BrownCS::udb::Schema::DbExportLogEntries;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("db_export_log_entries");
__PACKAGE__->add_columns(
  "db_export_log_entry_id",
  {
    data_type => "integer",
    default_value => "nextval('db_export_log_entries_db_export_log_entry_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "script_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "last_run",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("db_export_log_entry_id");
__PACKAGE__->add_unique_constraint("db_export_log_entries_pkey", ["db_export_log_entry_id"]);

1;
