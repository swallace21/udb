package BrownCS::udb::Schema::DnsRegions;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("dns_regions");
__PACKAGE__->add_columns(
  "dns_region",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("dns_region");
__PACKAGE__->add_unique_constraint("dns_regions_pkey", ["dns_region"]);
__PACKAGE__->has_many(
  "net_dns_entries",
  "BrownCS::udb::Schema::NetDnsEntries",
  { "foreign.dns_region" => "self.dns_region" },
  {
    cascade_delete => 0,
  }
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Bef16oLYcRU4EqgbVx9DxA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
