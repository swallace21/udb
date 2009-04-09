package BrownCS::UDB::Schema::People;

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
  "user_status",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
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
  "enrollments",
  "BrownCS::UDB::Schema::Enrollment",
  { "foreign.student_id" => "self.id" },
);
__PACKAGE__->has_many(
  "equipment_people",
  "BrownCS::UDB::Schema::EquipmentPeople",
  { "foreign.equip_user_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "user_status",
  "BrownCS::UDB::Schema::UserStatusTypes",
  { name => "user_status" },
);
__PACKAGE__->has_many(
  "user_accounts",
  "BrownCS::UDB::Schema::UserAccounts",
  { "foreign.people_id" => "self.id" },
);
__PACKAGE__->has_many(
  "user_accounts_people",
  "BrownCS::UDB::Schema::UserAccountsPeople",
  { "foreign.sponsor_id" => "self.id" },
);

1;
