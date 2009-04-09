package BrownCS::UDB::Schema::MailAliases;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("mail_aliases");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('mail_aliases_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "user_accounts_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "alias",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "target",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "alias_type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("mail_aliases_pkey", ["id"]);
__PACKAGE__->belongs_to(
  "user_accounts",
  "BrownCS::UDB::Schema::UserAccounts",
  { id => "user_accounts_id" },
);

1;
