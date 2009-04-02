package BrownCS::UDB::Schema::NetAddresses;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_addresses");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_addresses_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "zone",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "vlan_num",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "ipaddr",
  {
    data_type => "inet",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "enabled",
  {
    data_type => "boolean",
    default_value => "true",
    is_nullable => 0,
    size => 1,
  },
  "monitored",
  { data_type => "boolean", default_value => undef, is_nullable => 0, size => 1 },
  "last_changed",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_addresses_pkey", ["id"]);
__PACKAGE__->belongs_to("zone", "BrownCS::UDB::Schema::NetZones", { name => "zone" });
__PACKAGE__->belongs_to(
  "vlan_num",
  "BrownCS::UDB::Schema::NetVlans",
  { vlan_num => "vlan_num" },
);
__PACKAGE__->has_many(
  "net_addresses_net_interfaces",
  "BrownCS::UDB::Schema::NetAddressesNetInterfaces",
  { "foreign.net_addresses_id" => "self.id" },
);
__PACKAGE__->has_many(
  "net_addresses_net_services",
  "BrownCS::UDB::Schema::NetAddressesNetServices",
  { "foreign.net_addresses_id" => "self.id" },
);
__PACKAGE__->has_many(
  "net_dns_entries",
  "BrownCS::UDB::Schema::NetDnsEntries",
  { "foreign.address" => "self.id" },
);
__PACKAGE__->has_many(
  "net_interfaces",
  "BrownCS::UDB::Schema::NetInterfaces",
  { "foreign.primary_address" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DEuWVicR94y5YU/AzeUIwQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
