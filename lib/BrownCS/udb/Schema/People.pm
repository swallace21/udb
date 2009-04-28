package BrownCS::udb::Schema::People;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("people");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('people_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "user_status_type_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "full_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "common_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "family_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "alternate_email",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "auth_id",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "brown_card_id",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "gender",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "office",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "office_phone",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "home_phone",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "cell_phone",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("people_brown_card_id_key", ["brown_card_id"]);
__PACKAGE__->add_unique_constraint("people_pkey", ["id"]);
__PACKAGE__->has_many(
  "device_users",
  "BrownCS::udb::Schema::DeviceUsers",
  { "foreign.person_id" => "self.id" },
);
__PACKAGE__->has_many(
  "enrollments",
  "BrownCS::udb::Schema::Enrollment",
  { "foreign.person_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "user_status_type_id",
  "BrownCS::udb::Schema::UserStatusTypes",
  { id => "user_status_type_id" },
);
__PACKAGE__->has_many(
  "user_accounts_sponsor_ids",
  "BrownCS::udb::Schema::UserAccounts",
  { "foreign.sponsor_id" => "self.id" },
);
__PACKAGE__->has_many(
  "user_accounts_person_ids",
  "BrownCS::udb::Schema::UserAccounts",
  { "foreign.person_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QWYiOD996Bbw5l6tXZf3fw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
