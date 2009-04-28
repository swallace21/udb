package BrownCS::UDB;
use Moose;

use Crypt::Simple;
use Data::Dumper;

use BrownCS::UDB::Util qw(:all);
use BrownCS::UDB::Schema;

has 'db' => (
  is => 'ro',
  isa => 'BrownCS::UDB::Schema'
);

has 'dbh' => (
  is => 'ro',
  isa => 'DBIx::Simple'
);

sub start {
  my $self = shift;
  my ($username) = @_;

  my $enc_password;
  my $password;
  my $filename = "/tmp/udb_cc.$username";
  if (-r $filename) {
    open(FH, $filename);
    $enc_password = <FH>;
    chomp $enc_password;
    $password = decrypt($enc_password);
    close(FH);
  }

  $self->{db} = BrownCS::UDB::Schema->clone;

  while ((!$self->db->storage) or (!($self->db->storage->connected))) {
    $self->db->connection("dbi:Pg:dbname=udb;host=sysdb", $username, $password);
    eval {
      $self->db->storage->ensure_connected;
    };
    if ($@) {
      $password = &ask_password;
      if (not $password) {
        exit(0);
      }
    } else {
      last;
    }
  }

  my $old_umask = umask(0077);
  $enc_password = encrypt($password);
  open(FH, ">$filename");
  print FH "$enc_password\n";
  close(FH);
  umask($old_umask);

}

sub do {
  my ($self, $sql, @args) = @_;
  $self->db->storage->dbh_do(
    sub {
      my ($storage, $dbh) = @_;
      $dbh->do($sql, @args);
    }
  );
}

sub get_host_class_map {
  my $self = shift;

  my $hash = {};

  my $rs = $self->db->resultset('CompClassesComputers')->search({},
    {
      prefetch => ['computer', 'comp_class'],
      include_columns => ['comp_class.name'],
    });

  while (my $item = $rs->next) {
    my $name = $item->computer->name;
    if (not defined @{$hash->{$name}}) {
      $hash->{$name} = [];
    }
    push @{$hash->{$name}}, $item->comp_class->name;
  }

  return $hash;

}

sub find_unused_ip {
  my $self = shift;
  my ($vlan) = @_;

  my($subnet) = new NetAddr::IP ($vlan->network);

  my(%ip_addrs) = ();

  # Build hash of used IP addresses to avoid

  my $all_ips = $self->db->resultset('NetAddresses');;

  while (my $ip = $all_ips->next) {
    if ($ip->ipaddr) {
      $ip_addrs{$ip->ipaddr} = 1;
    }
  }

  # Skip the broadcast, gateway, and network addresses
  $ip_addrs{$subnet->broadcast} = 1;
  $ip_addrs{$subnet->network} = 1;
  $ip_addrs{$vlan->gateway} = 1;

  my $ip_end = $subnet;
  my $ip_iterator = $ip_end;

  while ((++$ip_iterator) != $ip_end) {
    my $ip_addr_test = $ip_iterator->addr;
    next if(defined($ip_addrs{$ip_addr_test}));
    return $ip_addr_test;
  }

  die "No addresses are available for the $subnet subnet.\n";
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

BrownCS::UDB - the Universal DataBase

=head1 SYNOPSIS

  use BrownCS::UDB;

  my $udb = BrownCS::UDB->new;
  $udb->start($username);

  my @hosts = $udb->all_hosts_in_class($class, $os);
  # ...
 
  $udb->finish;

=head1 DESCRIPTION

The client database is a simple database of network clients which can be used
to automatically generate system-wide configuration files, such as NIS maps,
DNS zone files, and network boot information.  Each record in the database
corresponds to a network connection, i.e. a unique IP address.  In most cases,
each record also corresponds to a single machine connected to the network, but
this is not always the case.  A single logical machine may have multiple
network interfaces, and will therefore have multiple database entries.
Additionally, some network devices with names and IP addresses may not
correspond to a workstation; there may be entries for networked printers,
dialup multiplexors, and other devices.

=head1 AUTHOR

Aleks Bromfield, based on previous code by Mike Shapiro and Stephanie
Schaaf, among others.

=head1 SEE ALSO

B<psql>(1), B<perl>(1)

=head1 NOTES

The current version of UDB assumes that there is a database 'udb' on a
postgres server called 'sysdb'. Future versions will be more flexible.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 Brown University. All rights reserved.

For now, this is "all rights reserved" since it is of no use outside
of the CS Department.  If you think of some use, let us know.

=cut
