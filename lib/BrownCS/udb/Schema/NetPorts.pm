package BrownCS::udb::Schema::NetPorts;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_ports");
__PACKAGE__->add_columns(
  "net_port_id",
  {
    data_type => "integer",
    default_value => "nextval('net_ports_net_port_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "place_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "switch_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
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
__PACKAGE__->set_primary_key("net_port_id");
__PACKAGE__->add_unique_constraint(
  "net_ports_switch_name_key",
  ["switch_name", "port_num", "blade_num"],
);
__PACKAGE__->add_unique_constraint("net_ports_pkey", ["net_port_id"]);
__PACKAGE__->has_many(
  "net_interfaces",
  "BrownCS::udb::Schema::NetInterfaces",
  { "foreign.net_port_id" => "self.net_port_id" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->belongs_to(
  "net_switch",
  "BrownCS::udb::Schema::NetSwitches",
  { device_name => "switch_name" },
);
__PACKAGE__->belongs_to(
  "place",
  "BrownCS::udb::Schema::Places",
  { place_id => "place_id" },
);
__PACKAGE__->has_many(
  "net_ports_net_vlans",
  "BrownCS::udb::Schema::NetPortsNetVlans",
  { "foreign.net_port_id" => "self.net_port_id" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->many_to_many(net_vlans => 'net_ports_net_vlans', 'net_vlan');


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5RxCgi3jwnkgg0CdCQzHRg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
