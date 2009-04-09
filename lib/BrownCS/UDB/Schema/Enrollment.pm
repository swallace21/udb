package BrownCS::UDB::Schema::Enrollment;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("enrollment");
__PACKAGE__->add_columns(
  "student_id",
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
__PACKAGE__->set_primary_key("student_id", "course_id");
__PACKAGE__->add_unique_constraint("enrollment_pkey", ["student_id", "course_id"]);
__PACKAGE__->belongs_to(
  "course",
  "BrownCS::UDB::Schema::Courses",
  { id => "course_id" },
);
__PACKAGE__->belongs_to(
  "student",
  "BrownCS::UDB::Schema::People",
  { id => "student_id" },
);

1;
