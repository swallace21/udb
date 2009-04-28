package BrownCS::udb::Schema::NetAddressesNetServices;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_addresses_net_services");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_addresses_net_services_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "net_address_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "net_service_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_addresses_net_services_pkey", ["id"]);
__PACKAGE__->belongs_to(
  "net_service_id",
  "BrownCS::udb::Schema::NetServices",
  { id => "net_service_id" },
);
__PACKAGE__->belongs_to(
  "net_address_id",
  "BrownCS::udb::Schema::NetAddresses",
  { id => "net_address_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3FgZviCab/Ns3zr86BhDSA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
