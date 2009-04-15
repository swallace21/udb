package BrownCS::UDB::Schema::LogDhcp;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("log_dhcp");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('log_dhcp_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "entry_time",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 1,
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
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("log_dhcp_pkey", ["id"]);

1;
