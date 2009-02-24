package BrownCS::UDB::Frontend::ClassShow;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(class_show);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  pod2usage({ -exitval => $exit_status, -verbose => 1});
}

sub class_show {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;
  if (@ARGV == 0) {
    usage(2);
  }

  my $class = shift @ARGV;
  my @hosts = $udb->all_hosts_in_class($class);
  print join(" ", @hosts) . "\n";
}

1;
__END__

=head1 NAME

cdb-class-show - Print out a list of all hosts in a class

=head1 SYNOPSIS

cdb-class-show [-u username] class

=head1 DESCRIPTION

cdb-class-show queries the UDB database for all members of a given host
class. It is designed to resemble the old I<cdb classlist> command.

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

