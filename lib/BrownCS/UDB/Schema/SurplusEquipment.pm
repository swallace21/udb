package BrownCS::UDB::Schema::SurplusEquipment;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("surplus_equipment");
__PACKAGE__->add_columns(
  "id"              => { data_type => "integer", default_value => "nextval('net_ports_id_seq'::regclass)", is_nullable => 0, size => 4, },
  "parent_equip_id" => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "surplus_date"    => { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "purchased_on"    => { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "installed_on"    => { data_type => "date", default_value => undef, is_nullable => 1, size => 4 },
  "name"            => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "buyer"           => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "brown_inv_num"   => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "serial_num"      => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "po_num"          => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "comments"        => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("surplus_equipment_pkey", ["id"]);
__PACKAGE__->belongs_to("name", "BrownCS::UDB::Schema::SurplusEquipment", { id => "id" });

1;
