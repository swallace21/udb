package BrownCS::UDB::Schema::NetPorts;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_ports");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_ports_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "switch",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "port_num",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "wall_plate",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "last_updated",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
  "blade_num",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "place_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_ports_switch_key", ["switch", "port_num", "blade_num"]);
__PACKAGE__->add_unique_constraint("net_ports_pkey", ["id"]);
__PACKAGE__->has_many(
  "net_interfaces",
  "BrownCS::UDB::Schema::NetInterfaces",
  { "foreign.port_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "switch",
  "BrownCS::UDB::Schema::NetSwitches",
  { name => "switch" },
);
__PACKAGE__->belongs_to(
  "location",
  "BrownCS::UDB::Schema::Places",
  { id => "place_id" },
);
__PACKAGE__->has_many(
  "net_ports_net_vlans",
  "BrownCS::UDB::Schema::NetPortsNetVlans",
  { "foreign.net_ports_id" => "self.id" },
);
__PACKAGE__->many_to_many(
  'net_vlans' => 'net_ports_net_vlans',
  'vlan_num'
);

1;
