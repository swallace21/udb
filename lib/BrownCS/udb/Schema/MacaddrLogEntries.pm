package BrownCS::udb::Schema::MacaddrLogEntries;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("macaddr_log_entries");
__PACKAGE__->add_columns(
  "macaddr_log_entry_id",
  {
    data_type => "integer",
    default_value => "nextval('macaddr_log_entries_macaddr_log_entry_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "entry_time",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
  "switch_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "port",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "macaddr",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "data",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("macaddr_log_entry_id");
__PACKAGE__->add_unique_constraint("macaddr_log_entries_pkey", ["macaddr_log_entry_id"]);

1;
