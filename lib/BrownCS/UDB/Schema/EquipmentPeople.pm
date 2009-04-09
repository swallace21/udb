package BrownCS::UDB::Schema::EquipmentPeople;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("equipment_people");
__PACKAGE__->add_columns(
  "equipment_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "equip_user_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("equipment_name", "equip_user_id");
__PACKAGE__->add_unique_constraint("equipment_people_pkey", ["equipment_name", "equip_user_id"]);
__PACKAGE__->belongs_to(
  "equip_user",
  "BrownCS::UDB::Schema::People",
  { id => "equip_user_id" },
);
__PACKAGE__->belongs_to(
  "equipment_name",
  "BrownCS::UDB::Schema::Equipment",
  { name => "equipment_name" },
);

1;
