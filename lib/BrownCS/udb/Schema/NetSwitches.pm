package BrownCS::udb::Schema::NetSwitches;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("net_switches");
__PACKAGE__->add_columns(
  "device_name"     => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "fqdn"            => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "num_ports"       => { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "num_blades"      => { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "switch_type"     => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "connection_type" => { data_type => "text", default_value => "'ssh'::text", is_nullable => 0, size => undef, },
  "username"        => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "pass"            => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
);
__PACKAGE__->set_primary_key("device_name");
__PACKAGE__->add_unique_constraint("net_switches_pkey", ["device_name"]);
__PACKAGE__->has_many(
  "net_ports",
  "BrownCS::udb::Schema::NetPorts",
  { "foreign.switch_name" => "self.device_name" },
  {
    cascade_delete => 0,
  }
);
__PACKAGE__->belongs_to(
  "device",
  "BrownCS::udb::Schema::Devices",
  { device_name => "device_name" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:w1sfEkDmP/p0Y5k0+hSxyA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
