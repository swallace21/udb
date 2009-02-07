package BrownCS::UDB::Frontend::ContactList;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(contact_list);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  pod2usage({ -exitval => $exit_status, -verbose => 99, -sections => "SYNOPSIS|DESCRIPTION|OPTIONS"});
}

sub contact_list {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;

  if (@ARGV == 0) {
    usage(2);
  }

  my $class = shift @ARGV;
  my @hostnames = @ARGV;

  printf "%-15s%-40s%-10s\n\n", "MACHINE", "SERVICES", "CONTACTS";

  my @hosts = $udb->all_hosts_in_class($class);

  foreach my $hostname (@hosts) {
    my %host = $udb->get_host($hostname);
    my $contact = ($host{contact} or '');
    printf "%-15s%-40s%-10s\n", $hostname, "who knows", $contact;
  }

}

1;
__END__

=head1 NAME

cdb-contact-list - Print out a contact list for all hosts in a class

=head1 SYNOPSIS

cdb-contact-list [-u username] classname

=head1 DESCRIPTION

cdb-contact-list queries the UDB database for all hosts in a class, and
prints out a contact list which is designed to be posted in the machine
rooms. It is designed to resemble the old I<contact-list> command.

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

