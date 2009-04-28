package BrownCS::UDB::Edit;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(get_new_name get_new_user get_new_os get_new_location);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

use BrownCS::UDB::Util qw(:all);

sub get_new_name {
  my ($maybe) = @_;
  return get_new($maybe, "device name", \&verify_hostname);
}

sub get_new_user {
  my ($maybe) = @_;
  return get_new($maybe, "primary user or contact person", \&yes);
}

sub get_new_os {
  my ($maybe) = @_;
  return get_new($maybe, "OS type", \&yes);
}

sub get_new_location {
  my ($maybe) = @_;
  return get_new($maybe, "location", \&yes);
}

