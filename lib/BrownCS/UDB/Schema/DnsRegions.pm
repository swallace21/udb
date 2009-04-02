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


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2MEhDvJ3qTa7kVAAj4Fi9g


# You can replace this text with custom content, and it will be preserved on regeneration
1;
