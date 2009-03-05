package BrownCS::UDB::Frontend::Show;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(show);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

use BrownCS::UDB::Util qw(:all);

my $fields = {
  'name' => {
    'desc' => "Name",
    'views' => [],
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
  'ethernet' => {
    'desc' => "MAC address",
    'views' => ['hw', 'net'],
  },
  'ip_addr' => {
    'desc' => "IP address",
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
};

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  pod2usage({ -exitval => $exit_status, -verbose => 1});
}

sub print_field {
  my ($host, $name) = @_;
  my $val = $host->{$name};
  if (defined $val) {
    if ((ref($val) eq "ARRAY")) {
      if (scalar(@$val) == 0) {
        printf "%-18s %s\n", ($fields->{$name}->{desc} . ':'), '---';
      } else {
        print $fields->{$name}->{desc}, ":\n";
        foreach my $item (sort @{$val}) {
          print "  - $item\n";
        }
      }
    } else {
      printf "%-18s %s\n", ($fields->{$name}->{desc} . ':'), $host->{$name};
    }
  }
}

sub show {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;
  if (@ARGV != 2) {
    usage(2);
  }

  my $view = shift @ARGV;
  my $name = shift @ARGV;

  my %host = $udb->get_equip($name);

  if (not %host) {
    print "No record for device $name.\n";
    exit(2);
  }

  print_field(\%host, 'name');

  foreach my $field (sort (keys %{$fields})) {
    my $views_ref = $fields->{$field}->{views};
    if (($view eq 'all') or (grep { $_ =~ /^$view$/ } @{$views_ref})) {
      print_field(\%host, $field);
    }
  }
}

1;
__END__

=head1 NAME

cdb-show - Print out information about a piece of equipment

=head1 SYNOPSIS

cdb-show [-u username] name

=head1 DESCRIPTION

cdb-show queries the UDB database for information about a piece of
equipment, and prints it out to the console. It is designed to resemble
the old I<cdb profile> or I<index pc> commands.

=head1 OPTIONS

=over

=item B<-h>, B<--help>

Print a help message and exit.

=item B<-u>, B<--username>=user

Logs onto the database server as the specified username, instead of as
the current user.

=back

=head1 AUTHORS

Aleks Bromfield.

=head1 SEE ALSO

B<udb>

=cut

