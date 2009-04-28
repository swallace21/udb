package BrownCS::udb::Schema::CompClassesComputers;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("comp_classes_computers");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('comp_classes_computers_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "comp_class_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "computer_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("comp_classes_computers_pkey", ["id"]);
__PACKAGE__->belongs_to(
  "comp_class_id",
  "BrownCS::udb::Schema::CompClasses",
  { id => "comp_class_id" },
);
__PACKAGE__->belongs_to(
  "computer_id",
  "BrownCS::udb::Schema::Computers",
  { id => "computer_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:n49r2u+Ft0qsj7E6DEM3/Q


# You can replace this text with custom content, and it will be preserved on regeneration
1;
