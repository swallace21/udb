package BrownCS::udb::Schema::CompClassesComputers;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("comp_classes_computers");
__PACKAGE__->add_columns(
  "comp_class_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "device_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("comp_class_id", "device_name");
__PACKAGE__->add_unique_constraint(
  "comp_classes_computers_pkey",
  ["comp_class_id", "device_name"],
);
__PACKAGE__->belongs_to(
  "comp_class",
  "BrownCS::udb::Schema::CompClasses",
  { comp_class_id => "comp_class_id" },
);
__PACKAGE__->belongs_to(
  "computer",
  "BrownCS::udb::Schema::Computers",
  { device_name => "device_name" },
);

1;
