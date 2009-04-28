package BrownCS::udb::Schema::NetSwitches;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_switches");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_switches_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "device_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
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
  "connection_type",
  {
    data_type => "text",
    default_value => "'ssh'::text",
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_switches_pkey", ["id"]);
__PACKAGE__->has_many(
  "net_ports",
  "BrownCS::udb::Schema::NetPorts",
  { "foreign.net_switch_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "device_id",
  "BrownCS::udb::Schema::Devices",
  { id => "device_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SNJGoQHdySFoLYbvDYQY2w


# You can replace this text with custom content, and it will be preserved on regeneration
1;
