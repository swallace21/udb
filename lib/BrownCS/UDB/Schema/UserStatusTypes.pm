package BrownCS::UDB::Schema::UserStatusTypes;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("user_status_types");
__PACKAGE__->add_columns(
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("name");
__PACKAGE__->add_unique_constraint("user_status_types_pkey", ["name"]);
__PACKAGE__->has_many(
  "peoples",
  "BrownCS::UDB::Schema::People",
  { "foreign.user_status" => "self.name" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-02 16:27:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ksa9cU2OA9FcErbwy5H6zw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
