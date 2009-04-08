package BrownCS::UDB::Schema::NetVlans;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_vlans");
__PACKAGE__->add_columns(
  "vlan_num",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "zone",
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
);
__PACKAGE__->set_primary_key("vlan_num");
__PACKAGE__->add_unique_constraint("net_vlans_pkey", ["vlan_num"]);
__PACKAGE__->has_many(
  "net_addresses",
  "BrownCS::UDB::Schema::NetAddresses",
  { "foreign.vlan_num" => "self.vlan_num" },
);
__PACKAGE__->has_many(
  "net_ports_net_vlans",
  "BrownCS::UDB::Schema::NetPortsNetVlans",
  { "foreign.vlan_num" => "self.vlan_num" },
);
__PACKAGE__->belongs_to("zone", "BrownCS::UDB::Schema::NetZones", { name => "zone" });


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yjsk3VaZPA7eTsKXGf6TBA


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->many_to_many('net_ports' => 'net_ports_net_vlans', 'net_ports_id');
1;
