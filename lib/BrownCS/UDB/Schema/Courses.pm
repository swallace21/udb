package BrownCS::UDB::Schema::Courses;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("courses");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('courses_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "course",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "year",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "description",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "instructor",
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
  "phd_area1",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "phd_area2",
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
__PACKAGE__->add_unique_constraint("courses_pkey", ["id"]);
__PACKAGE__->has_many(
  "enrollments",
  "BrownCS::UDB::Schema::Enrollment",
  { "foreign.course_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wRdfPwBDc6Vx5DzcIGHiCw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
