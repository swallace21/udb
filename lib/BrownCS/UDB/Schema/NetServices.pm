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


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Sj54781zd8y38TiLGOrJig


# You can replace this text with custom content, and it will be preserved on regeneration
1;
