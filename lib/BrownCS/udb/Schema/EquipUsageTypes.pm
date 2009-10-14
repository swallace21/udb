package BrownCS::udb::Schema::EquipUsageTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("equip_usage_types");
__PACKAGE__->add_columns(
  "equip_usage_type" => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
	"tracked" => { data_type => "boolean", default_value => "true", is_nullable => 0, size => 1, },
  "description" => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
);
__PACKAGE__->set_primary_key("equip_usage_type");
__PACKAGE__->add_unique_constraint("equip_usage_types_pkey", ["equip_usage_type"]);
__PACKAGE__->has_many(
  "devices",
  "BrownCS::udb::Schema::Devices",
  { "foreign.usage" => "self.equip_usage_type" },
  {
    cascade_delete => 0,
  }
);

1;
