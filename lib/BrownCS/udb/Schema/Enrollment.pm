package BrownCS::udb::Schema::Enrollment;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("enrollment");
__PACKAGE__->add_columns(
  "enrollment_id",
  {
    data_type => "integer",
    default_value => "nextval('enrollment_enrollment_id_seq'::regclass)",
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
  "last_updated" => { data_type => "timestamp without time zone", default_value => "now()", is_nullable => 0, size => 8, },
);
__PACKAGE__->set_primary_key("enrollment_id");
__PACKAGE__->add_unique_constraint("enrollment_pkey", ["enrollment_id"]);
__PACKAGE__->belongs_to(
  "course",
  "BrownCS::udb::Schema::Courses",
  { course_id => "course_id" },
);
__PACKAGE__->belongs_to(
  "person",
  "BrownCS::udb::Schema::People",
  { person_id => "person_id" },
);

1;
