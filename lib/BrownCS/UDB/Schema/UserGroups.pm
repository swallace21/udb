package BrownCS::UDB::Schema::UserGroups;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("user_groups");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('user_groups_id_seq'::regclass)",
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
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("user_groups_gid_key", ["gid"]);
__PACKAGE__->add_unique_constraint("user_groups_pkey", ["id"]);
__PACKAGE__->add_unique_constraint("user_groups_group_name_key", ["group_name"]);
__PACKAGE__->has_many(
  "user_groups_user_accounts",
  "BrownCS::UDB::Schema::UserGroupsUserAccounts",
  { "foreign.user_groups_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:X8GyRq2lwfjkFZ+DHvFBnA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
