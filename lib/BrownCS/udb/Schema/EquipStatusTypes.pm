package BrownCS::udb::Schema::EquipStatusTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("equip_status_types");
__PACKAGE__->add_columns(
  "equip_status_type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("equip_status_type");
__PACKAGE__->add_unique_constraint("equip_status_types_pkey", ["equip_status_type"]);
__PACKAGE__->has_many(
  "devices",
  "BrownCS::udb::Schema::Devices",
  { "foreign.status" => "self.equip_status_type" },
  {
    cascade_delete => 0,
  }
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Zipk36vUqQcZo7X2uFzvbQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
