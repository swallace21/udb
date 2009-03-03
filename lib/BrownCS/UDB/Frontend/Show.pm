package BrownCS::UDB::Frontend::Show;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(show);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

use BrownCS::UDB::Util qw(:all);

my $field_names = {
  'name'       => "Name",
  'room'       => "Location",
  'contact'    => "Primary user",
  'status'     => "Status",
  'managed_by' => "Managed by",
  'os_type'    => "OS",      
  'ethernet'   => "MAC address",
  'ip_addr'    => "IP address",
  'classes'    => "Classes", 
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
        printf "%-18s %s\n", ($field_names->{$name} . ':'), '---';
      } else {
        print $field_names->{$name}, ":\n";
        foreach my $item (sort @{$val}) {
          print "  - $item\n";
        }
      }
    } else {
      printf "%-18s %s\n", ($field_names->{$name} . ':'), $host->{$name};
    }
  }
}

sub show {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;
  if (@ARGV == 0) {
    usage(2);
  }

  my $name = shift @ARGV;

  my %host = $udb->get_equip($name);

  if (not %host) {
    print "No record for device $name.\n";
    exit(2);
  }

  print_field(\%host, 'name');
  print_field(\%host, 'room');
  print_field(\%host, 'contact');
  print_field(\%host, 'status');
  print_field(\%host, 'managed_by');
  print_field(\%host, 'os_type');
  print_field(\%host, 'ethernet');
  print_field(\%host, 'ip_addr');
  print_field(\%host, 'classes');
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

