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
);
__PACKAGE__->set_primary_key("fs_automount_id");
__PACKAGE__->add_unique_constraint("fs_automounts_pkey", ["fs_automount_id"]);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:b9UCOQ2mst8p4efAAkGyhA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
