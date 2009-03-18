package BrownCS::UDB::Verify;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(verify_hostname verify_mac);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);
use Net::MAC;

use BrownCS::UDB::Util qw(:all);

# TODO: check that value is not in use

sub verify_hostname {
  my($value) = @_;

  if($value !~ /^[a-zA-Z]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$/) {
    warn "Invalid hostname.\n";
    return 0;
  }

  return 1;
}

sub verify_mac {
  my ($mac_str) = @_;
  my $mac = Net::MAC->new('mac' => $mac_str, 'die' => 0);
  if (not $mac) {
    warn "Invalid MAC address.\n";
    return 0;
  } else {
    return 1;
  }
}

