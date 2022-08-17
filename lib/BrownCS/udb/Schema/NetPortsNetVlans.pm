package BrownCS::udb::Schema::NetPortsNetVlans;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_ports_net_vlans");
__PACKAGE__->add_columns(
  "net_port_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "vlan_num",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "native",
  { data_type => "boolean", default_value => undef, is_nullable => 0, size => 1 },
  "last_updated" => { data_type => "timestamp without time zone", default_value => "now()", is_nullable => 0, size => 8, },
);
__PACKAGE__->set_primary_key("net_port_id", "vlan_num");
__PACKAGE__->add_unique_constraint("net_ports_net_vlans_pkey", ["net_port_id", "vlan_num"]);
__PACKAGE__->belongs_to(
  "net_port",
  "BrownCS::udb::Schema::NetPorts",
  { net_port_id => "net_port_id" },
);
__PACKAGE__->belongs_to(
  "net_vlan",
  "BrownCS::udb::Schema::NetVlans",
  { vlan_num => "vlan_num" },
);

1;
