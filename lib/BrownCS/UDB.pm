package BrownCS::UDB;

use 5.010000;
use strict;
use warnings;

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %args = @_;
  my $self = {};

  $self->{dbh} = undef;
  @{$self->{sths}} = ();

  bless($self, $class);
  return $self;
}

sub prepare {
  my $self = shift;
  my ($st) = @_;
  my $sth = $self->{dbh}->prepare($st);
  push @{$self->{sths}}, $sth;
  return $sth;
}

sub start {
  my $self = shift;
  my ($username, $password) = @_;
  $self->{dbh} = DBI->connect("dbi:Pg:dbname=udb;host=sysdb", $username, $password, {AutoCommit=>0, pg_errorlevel=>2}) or die "Couldn't connect to database: " . DBI->errstr;

  my $all_aliases_select = $self->prepare("select name from net_dns_entries");
  my $all_classes_select = $self->prepare("select cc.class from comp_classes cc");
  my $all_comps_select = $self->prepare("select hw_arch, os, pxelink from computers");
  my $all_equip_select = $self->prepare("select contact, equip_status from equipment");
  my $all_ethernet_select = $self->prepare("select ethernet from net_interfaces");

  #$self->{dbh}->trace(1);
}

sub get_all_ips {
  my $self = shift;
  my %ip_addrs = ();
  my $addr;

  my $sth = $self->prepare("select ipaddr from net_addresses");
  $sth->execute;
  $sth->bind_columns(\$addr);

  while ($sth->fetch) {
    $ip_addrs{$addr} = 1;
  }

  return %ip_addrs;
}

sub all_hosts_in_class {
  my $self = shift;
  my ($class) = @_;
  my @hosts_in_class = ();
  my $host;

  my $all_hosts_in_class_select = $self->prepare("select e.name from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id and cc.class = ?");

  $all_hosts_in_class_select->execute($class);
  $all_hosts_in_class_select->bind_columns(\$host);
  
  while ($all_hosts_in_class_select->fetch) {
    push @hosts_in_class, $host;
  }

  return @hosts_in_class;
}

sub get_host {
  my $self = shift;
  my ($hostname) = @_;
  my %host = ();

  my $aliases_select = $self->prepare("select nde.name from net_dns_entries nde, equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id and na.id = nde.net_address_id");
  my $classes_select = $self->prepare("select cc.class from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.name = ? and e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id");
  my $comp_select = $self->prepare("select c.id, c.hw_arch, c.os, c.pxelink from equipment e, computers c where e.name = ? and c.equipment_id = e.id");
  my $equip_select = $self->prepare("select id, contact, equip_status, usage, managed_by from equipment where name = ?");
  my $ethernet_select = $self->prepare("select ni.ethernet from equipment e, net_interfaces ni where e.name = ? and e.id = ni.equipment_id");
  my $ip_addr_select = $self->prepare("select na.ipaddr from equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id");

  $host{hostname} = $hostname;
  $host{mxhost} = "mx.cs.brown.edu";

  $equip_select->execute($hostname);
  die "No record for host $hostname\n" if ($equip_select->rows == 0);
  $equip_select->bind_columns(\$host{equip_id}, \$host{contact}, \$host{status}, \$host{usage}, \$host{managed_by});
  $equip_select->fetch;

  $host{status} = $self->get_field("equip_status_types", "description", $host{status});
  $host{managed_by} = $self->get_field("management_types", "description", $host{managed_by});
  $host{usage} = $self->get_field("equip_usage_types", "description", $host{usage});

  $comp_select->execute($hostname);
  $comp_select->bind_columns(\$host{comp_id}, \$host{hw_arch}, \$host{os_type}, \$host{pxelink});
  $comp_select->fetch;

  $ethernet_select->execute($hostname);
  $ethernet_select->bind_columns(\$host{ethernet});
  $ethernet_select->fetch;

  $ip_addr_select->execute($hostname);
  $ip_addr_select->bind_columns(\$host{ip_addr});
  $ip_addr_select->fetch;

  $host{aliases} = [];
  my $alias;
  $aliases_select->execute($hostname);
  $aliases_select->bind_columns(\$alias);
  while ($aliases_select->fetch) {
    if ($alias ne $hostname) {
      push @{$host{aliases}}, $alias;
    }
  }

  $host{classes} = [];
  my $class;
  $classes_select->execute($hostname);
  $classes_select->bind_columns(\$class);
  while ($classes_select->fetch) {
    if ($class ne $hostname) {
      push @{$host{classes}}, $class;
    }
  }

  return %host;
}

sub finish {
  my $self = shift;
  foreach my $sth (@{$self->{sths}}) {
    $sth->finish;
  }

  if ($self->{dbh}) {
    $self->{dbh}->commit;
    $self->{dbh}->disconnect;
  }
}

sub get_id {
  my $self = shift;
  my ($table, $field, $value) = @_;
  my $id;

  my $sth_select = $self->prepare("select id from $table where $field = ?");

  $sth_select->execute($value);

  if ($sth_select->rows == 0) {
    die "Can't find entry in $table where $field = $value!\n";
  } else {
    $id = $sth_select->fetchrow_arrayref()->[0];
  }

  return $id;
}

sub get_or_create_id {
  my $self = shift;
  my ($table, $field, $value) = @_;
  my $id;

  my $sth_insert = $self->prepare("insert into $table ($field) values (?) returning id");
  my $sth_select = $self->prepare("select id from $table where $field = ?");

  $sth_select->execute($value);

  if ($sth_select->rows == 0) {
    $sth_insert->execute($value);
    $id = $sth_insert->fetch()->[0];
  } else {
    $id = $sth_select->fetchrow_arrayref()->[0];
  }

  return $id;
}

sub get_field {
  my $self = shift;
  my ($table, $field, $value) = @_;
  my $id;

  my $sth_select = $self->prepare("select $field from $table where id = ?");

  $sth_select->execute($value);

  if ($sth_select->rows == 0) {
    die "Can't find entry in $table where id = $value!\n";
  } else {
    $id = $sth_select->fetchrow_arrayref()->[0];
  }

  return $id;
}

sub get_class_id {
  my $self = shift;
  my ($class) = @_;
  return $self->get_or_create_id("comp_classes", "class", $class);
}

sub get_vlan {
  my $self = shift;
  my ($ip) = @_;

  my $sth = $self->prepare("select id from net_vlans v where ? << v.network");

  $sth->execute($ip);

  my $vlan_id;

  if ($sth->rows == 0) {
    die "Can't find vlan for $ip!\n";
  } else {
    $vlan_id = $sth->fetchrow_arrayref()->[0];
  }

  return $vlan_id;
}

sub insert_host {
  my $self = shift;
  my($host) = @_;

  my $deployed_id = $self->get_id("equip_status_types", "description", "deployed");
  my $academic_id = $self->get_id("equip_usage_types", "description", "academic");
  my $managed_by_id = $self->get_id("management_types", "description", "tstaff");

  my $equip_insert = $self->prepare("INSERT INTO equipment (equip_status, usage, managed_by, name, contact) VALUES ($deployed_id, $academic_id, $managed_by_id, ?, ?) RETURNING id");

  my $comp_insert = $self->prepare("INSERT INTO computers (equipment_id, hw_arch, os, pxelink) VALUES (?, ?, ?, ?) RETURNING id");
  $comp_insert->bind_param(1, undef, SQL_INTEGER);

  my $interface_insert = $self->prepare("INSERT INTO net_interfaces (equipment_id, ethernet) VALUES (?, ?) RETURNING id");
  $interface_insert->bind_param(1, undef, SQL_INTEGER);
  $interface_insert->bind_param(2, undef, {pg_type => PG_MACADDR});

  my $address_insert = $self->prepare("INSERT INTO net_addresses (vlan_id, ipaddr, monitored, dns_name, domain) VALUES (?, ?, ?, ?, 'cs.brown.edu') RETURNING id");
  $address_insert->bind_param(1, undef, SQL_INTEGER);
  $address_insert->bind_param(2, undef, {pg_type => PG_INET});
  $address_insert->bind_param(3, undef, {pg_type => PG_BOOL});

  my $addr_iface_insert = $self->prepare("INSERT INTO net_addresses_net_interfaces (net_addresses_id, net_interfaces_id) VALUES (?, ?)");
  $addr_iface_insert->bind_param(1, undef, SQL_INTEGER);
  $addr_iface_insert->bind_param(2, undef, SQL_INTEGER);

  my $dns_insert = $self->prepare("INSERT INTO net_dns_entries (name, domain, zone, net_address_id) VALUES (?, 'cs.brown.edu', 'both', ?)");
  $dns_insert->bind_param(2, undef, SQL_INTEGER);

  my $class_comp_insert = $self->prepare("INSERT INTO comp_classes_computers (comp_classes_id, computers_id) VALUES (?,?)");
  $class_comp_insert->bind_param(1, undef, SQL_INTEGER);
  $class_comp_insert->bind_param(2, undef, SQL_INTEGER);

  my $hostname = $host->{'hostname'};

  my $contact = $host->{'contact'};

  $host->{'aliases'} =~ s/\s//g;
  my @aliases = split(/,/, $host->{'aliases'});

  $host->{'classes'} =~ s/\s//g;
  my @classes = split(/,/, $host->{'classes'});

  my $ethernet = $host->{'ethernet'};
  if ((defined $ethernet) and ($ethernet eq "")) {
    $ethernet = undef;
  }

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

  $equip_insert->execute($hostname, $contact);
  my $equip_id = $equip_insert->fetch()->[0];

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
  if ((defined $pxelink) and ($pxelink eq "")) {
    $pxelink = undef;
  }

  $comp_insert->execute($equip_id, $hw_arch, $os, $pxelink);
  my $comp_id = $comp_insert->fetch()->[0];

  $interface_insert->execute($equip_id, $ethernet);
  my $interface_id = $interface_insert->fetch()->[0];

  $address_insert->execute($vlan_id, $ipaddr, $monitored, $hostname);
  my $address_id = $address_insert->fetch()->[0];

  $addr_iface_insert->execute($address_id, $interface_id);

  $dns_insert->execute($hostname, $address_id);

  if ( $#aliases != -1 ) {
    foreach (@aliases) {
      $dns_insert->execute($_, $address_id);
    }
  }

  if ( $#classes != -1 ) {
    foreach (@classes) {
      my $class_id = $self->get_class_id($_);
      $class_comp_insert->execute($class_id, $comp_id);
    }
  }
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