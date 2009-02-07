package BrownCS::UDB::Frontend::ClassDel;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(class_del);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  pod2usage({ -exitval => $exit_status, -verbose => 99, -sections => "SYNOPSIS|DESCRIPTION|OPTIONS"});
}

sub class_del {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;

  if (@ARGV == 0) {
    usage(2);
  }

  my $class = shift @ARGV;
  my @hostnames = @ARGV;

  $udb->prepare("class_comp_delete", "delete from comp_classes_computers ccc using comp_classes cc, computers c where ccc.comp_classes_id = cc.id and ccc.computers_id = c.id and cc.class = ? and c.machine_name = ?");

  foreach my $hostname (@hostnames) {
    if ($verbose) {
      print "removing host $hostname from class $class\n";
    }
    $udb->{sths}->{class_comp_delete}->execute($class, $hostname);
  }

}

1;
__END__

=head1 NAME

cdb-class-del - Delete one or more hosts from a class

=head1 SYNOPSIS

cdb-class-del [-u username] classname hostname [hostname ...]

=head1 DESCRIPTION

deletes one or more hosts from a class

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

