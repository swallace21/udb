package BrownCS::UDB::Schema::NetDnsEntries;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_dns_entries");
__PACKAGE__->add_columns(
  "dns_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "domain",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "dns_region",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "address",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "authoritative",
  { data_type => "boolean", default_value => undef, is_nullable => 0, size => 1 },
  "last_updated",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 1,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("dns_name", "domain", "dns_region");
__PACKAGE__->add_unique_constraint("net_dns_entries_pkey", ["dns_name", "domain", "dns_region"]);
__PACKAGE__->belongs_to(
  "address",
  "BrownCS::UDB::Schema::NetAddresses",
  { id => "address" },
);
__PACKAGE__->belongs_to(
  "dns_region",
  "BrownCS::UDB::Schema::DnsRegions",
  { name => "dns_region" },
);

1;
