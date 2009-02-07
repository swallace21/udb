package BrownCS::UDB::Frontend::ClassAdd;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(class_add);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  pod2usage({ -exitval => $exit_status, -verbose => 99, -sections => "SYNOPSIS|DESCRIPTION|OPTIONS"});
}

sub class_add {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;

  if (@ARGV == 0) {
    usage(2);
  }

  my $class = shift @ARGV;
  my @hostnames = @ARGV;

  $udb->prepare("class_comp_insert", "INSERT INTO comp_classes_computers (comp_classes_id, computers_id) VALUES (?,?)");
  $udb->{sths}->{class_comp_insert}->bind_param(1, undef, SQL_INTEGER);
  $udb->{sths}->{class_comp_insert}->bind_param(2, undef, SQL_INTEGER);
  
  my $class_id = $udb->get_class($class);
  
  foreach my $hostname (@hostnames) {
    if ($verbose) {
      print "adding host $hostname to class $class\n";
    }
    my %host = $udb->get_host($hostname);
    $udb->{sths}->{class_comp_insert}->execute($class_id, $host{comp_id});
  }

}

1;

__END__

=head1 NAME

cdb-class-add - Add one or more hosts to a class

=head1 SYNOPSIS

cdb-class-add [-u username] classname hostname [hostname ...]

=head1 DESCRIPTION

adds one or more hosts to a class

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

