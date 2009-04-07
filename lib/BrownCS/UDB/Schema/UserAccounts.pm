package BrownCS::UDB::Schema::UserAccounts;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("user_accounts");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('user_accounts_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "people_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "uid",
  {
    data_type => "integer",
    default_value => "nextval('uid_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "gid",
  {
    data_type => "integer",
    default_value => "nextval('gid_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "login",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "shell",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "home_dir",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "created",
  { data_type => "date", default_value => undef, is_nullable => 0, size => 4 },
  "expiration",
  { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "enabled",
  { data_type => "boolean", default_value => undef, is_nullable => 1, size => 1 },
  "last_updated",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("user_accounts_gid_key", ["gid"]);
__PACKAGE__->add_unique_constraint("user_accounts_uid_key", ["uid"]);
__PACKAGE__->add_unique_constraint("user_accounts_pkey", ["id"]);
__PACKAGE__->add_unique_constraint("user_accounts_login_key", ["login"]);
__PACKAGE__->has_many(
  "mail_aliases",
  "BrownCS::UDB::Schema::MailAliases",
  { "foreign.user_accounts_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "people_id",
  "BrownCS::UDB::Schema::People",
  { id => "people_id" },
);
__PACKAGE__->has_many(
  "user_accounts_peoples",
  "BrownCS::UDB::Schema::UserAccountsPeople",
  { "foreign.user_accounts_id" => "self.id" },
);
__PACKAGE__->has_many(
  "user_groups_user_accounts",
  "BrownCS::UDB::Schema::UserGroupsUserAccounts",
  { "foreign.user_accounts_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CTkWdD7FvylZjQNx05hBpA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
