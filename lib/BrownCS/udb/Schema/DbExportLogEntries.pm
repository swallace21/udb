package BrownCS::udb::Schema::DbExportLogEntries;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("db_export_log_entries");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('db_export_log_entries_id_seq'::regclass)",
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
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("db_export_log_entries_pkey", ["id"]);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:S5JKXOpwTb3aPPaCFU0WUg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
