package BrownCS::UDB::Schema::NetServices;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_services");
__PACKAGE__->add_columns(
  "service",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("service");
__PACKAGE__->add_unique_constraint("net_services_pkey", ["service"]);
__PACKAGE__->has_many(
  "net_addresses_net_services",
  "BrownCS::UDB::Schema::NetAddressesNetServices",
  { "foreign.net_services_id" => "self.service" },
);
__PACKAGE__->many_to_many(
  'net_addresses' => 'net_addresses_net_services',
  'net_addresses_id'
);

1;
