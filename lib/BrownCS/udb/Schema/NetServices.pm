package BrownCS::udb::Schema::NetServices;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_services");
__PACKAGE__->add_columns(
  "net_service",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("net_service");
__PACKAGE__->add_unique_constraint("net_services_pkey", ["net_service"]);
__PACKAGE__->has_many(
  "net_addresses_net_services",
  "BrownCS::udb::Schema::NetAddressesNetServices",
  { "foreign.net_service" => "self.net_service" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->many_to_many(net_addresses => 'net_addresses_net_services', 'net_address');


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SSI76WvH5VC7MtsGhcfmZA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
