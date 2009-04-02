package BrownCS::UDB::Schema::EquipStatusTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("equip_status_types");
__PACKAGE__->add_columns(
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("name");
__PACKAGE__->add_unique_constraint("equip_status_types_pkey", ["name"]);
__PACKAGE__->has_many(
  "equipments",
  "BrownCS::UDB::Schema::Equipment",
  { "foreign.equip_status" => "self.name" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rurW7JnFE4P2dIewMvD+Cw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
