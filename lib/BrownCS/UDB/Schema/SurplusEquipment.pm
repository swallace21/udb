package BrownCS::UDB::Schema::SurplusEquipment;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("surplus_equipment");
__PACKAGE__->add_columns(
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "surplus_date",
  { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "sale_date",
  { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "buyer",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("name");
__PACKAGE__->add_unique_constraint("surplus_equipment_pkey", ["name"]);
__PACKAGE__->belongs_to("name", "BrownCS::UDB::Schema::Equipment", { name => "name" });

1;
