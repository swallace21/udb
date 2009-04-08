package BrownCS::UDB::Schema::DnsRegions;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("dns_regions");
__PACKAGE__->add_columns(
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("name");
__PACKAGE__->add_unique_constraint("dns_regions_pkey", ["name"]);
__PACKAGE__->has_many(
  "net_dns_entries",
  "BrownCS::UDB::Schema::NetDnsEntries",
  { "foreign.dns_region" => "self.name" },
);

1;
