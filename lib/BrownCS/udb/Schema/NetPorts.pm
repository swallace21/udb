package BrownCS::udb::Schema::NetPorts;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_ports");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_ports_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "place_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "net_switch_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "port_num",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "wall_plate",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "last_updated",
  {
    data_type => "timestamp without time zone",
    default_value => "now()",
    is_nullable => 0,
    size => 8,
  },
  "blade_num",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "net_ports_switch_id_key",
  ["net_switch_id", "port_num", "blade_num"],
);
__PACKAGE__->add_unique_constraint("net_ports_pkey", ["id"]);
__PACKAGE__->has_many(
  "net_interfaces",
  "BrownCS::udb::Schema::NetInterfaces",
  { "foreign.net_port_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "net_switch_id",
  "BrownCS::udb::Schema::NetSwitches",
  { id => "net_switch_id" },
);
__PACKAGE__->belongs_to(
  "place_id",
  "BrownCS::udb::Schema::Places",
  { id => "place_id" },
);
__PACKAGE__->has_many(
  "net_ports_net_vlans",
  "BrownCS::udb::Schema::NetPortsNetVlans",
  { "foreign.net_port_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6/hMHMgrL9QPrIy+kA5ccA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
