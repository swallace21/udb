package BrownCS::UDB::View;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(print_record);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

use BrownCS::UDB::Util qw(:all);

my $fields = {
  'name' => {
    'desc' => "Name",
    'views' => ['hostname'],
  },
  'room' => {
    'desc' => "Location",
    'views' => ['admin'],
  },
  'contact' => {
    'desc' => "Primary user",
    'views' => ['admin'],
  },
  'status' => {
    'desc' => "Status",
    'views' => ['admin'],
  },
  'managed_by' => {
    'desc' => "Managed by",
    'views' => ['admin'],
  },
  'interfaces' => {
    'desc' => "Network interfaces",
    'views' => ['hw', 'net'],
  },
  'ethernet' => {
    'desc' => "MAC address",
    'views' => ['hw', 'net'],
  },
  'ip_addr' => {
    'desc' => "IP address(es)",
    'views' => ['sw', 'net'],
  },
  'classes' => {
    'desc' => "Classes",
    'views' => ['sw'],
  },
  'os_type' => {
    'desc' => "OS",
    'views' => ['sw'],
  },
  'pxelink' => {
    'desc' => "PXE link",
    'views' => ['sw'],
  },
  'system_model' => {
    'desc' => "System model (reported)",
    'views' => ['hw'],
  },
  'num_cpus' => {
    'desc' => "# of CPUs (reported)",
    'views' => ['hw'],
  },
  'cpu_type' => {
    'desc' => "CPU type (reported)",
    'views' => ['hw'],
  },
  'cpu_speed' => {
    'desc' => "CPU speed (reported)",
    'views' => ['hw'],
  },
  'memory' => {
    'desc' => "Memory (reported)",
    'views' => ['hw'],
  },
  'hard_drives' => {
    'desc' => "Hard drives (reported)",
    'views' => ['hw'],
  },
  'total_disk' => {
    'desc' => "Total disk (reported)",
    'views' => ['hw'],
  },
  'other_drives' => {
    'desc' => "Other drives (reported)",
    'views' => ['hw'],
  },
  'network_cards' => {
    'desc' => "Network cards (reported)",
    'views' => ['hw'],
  },
  'video_cards' => {
    'desc' => "Video cards (reported)",
    'views' => ['hw'],
  },
  'os_name' => {
    'desc' => "OS name (reported)",
    'views' => ['sw'],
  },
  'os_name' => {
    'desc' => "OS version (reported)",
    'views' => ['sw'],
  },
  'os_name' => {
    'desc' => "OS dist (reported)",
    'views' => ['sw'],
  },
  'info_time' => {
    'desc' => "Last report time",
    'views' => ['sw', 'hw'],
  },
  'boot_time' => {
    'desc' => "Last boot time (reported)",
    'views' => ['sw', 'hw'],
  },
  'fqdn' => {
    'desc' => "Domain name",
    'views' => ['net'],
  },
  'num_ports' => {
    'desc' => "# of ports",
    'views' => ['net'],
  },
  'num_blades' => {
    'desc' => "# of blades",
    'views' => ['net'],
  },
  'switch_type' => {
    'desc' => "Switch type",
    'views' => ['net'],
  },
  'port_prefix' => {
    'desc' => "Port prefix",
    'views' => ['net'],
  },
  'connection' => {
    'desc' => "Connection type",
    'views' => ['net'],
  },
  'username' => {
    'desc' => "Username",
    'views' => [],
  },
  'pass' => {
    'desc' => "Password",
    'views' => [],
  },
  'switch' => {
    'desc' => "Switch",
    'views' => ['net'],
  },
  'port_num' => {
    'desc' => "Port #",
    'views' => ['net'],
  },
  'blade_num' => {
    'desc' => "Blade #",
    'views' => ['net'],
  },
  'wall_plate' => {
    'desc' => "Wall plate",
    'views' => ['net'],
  },
  'services' => {
    'desc' => "Services",
    'views' => ['sw'],
  },
};

sub print_record {
  my ($view, $prefix, $hash) = @_;

  foreach my $key (sort(keys %{$hash})) {

    my $views_ref = $fields->{$key}->{views};
    my $val = $hash->{$key};

    next if (($view ne 'all') and not (grep { $_ =~ /^$view$/ } @{$views_ref}));
    next if not defined $val;

    if ((ref($val) eq "ARRAY")) {
      if (%{$fields->{$key}} and (scalar(@{$val}) > 0)) {
        print $prefix, $fields->{$key}->{desc}, ":\n";
        print_array($view, ($prefix."  "), $val);
      }
    } elsif ((ref($val) eq "HASH")) {
      print_record($view, ($prefix."  "), $val);
    } else {
      if (%{$fields->{$key}}) {
        printf "%s%s: %s\n", $prefix, $fields->{$key}->{desc}, $val;
      }
    }
  }

}

sub print_array {
  my ($view, $prefix, $array) = @_;

  my $end_list;

  foreach my $item (sort @{$array}) {

    next if not defined $item;

    if ((ref($item) eq "ARRAY")) {
      $end_list = 1;
      print "$prefix--\n";
      print_array($view, ($prefix."| "), $item);
    } elsif ((ref($item) eq "HASH")) {
      $end_list = 1;
      print "$prefix--\n";
      print_record($view, ($prefix."| "), $item);
    } else {
      printf "%s- %s\n", $prefix, $item;
    }
  }

  if ($end_list) {
    print "$prefix--\n";
  }

}

