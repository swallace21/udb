package BrownCS::UDB::Schema::CompClassesComputers;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("comp_classes_computers");
__PACKAGE__->add_columns(
  "comp_class",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "computer",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("comp_class", "computer");
__PACKAGE__->add_unique_constraint("comp_classes_computers_pkey", ["comp_class", "computer"]);
__PACKAGE__->belongs_to(
  "computer",
  "BrownCS::UDB::Schema::Computers",
  { name => "computer" },
);
__PACKAGE__->belongs_to(
  "comp_class",
  "BrownCS::UDB::Schema::CompClasses",
  { id => "comp_class" },
);

1;
