package BrownCS::udb::Schema::FsAutomounts;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("fs_automounts");
__PACKAGE__->add_columns(
  "fs_automount_id",
  {
    data_type => "integer",
    default_value => "nextval('fs_automounts_fs_automount_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "client_path",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "server",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "server_path",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "flags",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "last_updated" => { data_type => "timestamp without time zone", default_value => "now()", is_nullable => 0, size => 8, },
);
__PACKAGE__->set_primary_key("fs_automount_id");
__PACKAGE__->add_unique_constraint("fs_automounts_pkey", ["fs_automount_id"]);

1;
