package BrownCS::UDB;

use 5.010000;
use strict;
use warnings;

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);
use Term::ReadKey;
use Term::ReadLine;
use Pod::Usage;

our $PNAME = 'UDB';
our $VERSION = '0.01';

my $term = new Term::ReadLine 'udb';
$term->ornaments(0);

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
  my($prompt, $default) = @_;
  while (1) {
    my $answer = $term->readline($prompt);
    if ($answer eq '') {
      return $default;
    } elsif ($answer =~ /^y(es)?$/i) {
      return 1;
    } elsif ($answer =~ /^n(o)?$/i) {
      return 0;
    } else {
      print "Invalid answer. Please answer yes or no (y/n).\n"
    }
  }
}

# textquery :: string -> string
# Gets a line from the user.
sub textquery {
  my($prompt, $default) = @_;
  while (1) {
    my $answer = $term->readline($prompt);
    if (($answer eq '') and $default) {
      return $default;
    } elsif ($answer ne '') {
      return $answer;
    } else {
      print "Invalid answer. Please enter a non-empty string.\n"
    }
  }
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
  $self->prepare("all_equip_select", "select contact, equip_status from equipment");
  $self->prepare("all_ethernet_select", "select ethernet from net_interfaces");
  $self->prepare("all_ips_select", "select ipaddr from net_addresses");

  #$self->{dbh}->trace(1);
}

sub get_all_ips {
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

  $self->prepare("all_hosts_in_class_select", "select e.name from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id and cc.class = ?");

  $self->{sths}->{all_hosts_in_class_select}->execute($class);
  $self->{sths}->{all_hosts_in_class_select}->bind_columns(\$host);
  
  while ($self->{sths}->{all_hosts_in_class_select}->fetch) {
    push @hosts_in_class, $host;
  }

  return @hosts_in_class;
}

sub get_host {
  my $self = shift;
  my ($hostname) = @_;
  my %host = ();

  $self->prepare("aliases_select", "select nde.name from net_dns_entries nde, equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id and na.id = nde.net_address_id");
  $self->prepare("classes_select", "select cc.class from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.name = ? and e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id");
  $self->prepare("comp_select", "select c.id, c.hw_arch, c.os, c.pxelink from equipment e, computers c where e.name = ? and c.equipment_id = e.id");
  $self->prepare("equip_select", "select e.id, e.contact, e.equip_status from equipment e where e.name = ?");
  $self->prepare("ethernet_select", "select ni.ethernet from equipment e, net_interfaces ni where e.name = ? and e.id = ni.equipment_id");
  $self->prepare("ip_addr_select", "select na.ipaddr from equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id");

  $host{hostname} = $hostname;
  $host{mxhost} = "mx.cs.brown.edu";

  $self->{sths}->{equip_select}->execute($hostname);
  die "No record for host $hostname\n" if ($self->{sths}->{equip_select}->rows == 0);
  $self->{sths}->{equip_select}->bind_columns(\$host{equip_id}, \$host{contact}, \$host{status});
  $self->{sths}->{equip_select}->fetch;

  $self->{sths}->{comp_select}->execute($hostname);
  $self->{sths}->{comp_select}->bind_columns(\$host{comp_id}, \$host{hw_arch}, \$host{os_type}, \$host{pxelink});
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
    $self->{dbh}->commit;
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
    $self->{sths}->{class_insert}->execute($class);
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

sub insert_host {
  my $self = shift;
  my($host) = @_;

  $self->prepare("equip_insert", "INSERT INTO equipment (equip_status, usage, name, contact) VALUES ('deployed', 'academic', ?, ?) RETURNING id");

  $self->prepare("comp_insert", "INSERT INTO computers (equipment_id, hw_arch, os, pxelink) VALUES (?, ?, ?, ?) RETURNING id");
  $self->{sths}->{comp_insert}->bind_param(1, undef, SQL_INTEGER);

  $self->prepare("interface_insert", "INSERT INTO net_interfaces (equipment_id, ethernet) VALUES (?, ?) RETURNING id");
  $self->{sths}->{interface_insert}->bind_param(1, undef, SQL_INTEGER);
  $self->{sths}->{interface_insert}->bind_param(2, undef, {pg_type => PG_MACADDR});

  $self->prepare("address_insert", "INSERT INTO net_addresses (vlan_id, ipaddr, monitored) VALUES (?, ?, ?) RETURNING id");
  $self->{sths}->{address_insert}->bind_param(1, undef, SQL_INTEGER);
  $self->{sths}->{address_insert}->bind_param(2, undef, {pg_type => PG_INET});
  $self->{sths}->{address_insert}->bind_param(3, undef, {pg_type => PG_BOOL});

  $self->prepare("addr_iface_insert", "INSERT INTO net_addresses_net_interfaces (net_addresses_id, net_interfaces_id) VALUES (?, ?)");
  $self->{sths}->{addr_iface_insert}->bind_param(1, undef, SQL_INTEGER);
  $self->{sths}->{addr_iface_insert}->bind_param(2, undef, SQL_INTEGER);

  $self->prepare("dns_insert", "INSERT INTO net_dns_entries (name, domain, zone, net_address_id) VALUES (?, 'cs.brown.edu', 'both', ?)");
  $self->{sths}->{dns_insert}->bind_param(2, undef, SQL_INTEGER);

  $self->prepare("class_comp_insert", "INSERT INTO comp_classes_computers (comp_classes_id, computers_id) VALUES (?,?)");
  $self->{sths}->{class_comp_insert}->bind_param(1, undef, SQL_INTEGER);
  $self->{sths}->{class_comp_insert}->bind_param(2, undef, SQL_INTEGER);

  my $machine_name = $host->{'hostname'};

  print "importing cdb $machine_name";

  my $contact = $host->{'contact'};

  $host->{'aliases'} =~ s/\s//g;
  my @aliases = split(/,/, $host->{'aliases'});

  $host->{'classes'} =~ s/\s//g;
  my @classes = split(/,/, $host->{'classes'});

  my $ethernet = $host->{'ethernet'};

  my $ipaddr = $host->{'ip_addr'};
  my $vlan_id;
  if ((!$ipaddr) or ($ipaddr eq "")) {
    $ipaddr = undef;
    $vlan_id = $self->get_vlan("128.148.36.1");
  } else {
    $vlan_id = $self->get_vlan($ipaddr);
  }

  my $status = $host->{'status'};

  my $monitored = 0;
  if ($status eq "monitored") {
    $monitored = 1;
  }

  # create an equipment entry...

  $self->{sths}->{equip_insert}->execute($machine_name, $contact);
  my $equip_id = $self->{sths}->{equip_insert}->fetch()->[0];

  # fill in equip_status

  my $hw_arch = $host->{'hw_arch'};
  if ($hw_arch eq "") {
    $hw_arch = undef;
  } elsif ($hw_arch eq "x64") {
    $hw_arch = "amd64";
  }

  my $os = $host->{'os_type'};
  if (($os eq "other") or ($os eq "") or ($os eq "windows")) {
    $os = undef;
  }

  my $pxelink = $host->{'pxelink'};
  if ($pxelink eq "") {
    $pxelink = undef;
  }

  $self->{sths}->{comp_insert}->execute($equip_id, $hw_arch, $os, $pxelink);
  my $comp_id = $self->{sths}->{comp_insert}->fetch()->[0];

  $self->{sths}->{interface_insert}->execute($equip_id, $ethernet);
  my $interface_id = $self->{sths}->{interface_insert}->fetch()->[0];

  $self->{sths}->{address_insert}->execute($vlan_id, $ipaddr, $monitored);
  my $address_id = $self->{sths}->{address_insert}->fetch()->[0];

  $self->{sths}->{addr_iface_insert}->execute($address_id, $interface_id);

  $self->{sths}->{dns_insert}->execute($machine_name, $address_id);

  if ( $#aliases != -1 ) {
    foreach (@aliases) {
      print ", alias $_";
      $self->{sths}->{dns_insert}->execute($_, $address_id);
    }
  }

  if ( $#classes != -1 ) {
    foreach (@classes) {
      print ", class $_";
      my $class_id = $self->get_class($_);
      $self->{sths}->{class_comp_insert}->execute($class_id, $comp_id);
    }
  }

  print "\n";
}

# sub find_unused_ip {
#   my($ip_addr) = @_;
#   my(%ip_addrs) = ();
#   my(@nibbles, $addr);
# 
#   $ip_addr =~ s/\s+//g;
#   @nibbles = split(/\./, $ip_addr);
#   foreach $i (0 .. $#nibbles) { $nibbles[$i] =~ s/^0(.+)$/$1/; }
#   return join('.', @nibbles) if($nibbles[3] ne '*');
# 
#   # Build hash of used IP addresses to avoid for '*' replacement
#   %ip_addrs = get_all_ips;
#   
#   # Strip trailing nibble, which is '*'
# 
#   pop(@nibbles);
# 
#   # Try all values for $nibbles[3] in ascending order from 2 to 254.
#   # 255 is the broadcast address, 0 is the network address, and 1 we reserve
#   # so it can be manually assigned by sysadmins to routers.
# 
#   for($i = 2; $i < 255; $i++) {
#     $addr = join('.', @nibbles) . ".$i";
#     print "Trying $addr ...\n" if($opt_v);
#     next if(defined($ip_addrs{$addr}));
#     next if(defined($g_cdb_include_ip_addrs{$addr}));
#     return $addr;
#   }
# 
#   die "$PNAME ERROR: No addresses are available for the $nibbles[2] subnet\n";
# }


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

BrownCS::UDB - the Universal DataBase

=head1 SYNOPSIS

  use BrownCS::UDB;

  my $udb = BrownCS::UDB->new;
  $udb->start;

  my @hosts = $udb->all_hosts_in_class($class);
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
