package BrownCS::UDB::Schema::NetSwitches;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_switches");
__PACKAGE__->add_columns(
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "fqdn",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "num_ports",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "num_blades",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "switch_type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "port_prefix",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "connection",
  {
    data_type => "text",
    default_value => "'ssh'::text",
    is_nullable => 0,
    size => undef,
  },
  "username",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "pass",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("name");
__PACKAGE__->add_unique_constraint("net_switches_pkey", ["name"]);
__PACKAGE__->has_many(
  "net_ports",
  "BrownCS::UDB::Schema::NetPorts",
  { "foreign.switch" => "self.name" },
);
__PACKAGE__->belongs_to("device", "BrownCS::UDB::Schema::Equipment", { name => "name" });

1;
