package BrownCS::udb::Schema::UserAccounts;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("user_accounts");
__PACKAGE__->add_columns(
  "user_account_id",
  {
    data_type => "integer",
    default_value => "nextval('user_accounts_user_account_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "person_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "sponsor_id",
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
__PACKAGE__->set_primary_key("user_account_id");
__PACKAGE__->add_unique_constraint("user_accounts_gid_key", ["gid"]);
__PACKAGE__->add_unique_constraint("user_accounts_uid_key", ["uid"]);
__PACKAGE__->add_unique_constraint("user_accounts_pkey", ["user_account_id"]);
__PACKAGE__->add_unique_constraint("user_accounts_login_key", ["login"]);
__PACKAGE__->has_many(
  "mail_aliases",
  "BrownCS::udb::Schema::MailAliases",
  { "foreign.user_account_id" => "self.user_account_id" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->belongs_to(
  "sponsor",
  "BrownCS::udb::Schema::People",
  { person_id => "sponsor_id" },
);
__PACKAGE__->belongs_to(
  "person",
  "BrownCS::udb::Schema::People",
  { person_id => "person_id" },
);
__PACKAGE__->has_many(
  "user_groups_user_accounts",
  "BrownCS::udb::Schema::UserGroupsUserAccounts",
  { "foreign.user_account_id" => "self.user_account_id" },
  {
    cascade_delete => 0,
  }
);

1;
