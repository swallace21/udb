package BrownCS::UDB::View;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(print_record);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

use BrownCS::UDB::Util qw(:all);

sub udb_sort {
  return -1 if ($a eq 'Name');
  return 1 if ($b eq 'Name');
  return 1 if ($a eq 'Comments');
  return -1 if ($b eq 'Comments');
  return $a cmp $b;
}

sub print_record {
  my ($prefix, $hash) = @_;

  foreach my $key (sort udb_sort (keys(%{$hash}))) {
    my $val = $hash->{$key};
    next if not defined $val;
    if ((ref($val) eq "ARRAY")) {
      if (scalar(@{$val}) > 0) {
        print $prefix, $key, ":\n";
        print_array(($prefix."  "), $val);
      }
    } elsif ((ref($val) eq "HASH")) {
      print $prefix, $key, ":\n";
      print_record(($prefix."  "), $val);
    } elsif ($val) {
      printf "%s%s: %s\n", $prefix, $key, $val;
    }
  }
}

sub print_array {
  my ($prefix, $array) = @_;

  foreach my $item (sort @{$array}) {

    next if not defined $item;

    if ((ref($item) eq "ARRAY")) {
      print "$prefix-\n";
      print_array(($prefix."- "), $item);
    } elsif ((ref($item) eq "HASH")) {
      print "$prefix-\n";
      print_record(($prefix."  "), $item);
    } elsif ($item) {
      printf "%s- %s\n", $prefix, $item;
    }
  }

}

