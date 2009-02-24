package BrownCS::UDB::Frontend::Show;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(show);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

use BrownCS::UDB::Util qw(:all);

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  pod2usage({ -exitval => $exit_status, -verbose => 1});
}

sub sort_fieldnames {
  return -1 if($a eq 'hostname');
  return 1 if($b eq 'hostname');
  return $a cmp $b;
}

sub show {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;
  if (@ARGV == 0) {
    usage(2);
  }

  my $hostname = shift @ARGV;

  my %host = $udb->get_host($hostname);

  if (not %host) {
    print "No record for host $hostname.\n";
    exit(2);
  }

  print "\n";
  print fix_width("Hostname:", 19), $host{'hostname'}, "\n";
  print "\n";
  print fix_width("Owner:", 19), ($host{'contact'} or 'unknown'), "\n";
  print fix_width("Location:", 19), ($host{'room'} or 'unknown'), "\n";
  print "\n";
  print fix_width("Status:", 19), $host{'status'}, "\n";
  print fix_width("Managed by:", 19), $host{'managed_by'}, "\n";
  print fix_width("OS:", 19), $host{'os_type'}, "\n";
  print "\n";
  print fix_width("MAC address:", 19), $host{'ethernet'}, "\n";
  print fix_width("IP address:", 19), $host{'ip_addr'}, "\n";
  print "\n";
  print "Classes: \n";
  foreach my $class (sort @{$host{classes}}) {
    print "  - $class\n";
  }
}

1;
__END__

=head1 NAME

cdb-show - Print out a summary of a host

=head1 SYNOPSIS

cdb-show [-u username] hostname

=head1 DESCRIPTION

cdb-show queries the UDB database for information about a host, and
prints it out to the console. It is designed to resemble the old I<cdb
profile> command.

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

