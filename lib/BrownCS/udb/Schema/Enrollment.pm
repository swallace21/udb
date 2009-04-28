package BrownCS::udb::Schema::Enrollment;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("enrollment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('enrollment_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "person_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "course_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "year",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "grade",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "phd_seq",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "phd_area",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "ugrad_area",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "level_100",
  { data_type => "boolean", default_value => undef, is_nullable => 1, size => 1 },
  "level_200",
  { data_type => "boolean", default_value => undef, is_nullable => 1, size => 1 },
  "scm_theory",
  { data_type => "boolean", default_value => undef, is_nullable => 1, size => 1 },
  "scm_practice",
  { data_type => "boolean", default_value => undef, is_nullable => 1, size => 1 },
  "scm_prog",
  { data_type => "boolean", default_value => undef, is_nullable => 1, size => 1 },
  "scm_research",
  { data_type => "boolean", default_value => undef, is_nullable => 1, size => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("enrollment_pkey", ["id"]);
__PACKAGE__->belongs_to(
  "course_id",
  "BrownCS::udb::Schema::Courses",
  { id => "course_id" },
);
__PACKAGE__->belongs_to(
  "person_id",
  "BrownCS::udb::Schema::People",
  { id => "person_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:V6/RwXO+YBTFq/jL7ebuNA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
