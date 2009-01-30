package BrownCS::UDB;

use 5.010000;
use strict;
use warnings;

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);
use Term::ReadKey;
use Pod::Usage;
use Data::Dumper;

our $PNAME = 'UDB';
our $VERSION = '0.01';

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %args = @_;
  my $self = {};

  $self->{dbh} = undef;
  $self->{sths} = ();

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
  $self->{dbh} = DBI->connect("dbi:Pg:dbname=udb;host=db", $username, $password, {AutoCommit=>0, pg_errorlevel=>2}) or die "Couldn't connect to database: " . DBI->errstr;

  $self->{sths}->{all_ips_select} = $self->{dbh}->prepare("select ipaddr from net_addresses");
  $self->{sths}->{all_equip_select} = $self->{dbh}->prepare("select comments, contact, equip_status from equipment");
  $self->{sths}->{all_comps_select} = $self->{dbh}->prepare("select hw_arch, os, pxelink from computers");
  $self->{sths}->{all_ethernet_select} = $self->{dbh}->prepare("select ethernet from net_interfaces");
  $self->{sths}->{all_aliases_select} = $self->{dbh}->prepare("select name from net_dns_entries");
  $self->{sths}->{all_classes_select} = $self->{dbh}->prepare("select cc.class from comp_classes cc");
  
  $self->{sths}->{equip_select} = $self->{dbh}->prepare("select e.comments, e.contact, e.equip_status from equipment e where e.equip_name = ?");
  
  $self->{sths}->{comp_select} = $self->{dbh}->prepare("select c.hw_arch, c.os, c.pxelink, c.comments from equipment e, computers c where e.equip_name = ? and c.equipment_id = e.id");
  
  $self->{sths}->{ethernet_select} = $self->{dbh}->prepare("select ni.ethernet from equipment e, net_interfaces ni where e.equip_name = ? and e.id = ni.equipment_id");
  
  $self->{sths}->{ip_addr_select} = $self->{dbh}->prepare("select na.ipaddr from equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.equip_name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id");
  
  $self->{sths}->{aliases_select} = $self->{dbh}->prepare("select nde.name from net_dns_entries nde, equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.equip_name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id and na.id = nde.net_address_id");
  
  $self->{sths}->{classes_select} = $self->{dbh}->prepare("select cc.class from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.equip_name = ? and e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id");
  
  $self->{sths}->{all_hosts_in_class_select} = $self->{dbh}->prepare("select e.equip_name from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id and cc.class = ?");

}

sub all_ips {
  my $self = shift;
  my %ip_addrs = ();
  my $addr;

  $self->{sths}->{all_ips_select}->execute;
  $self->{sths}->{all_ips_select}->bind_columns(\$addr);

  while ($self->{sths}->{all_ips_select}->fetch) {
    $ip_addrs{$addr} = 1;
  }

  return %ip_addrs;
}

sub all_hosts_in_class {
  my $self = shift;
  my ($class) = @_;
  my @hosts_in_class = ();
  my $host;

  $self->{sths}->{all_hosts_in_class_select}->execute($class);
  $self->{sths}->{all_hosts_in_class_select}->bind_columns(\$host);
  
  while ($self->{sths}->{all_hosts_in_class_select}->fetch) {
    push @hosts_in_class, $host;
  }

  return @hosts_in_class;
}

sub host {
  my $self = shift;
  my ($hostname) = @_;
  my %host = ();

  $host{hostname} = $hostname;
  $host{mxhost} = "mx.cs.brown.edu";

  $self->{sths}->{equip_select}->execute($hostname);
  die "No record for host $hostname\n" if ($self->{sths}->{equip_select}->rows == 0);
  $self->{sths}->{equip_select}->bind_columns(\$host{comment}, \$host{contact}, \$host{status});
  $self->{sths}->{equip_select}->fetch;

  $self->{sths}->{comp_select}->execute($hostname);
  $self->{sths}->{comp_select}->bind_columns(\$host{hw_arch}, \$host{os_type}, \$host{pxelink}, \$host{host_comments});
  $self->{sths}->{comp_select}->fetch;

  $self->{sths}->{ethernet_select}->execute($hostname);
  $self->{sths}->{ethernet_select}->bind_columns(\$host{ethernet});
  $self->{sths}->{ethernet_select}->fetch;

  $self->{sths}->{ip_addr_select}->execute($hostname);
  $self->{sths}->{ip_addr_select}->bind_columns(\$host{ip_addr});
  $self->{sths}->{ip_addr_select}->fetch;

  $host{aliases} = [];
  my $alias;
  $self->{sths}->{aliases_select}->execute($hostname);
  $self->{sths}->{aliases_select}->bind_columns(\$alias);
  while ($self->{sths}->{aliases_select}->fetch) {
    if ($alias ne $hostname) {
      push @{$host{aliases}}, $alias;
    }
  }

  $host{classes} = [];
  my $class;
  $self->{sths}->{classes_select}->execute($hostname);
  $self->{sths}->{classes_select}->bind_columns(\$class);
  while ($self->{sths}->{classes_select}->fetch) {
    if ($class ne $hostname) {
      push @{$host{classes}}, $class;
    }
  }

  return %host;
}

sub finish {
  my $self = shift;
  foreach my $sth (values %{$self->{sths}}) {
    $sth->finish;
  }

  if ($self->{dbh}) {
    $self->{dbh}->disconnect;
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
