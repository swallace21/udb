package BrownCS::udb::Schema::CompClasses;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("comp_classes");
__PACKAGE__->add_columns(
  "comp_class_id",
  {
    data_type => "integer",
    default_value => "nextval('comp_classes_comp_class_id_seq'::regclass)",
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
  "os_type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("comp_class_id");
__PACKAGE__->add_unique_constraint("comp_classes_pkey", ["comp_class_id"]);
__PACKAGE__->add_unique_constraint("comp_classes_name_key", ["name", "os_type"]);
__PACKAGE__->belongs_to(
  "os_type",
  "BrownCS::udb::Schema::OsTypes",
  { os_type => "os_type" },
);
__PACKAGE__->has_many(
  "comp_classes_computers",
  "BrownCS::udb::Schema::CompClassesComputers",
  { "foreign.comp_class_id" => "self.comp_class_id" },
);
__PACKAGE__->many_to_many(computers => 'comp_classes_computers', 'computer');


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-04-28 16:23:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IRAZE5F4aHjYklEUmOhPBA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
