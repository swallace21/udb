package BrownCS::UDB::Schema::NetPortsNetVlans;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_ports_net_vlans");
__PACKAGE__->add_columns(
  "net_ports_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "vlan_num",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "native",
  {
    data_type => "boolean",
    default_value => "false",
    is_nullable => 0,
    size => 1,
  },
);
__PACKAGE__->set_primary_key("net_ports_id", "vlan_num");
__PACKAGE__->add_unique_constraint("net_ports_net_vlans_pkey", ["net_ports_id", "vlan_num"]);
__PACKAGE__->belongs_to(
  "net_ports_id",
  "BrownCS::UDB::Schema::NetPorts",
  { id => "net_ports_id" },
);
__PACKAGE__->belongs_to(
  "vlan_num",
  "BrownCS::UDB::Schema::NetVlans",
  { vlan_num => "vlan_num" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5jvphJQJuueq+Dos9eoV+A


# You can replace this text with custom content, and it will be preserved on regeneration
1;
