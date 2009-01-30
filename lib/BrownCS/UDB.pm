package BrownCS::UDB;

use 5.010000;
use strict;
use warnings;

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);
use Term::ReadKey;
use Pod::Usage;

our $VERSION = '0.01';

my $dbh;

my %sths = ();

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %args = @_;
  my $self = {};

  $self->{'dbh'} = undef;
  $self->{'sths'} = ();

  bless($self, $class);
  return $self;
}

sub get_pass {
  print "Password: ";
  ReadMode 'noecho';
  my $password = ReadLine 0;
  chomp $password;
  ReadMode 'normal';
  print "\n";

  return $password;
}

sub start {
  my $self = shift;
  my ($username, $password) = @_;
  $dbh = DBI->connect("dbi:Pg:dbname=udb;host=db", $username, $password, {AutoCommit=>0, pg_errorlevel=>2}) or die "Couldn't connect to database: " . DBI->errstr;

  $sths{'all_ips_select'} = $dbh->prepare("select ipaddr from net_addresses");
  $sths{'all_equip_select'} = $dbh->prepare("select comments, contact, equip_status from equipment");
  $sths{'all_comps_select'} = $dbh->prepare("select hw_arch, os, pxelink from computers");
  $sths{'all_ethernet_select'} = $dbh->prepare("select ethernet from net_interfaces");
  $sths{'all_aliases_select'} = $dbh->prepare("select name from net_dns_entries");
  $sths{'all_classes_select'} = $dbh->prepare("select cc.class from comp_classes cc");
  
  $sths{'equip_select'} = $dbh->prepare("select e.comments, e.contact, e.equip_status from equipment e where e.equip_name = ?");
  
  $sths{'comp_select'} = $dbh->prepare("select c.hw_arch, c.os, c.pxelink from equipment e, computers c where e.equip_name = ? and c.equipment_id = e.id");
  
  $sths{'ethernet_select'} = $dbh->prepare("select ni.ethernet from equipment e, net_interfaces ni where e.equip_name = ? and e.id = ni.equipment_id");
  
  $sths{'ip_addr_select'} = $dbh->prepare("select na.ipaddr from equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.equip_name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id");
  
  $sths{'aliases_select'} = $dbh->prepare("select nde.name from net_dns_entries nde, equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.equip_name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id and na.id = nde.net_address_id");
  
  $sths{'classes_select'} = $dbh->prepare("select cc.class from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.equip_name = ? and e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id");
  
  $sths{'all_hosts_in_class_select'} = $dbh->prepare("select e.equip_name from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id and cc.class = ?");

}

sub all_ips {
  my $self = shift;
  my %ip_addrs = ();
  my $addr;

  $sths{'all_ips_select'}->execute;
  $sths{'all_ips_select'}->bind_columns(\$addr);

  while ($sths{'all_ips_select'}->fetch) {
    $ip_addrs{$addr} = 1;
  }

  return %ip_addrs;
}

sub all_hosts_in_class {
  my $self = shift;
  my %ip_addrs = ();
  my $addr;

  $sths{'all_hosts_in_class_select'}->execute;
  $sths{'all_hosts_in_class_select'}->bind_columns(\$addr);

  while ($sths{'all_hosts_in_class_select'}->fetch) {
    $ip_addrs{$addr} = 1;
  }

  return %ip_addrs;
}

sub finish {
  my $self = shift;
  foreach my $sth (values %sths) {
    $sth->finish;
  }

  if ($dbh) {
    $dbh->disconnect;
  }
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

BrownCS::UDB - Perl extension for blah blah blah

=head1 SYNOPSIS

  use BrownCS::UDB;

  init;

=head1 DESCRIPTION

Stub documentation for BrownCS::UDB, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.

=head1 AUTHOR

Aleks Bromfield, E<lt>aleks@cs.brown.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 Brown University. All rights reserved.

For now, this is "all rights reserved" since it is of no use outside
of the CS Department.  If you think of some use, let us know.

=cut
