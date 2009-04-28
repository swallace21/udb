package BrownCS::udb::Schema::CompClasses;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("comp_classes");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    default_value => "nextval('comp_classes_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "os_type_id",
  { data_type => "integer", default_value => undef, is_nullable => 1, size => 4 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("comp_classes_pkey", ["id"]);
__PACKAGE__->add_unique_constraint("comp_classes_name_key", ["name", "os_type_id"]);
__PACKAGE__->belongs_to(
  "os_type_id",
  "BrownCS::udb::Schema::OsTypes",
  { id => "os_type_id" },
);
__PACKAGE__->has_many(
  "comp_classes_computers",
  "BrownCS::udb::Schema::CompClassesComputers",
  { "foreign.comp_class_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 14:00:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rrKVHnb1PbvYmVMPKwQIJg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
