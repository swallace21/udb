package BrownCS::udb::Schema::NetInterfaces;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_interfaces");
__PACKAGE__->add_columns(
  "net_interface_id",
  {
    data_type => "integer",
    default_value => "nextval('net_interfaces_net_interface_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "device_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "net_port_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "ethernet",
  { data_type => "macaddr", default_value => undef, is_nullable => 1, size => 6 },
  "primary_address_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "last_updated",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("net_interface_id");
__PACKAGE__->add_unique_constraint("net_interfaces_ethernet_key", ["ethernet"]);
__PACKAGE__->add_unique_constraint("net_interfaces_pkey", ["net_interface_id"]);
__PACKAGE__->has_many(
  "net_addresses_net_interfaces",
  "BrownCS::udb::Schema::NetAddressesNetInterfaces",
  { "foreign.net_interface_id" => "self.net_interface_id" },
);
__PACKAGE__->belongs_to(
  "device",
  "BrownCS::udb::Schema::Devices",
  { device_name => "device_name" },
);
__PACKAGE__->belongs_to(
  "net_port",
  "BrownCS::udb::Schema::NetPorts",
  { net_port_id => "net_port_id" },
);
__PACKAGE__->belongs_to(
  "primary_address",
  "BrownCS::udb::Schema::NetAddresses",
  { net_address_id => "primary_address_id" },
);
__PACKAGE__->many_to_many(net_addresses => 'net_addresses_net_interfaces', 'net_address');


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SjFNYo8N/FF8g3pPqJqdDw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
