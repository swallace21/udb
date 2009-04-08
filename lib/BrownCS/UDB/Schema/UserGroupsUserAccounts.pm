package BrownCS::UDB::Schema::UserGroupsUserAccounts;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("user_groups_user_accounts");
__PACKAGE__->add_columns(
  "user_groups_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "user_accounts_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("user_groups_id", "user_accounts_id");
__PACKAGE__->add_unique_constraint(
  "user_groups_user_accounts_pkey",
  ["user_groups_id", "user_accounts_id"],
);
__PACKAGE__->belongs_to(
  "user_groups_id",
  "BrownCS::UDB::Schema::UserGroups",
  { id => "user_groups_id" },
);
__PACKAGE__->belongs_to(
  "user_accounts_id",
  "BrownCS::UDB::Schema::UserAccounts",
  { id => "user_accounts_id" },
);

1;
