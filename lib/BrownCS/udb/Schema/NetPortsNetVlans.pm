package BrownCS::udb::Schema::NetPortsNetVlans;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_ports_net_vlans");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('net_ports_net_vlans_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "net_port_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "net_vlan_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "native",
  { data_type => "boolean", default_value => undef, is_nullable => 0, size => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("net_ports_net_vlans_pkey", ["id"]);
__PACKAGE__->belongs_to(
  "net_port_id",
  "BrownCS::udb::Schema::NetPorts",
  { id => "net_port_id" },
);
__PACKAGE__->belongs_to(
  "net_vlan_id",
  "BrownCS::udb::Schema::NetVlans",
  { id => "net_vlan_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lRKyfGWeUJy+mA7U88XC7A


# You can replace this text with custom content, and it will be preserved on regeneration
1;
