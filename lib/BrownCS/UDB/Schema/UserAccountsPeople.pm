package BrownCS::UDB::Schema::UserAccountsPeople;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("user_accounts_people");
__PACKAGE__->add_columns(
  "user_accounts_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "sponsor_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("user_accounts_id", "sponsor_id");
__PACKAGE__->add_unique_constraint(
  "user_accounts_people_pkey",
  ["user_accounts_id", "sponsor_id"],
);
__PACKAGE__->belongs_to(
  "user_accounts_id",
  "BrownCS::UDB::Schema::UserAccounts",
  { id => "user_accounts_id" },
);
__PACKAGE__->belongs_to(
  "sponsor_id",
  "BrownCS::UDB::Schema::People",
  { id => "sponsor_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jWMtXXlSQdib65jm3zKKpg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
