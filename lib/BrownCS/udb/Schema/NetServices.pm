package BrownCS::udb::Schema::NetServices;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_services");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_services_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_services_pkey", ["id"]);
__PACKAGE__->add_unique_constraint("net_services_service_key", ["name"]);
__PACKAGE__->has_many(
  "net_addresses_net_services",
  "BrownCS::udb::Schema::NetAddressesNetServices",
  { "foreign.net_service_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:YpF+suQe/7tlPNt7f9ZUcQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
