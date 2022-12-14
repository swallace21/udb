package BrownCS::udb::Schema::UserGroupsUserAccounts;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("user_groups_user_accounts");
__PACKAGE__->add_columns(
  "user_group_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "user_account_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("user_group_id", "user_account_id");
__PACKAGE__->add_unique_constraint(
  "user_groups_user_accounts_pkey",
  ["user_group_id", "user_account_id"],
);
__PACKAGE__->belongs_to(
  "user_account",
  "BrownCS::udb::Schema::UserAccounts",
  { user_account_id => "user_account_id" },
);
__PACKAGE__->belongs_to(
  "user_group",
  "BrownCS::udb::Schema::UserGroups",
  { user_group_id => "user_group_id" },
);

1;
