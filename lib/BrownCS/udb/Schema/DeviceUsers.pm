package BrownCS::udb::Schema::DeviceUsers;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("device_users");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('device_users_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "device_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "person_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("device_users_pkey", ["id"]);
__PACKAGE__->belongs_to(
  "device_id",
  "BrownCS::udb::Schema::Devices",
  { id => "device_id" },
);
__PACKAGE__->belongs_to(
  "person_id",
  "BrownCS::udb::Schema::People",
  { id => "person_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1zq3jgXdRXwgT/3tRW80sQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
