package BrownCS::udb::Schema::NetPortsNetVlans;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_ports_net_vlans");
__PACKAGE__->add_columns(
  "net_port_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "vlan_num",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "native",
  { data_type => "boolean", default_value => undef, is_nullable => 0, size => 1 },
);
__PACKAGE__->set_primary_key("net_port_id", "vlan_num");
__PACKAGE__->add_unique_constraint("net_ports_net_vlans_pkey", ["net_port_id", "vlan_num"]);
__PACKAGE__->belongs_to(
  "net_port",
  "BrownCS::udb::Schema::NetPorts",
  { net_port_id => "net_port_id" },
);
__PACKAGE__->belongs_to(
  "vlan_num",
  "BrownCS::udb::Schema::NetVlans",
  { vlan_num => "vlan_num" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:eVNhDTP8cMsvGWz1be+hoA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
