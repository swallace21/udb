package BrownCS::udb::Schema::UserStatusTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("user_status_types");
__PACKAGE__->add_columns(
  "user_status_type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("user_status_type");
__PACKAGE__->add_unique_constraint("user_status_types_pkey", ["user_status_type"]);
__PACKAGE__->has_many(
  "people",
  "BrownCS::udb::Schema::People",
  { "foreign.status" => "self.user_status_type" },
  {
    cascade_delete => 0,
  }
);

1;
