package BrownCS::UDB::Schema::CompClasses;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("comp_classes");
__PACKAGE__->add_columns(
  "id"   => { data_type => "integer", default_value => "nextval('comp_classes_id_seq'::regclass)", is_nullable => 0, size => 4, },
  "name" => { data_type => "text", default_value => undef, is_nullable => 0, size => undef, },
  "os"   => { data_type => "text", default_value => undef, is_nullable => 1, size => undef, },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("comp_classes_pkey", ["id"]);
__PACKAGE__->add_unique_constraint("comp_classes_name_key", ["name", "os"]);
__PACKAGE__->belongs_to("os", "BrownCS::UDB::Schema::OsTypes", { name => "os" });
__PACKAGE__->has_many("comp_classes_computers", "BrownCS::UDB::Schema::CompClassesComputers", { "foreign.comp_class" => "self.id" });
__PACKAGE__->many_to_many('computers' => 'comp_classes_computers', 'computer');

1;
