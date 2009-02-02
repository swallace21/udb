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

#
# static methods
#

# get_pass :: void -> string
# Prompt the user for a password and return it.
sub get_pass {
  print "Password: ";
  ReadMode 'noecho';
  my $password = ReadLine 0;
  chomp $password;
  ReadMode 'normal';
  print "\n";

  return $password;
}

# ynquery :: string -> boolean
# Prompt the user for yes or no and return appropriate value.
sub ynquery {
  my($prompt) = @_;
  my($answer);

  printflush('STDOUT', $prompt);
  chop($answer = <STDIN>);
  return ($answer eq '') || ($answer eq 'Y') || ($answer eq 'y');
}

#
# object methods
#

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

sub prepare {
  my $self = shift;
  my ($name, $st) = @_;
  if (not $self->{sths}->{$name}) {
    $self->{sths}->{$name} = $self->{dbh}->prepare($st);
  }
}

sub start {
  my $self = shift;
  my ($username, $password) = @_;
  $self->{dbh} = DBI->connect("dbi:Pg:dbname=udb;host=db", $username, $password, {AutoCommit=>0, pg_errorlevel=>2}) or die "Couldn't connect to database: " . DBI->errstr;

  $self->prepare("all_aliases_select", "select name from net_dns_entries");
  $self->prepare("all_classes_select", "select cc.class from comp_classes cc");
  $self->prepare("all_comps_select", "select hw_arch, os, pxelink from computers");
  $self->prepare("all_equip_select", "select comments, contact, equip_status from equipment");
  $self->prepare("all_ethernet_select", "select ethernet from net_interfaces");
  $self->prepare("all_ips_select", "select ipaddr from net_addresses");
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

  $self->prepare("all_hosts_in_class_select", "select e.equip_name from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id and cc.class = ?");

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

  $self->prepare("aliases_select", "select nde.name from net_dns_entries nde, equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.equip_name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id and na.id = nde.net_address_id");
  $self->prepare("classes_select", "select cc.class from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.equip_name = ? and e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id");
  $self->prepare("comp_select", "select c.hw_arch, c.os, c.pxelink, c.comments from equipment e, computers c where e.equip_name = ? and c.equipment_id = e.id");
  $self->prepare("equip_select", "select e.comments, e.contact, e.equip_status from equipment e where e.equip_name = ?");
  $self->prepare("ethernet_select", "select ni.ethernet from equipment e, net_interfaces ni where e.equip_name = ? and e.id = ni.equipment_id");
  $self->prepare("ip_addr_select", "select na.ipaddr from equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.equip_name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id");

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

sub get_class {
  my $self = shift;
  my ($class) = @_;
  my $class_id;

  $self->prepare("class_insert", "insert into comp_classes (class) values (?) returning id");
  $self->prepare("class_select", "select id from comp_classes where class = ?");

  $self->{sths}->{class_select}->execute($class);

  if ($self->{sths}->{class_select}->rows == 0) {
    $self->{sths}->{class_insert}->execute($_);
    $class_id = $self->{sths}->{class_insert}->fetch()->[0];
  } else {
    $class_id = $self->{sths}->{class_select}->fetchrow_arrayref()->[0];
  }

  return $class_id;
}

sub get_vlan {
  my $self = shift;
  my ($ip) = @_;

  $self->prepare("vlan_select", "select id from net_vlans v where ? << v.network");

  $self->{sths}->{vlan_select}->execute($ip);

  my $vlan_id;

  if ($self->{sths}->{vlan_select}->rows == 0) {
    die "Can't find vlan for $ip!\n";
  } else {
    $vlan_id = $self->{sths}->{vlan_select}->fetchrow_arrayref()->[0];
  }

  return $vlan_id;
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
