package BrownCS::udb::Schema;

use strict;
use warnings;

use base 'DBIx::Class::Schema';
use YAML::Tiny;

my $cfgfile = "/sysvol/secure-cfg/browncs-udb.yml";
my $config_yaml = YAML::Tiny->read($cfgfile) || die "Can't open $cfgfile\n";
my $config = $config_yaml->[0];

__PACKAGE__->load_classes;

__PACKAGE__->connection(
  'dbi:Pg:dbname=udb;host=sysdb',
  $config->{user},
  $config->{pass},
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
