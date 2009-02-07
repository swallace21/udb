package BrownCS::UDB::Frontend::Mod;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(mod);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

use BrownCS::UDB::DbBase::Comp;

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  pod2usage({ -exitval => $exit_status, -verbose => 99, -sections => "SYNOPSIS|DESCRIPTION|OPTIONS"});
}

sub mod {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;
  if (@ARGV == 0) {
    usage(2);
  }

  my $hostname = shift @ARGV;

  my $comp_db = BrownCS::UDB::DbBase::Comp->new;
  my %old_comp = $udb->get_host($hostname);
  my $comp = $comp_db->str2hash(&edit($comp_db->hash2str(\%old_comp)));

  if ($verbose) {
    print Dumper(%$comp);
  }
}

1;
__END__

=head1 NAME

cdb-add - Add a host to UDB

=head1 SYNOPSIS

cdb-add [-u username] hostname

=head1 DESCRIPTION

adds one or more hosts to the database

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

