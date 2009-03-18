package BrownCS::UDB::View;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(filter_record);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

use BrownCS::UDB::Util qw(:all);

my $fields = {
  'room' => {
    'desc' => "Room",
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
  'ipaddr' => {
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
    'desc' => "Number of CPUs (reported)",
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
    'desc' => "Ports",
    'views' => ['net'],
  },
  'num_blades' => {
    'desc' => "Blades",
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
    'desc' => "Port number",
    'views' => ['net'],
  },
  'blade_num' => {
    'desc' => "Blade number",
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
  'place' => {
    'desc' => "Location",
    'views' => ['admin'],
  },
  'equip' => {
    'desc' => "Equipment info",
    'views' => ['admin'],
  },
  'comp' => {
    'desc' => "Computer info",
    'views' => ['admin'],
  },
  'comments' => {
    'desc' => "Comments",
    'views' => ['admin'],
  },
};

sub filter_record {
  my ($view, $old) = @_;

  if ((ref($old) eq "ARRAY")) {

    if (scalar(@{$old}) > 0) {
      my @new = map { filter_record($view, $_) } @{$old};
      return \@new;
    } else {
      return ();
    }

  } elsif ((ref($old) eq "HASH")) {

    my $new = {};

    foreach my $key (sort(keys %{$old})) {

      my $views_ref = $fields->{$key}->{views};
      next if (($view ne 'all') and not (grep { $_ =~ /^$view$/ } @{$views_ref}));

      my $val = $old->{$key};
      next if not defined $val;

      my $new_key = $fields->{$key}->{desc};
      next if not defined $new_key;

      my $new_val = filter_record($view, $val);
      next if not defined $new_val;

      $new->{$new_key} = $new_val;

    }

    return $new;

  } else {

    return $old;

  }

}

