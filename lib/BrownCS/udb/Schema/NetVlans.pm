package BrownCS::udb::Schema::NetVlans;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_vlans");
__PACKAGE__->add_columns(
  "vlan_num",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "zone_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "network",
  {
    data_type => "cidr",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "gateway",
  {
    data_type => "inet",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "dhcp",
  {
    data_type => "boolean",
    default_value => "true",
    is_nullable => 0,
    size => 1,
  },
  "dynamic_dhcp_start",
  {
    data_type => "inet",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "dynamic_dhcp_end",
  {
    data_type => "inet",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "last_updated" => { data_type => "timestamp without time zone", default_value => "now()", is_nullable => 0, size => 8, },
);
__PACKAGE__->set_primary_key("vlan_num");
__PACKAGE__->add_unique_constraint("net_vlans_pkey", ["vlan_num"]);
__PACKAGE__->has_many(
  "net_addresses",
  "BrownCS::udb::Schema::NetAddresses",
  { "foreign.vlan_num" => "self.vlan_num" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_many(
  "net_ports_net_vlans",
  "BrownCS::udb::Schema::NetPortsNetVlans",
  { "foreign.vlan_num" => "self.vlan_num" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->belongs_to(
  "zone",
  "BrownCS::udb::Schema::NetZones",
  { zone_name => "zone_name" },
);
__PACKAGE__->many_to_many(net_ports => 'net_ports_net_vlans', 'net_port');

1;
