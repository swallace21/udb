package BrownCS::udb::Schema::NetAddresses;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_addresses");
__PACKAGE__->add_columns(
  "net_address_id",
  {
    data_type => "integer",
    default_value => "nextval('net_addresses_net_address_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "zone_name",
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
  "monitored", { data_type => "boolean", default_value => undef, is_nullable => 0, size => 1 },
  "notification", { data_type => "boolean", default_value => undef, is_nullable => 0, size => 1 },
  "last_updated",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("net_address_id");
__PACKAGE__->add_unique_constraint("net_addresses_pkey", ["net_address_id"]);
__PACKAGE__->belongs_to(
  "zone",
  "BrownCS::udb::Schema::NetZones",
  { zone_name => "zone_name" },
);
__PACKAGE__->belongs_to(
  "vlan",
  "BrownCS::udb::Schema::NetVlans",
  { vlan_num => "vlan_num" },
);
__PACKAGE__->has_many(
  "net_addresses_net_interfaces",
  "BrownCS::udb::Schema::NetAddressesNetInterfaces",
  { "foreign.net_address_id" => "self.net_address_id" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_many(
  "net_addresses_net_services",
  "BrownCS::udb::Schema::NetAddressesNetServices",
  { "foreign.net_address_id" => "self.net_address_id" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_many(
  "net_dns_entries",
  "BrownCS::udb::Schema::NetDnsEntries",
  { "foreign.net_address_id" => "self.net_address_id" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->has_one(
  "primary_interface",
  "BrownCS::udb::Schema::NetInterfaces",
  { "foreign.primary_address_id" => "self.net_address_id" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->many_to_many(net_interfaces => 'net_addresses_net_interfaces', 'net_interface');
__PACKAGE__->many_to_many(net_services => 'net_addresses_net_services', 'net_service');

1;
