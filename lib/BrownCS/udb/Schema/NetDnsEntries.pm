package BrownCS::udb::Schema::NetDnsEntries;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_dns_entries");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_dns_entries_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
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
  "dns_region_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "net_address_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "authoritative",
  { data_type => "boolean", default_value => undef, is_nullable => 0, size => 1 },
  "last_updated",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_dns_entries_pkey", ["id"]);
__PACKAGE__->belongs_to(
  "net_address_id",
  "BrownCS::udb::Schema::NetAddresses",
  { id => "net_address_id" },
);
__PACKAGE__->belongs_to(
  "dns_region_id",
  "BrownCS::udb::Schema::DnsRegions",
  { id => "dns_region_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KMxCCFMqgt1j7RMi/VHrKQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
