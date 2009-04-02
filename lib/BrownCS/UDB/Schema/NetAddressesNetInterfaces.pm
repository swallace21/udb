package BrownCS::UDB::Schema::NetAddressesNetInterfaces;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_addresses_net_interfaces");
__PACKAGE__->add_columns(
  "net_addresses_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "net_interfaces_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("net_addresses_id", "net_interfaces_id");
__PACKAGE__->add_unique_constraint(
  "net_addresses_net_interfaces_pkey",
  ["net_addresses_id", "net_interfaces_id"],
);
__PACKAGE__->belongs_to(
  "net_interfaces_id",
  "BrownCS::UDB::Schema::NetInterfaces",
  { id => "net_interfaces_id" },
);
__PACKAGE__->belongs_to(
  "net_addresses_id",
  "BrownCS::UDB::Schema::NetAddresses",
  { id => "net_addresses_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tRifCP6VMmiURIufBSiO0w


# You can replace this text with custom content, and it will be preserved on regeneration
1;
