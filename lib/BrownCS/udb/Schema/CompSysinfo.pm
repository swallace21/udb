package BrownCS::udb::Schema::CompSysinfo;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("comp_sysinfo");
__PACKAGE__->add_columns(
  "device_name"  => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "num_cpus"     => { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
  "cpu_type"     => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "cpu_speed"    => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "memory"       => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "hard_drives"  => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "video_cards"  => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
  "last_updated" => { data_type => "timestamp without time zone", default_value => "now()", is_nullable => 0, size => 8, },
);
__PACKAGE__->set_primary_key("device_name");
__PACKAGE__->add_unique_constraint("comp_sysinfo_pkey", ["device_name"]);
__PACKAGE__->belongs_to(
  "device",
  "BrownCS::udb::Schema::Devices",
  { device_name => "device_name" },
);

1;

