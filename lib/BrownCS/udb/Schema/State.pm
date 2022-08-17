package BrownCS::udb::Schema::State;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("state");
__PACKAGE__->add_columns(
  "key",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "value",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => 4,
  },
);
__PACKAGE__->set_primary_key("key");
__PACKAGE__->add_unique_constraint("state_pkey", ["key"]);

1;
