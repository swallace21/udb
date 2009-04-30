package BrownCS::udb::Schema::DhcpLogEntries;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("dhcp_log_entries");
__PACKAGE__->add_columns(
  "dhcp_log_entry_id",
  {
    data_type => "integer",
    default_value => "nextval('dhcp_log_entries_dhcp_log_entry_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "entry_time",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
  "ethernet",
  { data_type => "macaddr", default_value => undef, is_nullable => 0, size => 6 },
  "ipaddr",
  {
    data_type => "inet",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "data",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("dhcp_log_entry_id");
__PACKAGE__->add_unique_constraint("dhcp_log_entries_pkey", ["dhcp_log_entry_id"]);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LKnGQqbksspgHe7g02GoUQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
