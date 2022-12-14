package BrownCS::udb::Schema::NetAddressesNetInterfaces;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_addresses_net_interfaces");
__PACKAGE__->add_columns(
  "net_address_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "net_interface_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("net_address_id", "net_interface_id");
__PACKAGE__->add_unique_constraint(
  "net_addresses_net_interfaces_pkey",
  ["net_address_id", "net_interface_id"],
);
__PACKAGE__->belongs_to(
  "net_address",
  "BrownCS::udb::Schema::NetAddresses",
  { net_address_id => "net_address_id" },
);
__PACKAGE__->belongs_to(
  "net_interface",
  "BrownCS::udb::Schema::NetInterfaces",
  { net_interface_id => "net_interface_id" },
);

1;
