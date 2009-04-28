package BrownCS::udb::Schema::DnsRegions;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("dns_regions");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('dns_regions_id_seq'::regclass)",
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
__PACKAGE__->add_unique_constraint("dns_regions_name_key", ["name"]);
__PACKAGE__->add_unique_constraint("dns_regions_pkey", ["id"]);
__PACKAGE__->has_many(
  "net_dns_entries",
  "BrownCS::udb::Schema::NetDnsEntries",
  { "foreign.dns_region_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:z6GCEaA6LwAG14XdcK7Neg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
