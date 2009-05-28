package BrownCS::udb::Schema::MailAliases;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("mail_aliases");
__PACKAGE__->add_columns(
  "mail_alias_id",
  {
    data_type => "integer",
    default_value => "nextval('mail_aliases_mail_alias_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "user_account_id",
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
  "last_updated" => { data_type => "timestamp without time zone", default_value => "now()", is_nullable => 0, size => 8, },
);
__PACKAGE__->set_primary_key("mail_alias_id");
__PACKAGE__->add_unique_constraint("mail_aliases_pkey", ["mail_alias_id"]);
__PACKAGE__->belongs_to(
  "user_account",
  "BrownCS::udb::Schema::UserAccounts",
  { user_account_id => "user_account_id" },
);

1;
