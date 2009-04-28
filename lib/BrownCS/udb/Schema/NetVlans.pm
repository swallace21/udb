package BrownCS::udb::Schema::NetVlans;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_vlans");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_vlans_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "vlan_num",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "zone_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
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
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_vlans_vlan_num_key", ["vlan_num"]);
__PACKAGE__->add_unique_constraint("net_vlans_pkey", ["id"]);
__PACKAGE__->has_many(
  "net_addresses",
  "BrownCS::udb::Schema::NetAddresses",
  { "foreign.vlan_id" => "self.id" },
);
__PACKAGE__->has_many(
  "net_ports_net_vlans",
  "BrownCS::udb::Schema::NetPortsNetVlans",
  { "foreign.net_vlan_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "zone_id",
  "BrownCS::udb::Schema::NetZones",
  { id => "zone_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6EP9qMsZyBlRPUeSMtx+EA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
