package BrownCS::udb::Schema::UserGroupsUserAccounts;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("user_groups_user_accounts");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('user_groups_user_accounts_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "user_group_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "user_account_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("user_groups_user_accounts_pkey", ["id"]);
__PACKAGE__->belongs_to(
  "user_account_id",
  "BrownCS::udb::Schema::UserAccounts",
  { id => "user_account_id" },
);
__PACKAGE__->belongs_to(
  "user_group_id",
  "BrownCS::udb::Schema::UserGroups",
  { id => "user_group_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xFAJMPpjGNc3cziZ7DUnZw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
