package BrownCS::udb::Schema::NetAddressesNetServices;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_addresses_net_services");
__PACKAGE__->add_columns(
  "net_address_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "net_service",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("net_address_id", "net_service");
__PACKAGE__->add_unique_constraint(
  "net_addresses_net_services_pkey",
  ["net_address_id", "net_service"],
);
__PACKAGE__->belongs_to(
  "net_service",
  "BrownCS::udb::Schema::NetServices",
  { net_service => "net_service" },
);
__PACKAGE__->belongs_to(
  "net_address",
  "BrownCS::udb::Schema::NetAddresses",
  { net_address_id => "net_address_id" },
);

1;
