package BrownCS::UDB::Frontend::Del;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(del);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  pod2usage({ -exitval => $exit_status, -verbose => 1});
}

sub del {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;
  if (@ARGV == 0) {
    usage(2);
  }

  my $hostname = shift @ARGV;
  $udb->{dbh}->do(q{delete from equipment where name = ?}, undef, $hostname);
}

1;
__END__

=head1 NAME

cdb-del - delete a host from UDB

=head1 SYNOPSIS

cdb-del [-u username] hostname

=head1 DESCRIPTION

deletes one or more hosts from the database

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

