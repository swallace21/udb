package BrownCS::udb::Schema;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_classes;

__PACKAGE__->connection(
  'dbi:Pg:dbname=udb;host=sysdb',
  'udbuser',
  '0=ckf5j/_es1ZsSh&I"$pXTp$9a2TG0y4!5t8K:hSzPZKzRN-S)6N+wa./CqIdrC',
);

sub do {
  my $self = shift;
  my ($sql, @args) = @_;
  $self->storage->dbh_do(
    sub {
      my ($storage, $dbh) = @_;
      $dbh->do($sql, @args);
    }
  );
}

1;
