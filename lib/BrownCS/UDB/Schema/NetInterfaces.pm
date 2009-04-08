package BrownCS::UDB::Schema::NetInterfaces;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_interfaces");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_interfaces_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "equip_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "port_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "ethernet",
  { data_type => "macaddr", default_value => undef, is_nullable => 1, size => 6 },
  "primary_address",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "last_updated",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_interfaces_ethernet_key", ["ethernet"]);
__PACKAGE__->add_unique_constraint("net_interfaces_pkey", ["id"]);
__PACKAGE__->has_many(
  "net_addresses_net_interfaces",
  "BrownCS::UDB::Schema::NetAddressesNetInterfaces",
  { "foreign.net_interfaces_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "port",
  "BrownCS::UDB::Schema::NetPorts",
  { id => "port_id" },
);
__PACKAGE__->belongs_to(
  "device",
  "BrownCS::UDB::Schema::Equipment",
  { name => "equip_name" },
);
__PACKAGE__->belongs_to(
  "primary_address",
  "BrownCS::UDB::Schema::NetAddresses",
  { id => "primary_address" },
);
__PACKAGE__->many_to_many(
  'net_addresses' => 'net_addresses_net_interfaces',
  'net_addresses_id'
);

1;
