package BrownCS::udb::Schema::UserGroups;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("user_groups");
__PACKAGE__->add_columns(
  "user_group_id",
  {
    data_type => "integer",
    default_value => "nextval('user_groups_user_group_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "gid",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "group_name",
  {
    data_type => "text",
    default_value => "nextval('gid_seq'::regclass)",
    is_nullable => 0,
    size => undef,
  },
  "created",
  { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "quota",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "last_updated" => { data_type => "timestamp without time zone", default_value => "now()", is_nullable => 0, size => 8, },
);
__PACKAGE__->set_primary_key("user_group_id");
__PACKAGE__->add_unique_constraint("user_groups_gid_key", ["gid"]);
__PACKAGE__->add_unique_constraint("user_groups_pkey", ["user_group_id"]);
__PACKAGE__->add_unique_constraint("user_groups_group_name_key", ["group_name"]);
__PACKAGE__->has_many(
  "user_groups_user_accounts",
  "BrownCS::udb::Schema::UserGroupsUserAccounts",
  { "foreign.user_group_id" => "self.user_group_id" },
  {
    cascade_delete => 0,
  }
);

1;
