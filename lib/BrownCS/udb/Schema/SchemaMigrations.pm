package BrownCS::udb::Schema::SchemaMigrations;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("schema_migrations");
__PACKAGE__->add_columns(
  "version",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 255,
  },
);
__PACKAGE__->add_unique_constraint("unique_schema_migrations", ["version"]);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TStuRrj3b/acp6AOCU6cng


# You can replace this text with custom content, and it will be preserved on regeneration
1;
