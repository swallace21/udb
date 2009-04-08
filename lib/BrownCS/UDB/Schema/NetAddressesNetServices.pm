package BrownCS::UDB::Schema::NetAddressesNetServices;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_addresses_net_services");
__PACKAGE__->add_columns(
  "net_addresses_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "net_services_id",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("net_addresses_id", "net_services_id");
__PACKAGE__->add_unique_constraint(
  "net_addresses_net_services_pkey",
  ["net_addresses_id", "net_services_id"],
);
__PACKAGE__->belongs_to(
  "net_services_id",
  "BrownCS::UDB::Schema::NetServices",
  { service => "net_services_id" },
);
__PACKAGE__->belongs_to(
  "net_addresses_id",
  "BrownCS::UDB::Schema::NetAddresses",
  { id => "net_addresses_id" },
);

1;
