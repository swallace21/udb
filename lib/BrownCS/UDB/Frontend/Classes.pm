package BrownCS::UDB::Frontend::Classes;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(classes);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  pod2usage({ -exitval => $exit_status, -verbose => 99, -sections => "SYNOPSIS|DESCRIPTION|OPTIONS"});
}

sub classes {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;
  if (@ARGV == 0) {
    usage(2);
  }

  my $hostname = shift @ARGV;
  my %host = $udb->get_host($hostname);
  print join(' ',@{$host{classes}}) . "\n";
}

1;
__END__

=head1 NAME

cdb-classes - Print out the classes a host belongs to

=head1 SYNOPSIS

cdb-classes [-u username] hostname

=head1 DESCRIPTION

cdb-classes queries the UDB database for the list of classes that a host
belongs to, and prints it out to the console. It is designed to resemble
the old I<cdb classes> command.

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

