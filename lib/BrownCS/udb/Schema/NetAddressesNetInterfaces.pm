package BrownCS::udb::Schema::NetAddressesNetInterfaces;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_addresses_net_interfaces");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_addresses_net_interfaces_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "net_address_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "net_interface_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_addresses_net_interfaces_pkey", ["id"]);
__PACKAGE__->belongs_to(
  "net_address_id",
  "BrownCS::udb::Schema::NetAddresses",
  { id => "net_address_id" },
);
__PACKAGE__->belongs_to(
  "net_interface_id",
  "BrownCS::udb::Schema::NetInterfaces",
  { id => "net_interface_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kwkjHsb0wg5lEhreyetFmg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
