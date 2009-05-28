package BrownCS::udb::Schema::DeviceUsers;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("device_users");
__PACKAGE__->add_columns(
  "device_name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "person_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("device_name", "person_id");
__PACKAGE__->add_unique_constraint("device_users_pkey", ["device_name", "person_id"]);
__PACKAGE__->belongs_to(
  "device",
  "BrownCS::udb::Schema::Devices",
  { device_name => "device_name" },
);
__PACKAGE__->belongs_to(
  "person",
  "BrownCS::udb::Schema::People",
  { person_id => "person_id" },
);

1;
