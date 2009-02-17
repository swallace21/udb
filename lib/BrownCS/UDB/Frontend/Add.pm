package BrownCS::UDB::Frontend::Add;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(add);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);
use Data::Dumper;

use BrownCS::UDB;
use BrownCS::UDB::Util qw(ask_password ask confirm edit choose);
use BrownCS::UDB::DbBase::Comp qw($attrs);

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  pod2usage({ -exitval => $exit_status, -verbose => 99, -sections => "SYNOPSIS|DESCRIPTION|OPTIONS"});
}

sub add {
  my ($udb, $verbose, $dryrun, @ARGV) = @_;

  my $hostname;
  
  if (@ARGV > 1) {
    usage(2);
  } elsif (@ARGV > 0) {
    $hostname = shift;
  }
  
  my $comp_db = BrownCS::UDB::DbBase::Comp->new;
  
  my %comp = (
    "hostname" => $hostname,
    "status" => "deployed",
    "hw_arch" => "x86",
  );
  
  foreach my $attr (@{$comp_db->{attrs}}) {
    my $name = shift (@{$attr});
    my $type = shift (@{$attr});
    my $reqd = shift (@{$attr});
    my $full = shift (@{$attr});
    my $cmts = join(" ", @{(shift @{$attr})});
  
    next if ($reqd ne 'req');
  
    if ($type eq 'string') {
      $comp{$name} = &ask($cmts);
    } elsif ($type eq 'choice') {
      $comp{$name} = &choose($cmts, [
        {
          'key' => "1key",
          'name' => "1name",
          'desc' => "description of item 1",
        },
        {
          'key' => "2key",
          'name' => "2name",
          'desc' => "description of item 2",
        },
        {
          'key' => "3key",
          'name' => "3name",
          'desc' => "description of item 3",
        },
        ]);
    } elsif ($type eq 'list') {
      $comp{$name} = &ask($cmts);
    }
  }
  
  if ($verbose) {
    print Dumper(%comp);
  }
  
  die;
  
  my $comp = $comp_db->str2hash(&edit($comp_db->hash2str(\%comp)));
  
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

