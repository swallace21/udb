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

my $debug = 0;

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

  while (! ($self->{db} = BrownCS::UDB::Schema->connect("dbi:Pg:dbname=udb;host=sysdb", $username, $password))) {
    if ($debug) {
      print "Error connecting to database. Try again.\n";
      print DBI->errstr if $debug;
    }
    $password = &ask_password;
    if (not $password) {
      exit(0);
    }
  };
  
  my $old_umask = umask(0077);
  $enc_password = encrypt($password);
  open(FH, ">$filename");
  print FH "$enc_password\n";
  close(FH);
  umask($old_umask);

  if ($debug) {
    my $dbg_file = "/tmp/test.debug.log";
    open ($self->{dbg_fh}, ">>$dbg_file") or die qq{Could not open "$dbg_file": $!\n};
    $self->db->storage->dbh->pg_server_trace($self->{dbg_fh});
    $self->db->storage->dbh->trace(2);
  }

}

sub DEMOLISH {
  my $self = shift;
  if ($debug) {
    $self->db->storage->dbh->pg_server_untrace;
    close($self->{dbg_fh});
  }
}

#
# Internal functions
#

sub create {
  my $self = shift;
  my ($table, $field, $value) = @_;

  my ($result) = $self->query("select $field from $table where $field = ?",
    $value)->flat;

  if (not $result) {
    ($result) = $self->query("insert into $table ($field) values (?) returning
      $field", $value)->flat;
  }

  return $result;
}

sub get_id {
  my $self = shift;
  my ($table, $field, $fieldval) = @_;

  my ($id) = $self->query("select id from $table where $field = ?",
    $fieldval)->flat;
   
  die "Can't find entry in $table where $field = $fieldval!\n" if not $id;

  return $id;
}

sub get_field {
  my $self = shift;
  my ($table, $field, $id) = @_;

  my ($fieldval) = $self->query("select $field from $table where id = ?",
    $id)->flat;

  die "Can't find entry in $table where id = $id!\n" if not $fieldval;

  return $fieldval;
}

#
# Single-record queries
#

sub get_class_id {
  my $self = shift;
  my ($name, $os) = @_;

  my ($result) = $self->query("select id from comp_classes where name = ? and
    os = ?", $name, $os)->flat;

  if (not $result) {
    ($result) = $self->query("insert into comp_classes (name, os) values (??)
      returning id", $name, $os)->flat;
  }
  
  return $result;
}

sub get_service_id {
  my $self = shift;
  my ($service) = @_;
  return $self->create("net_services", "service", $service);
}

sub get_interface_id {
  my $self = shift;
  my ($ethernet) = @_;
  return $self->create("net_interfaces", "ethernet", $ethernet);
}

sub get_location_id {
  my $self = shift;
  my($room) = shift;

  my ($result) = $self->query("select id from places where room = ?", $room)->flat;

  if (not $result) {
    ($result) = $self->query("insert into places (city, building, room) values
      (??) returning id", "Providence", "CIT", $room)->flat;
  }
}

sub get_equip {
  my $self = shift;
  my ($name) = @_;
  my $device = {};

  $device->{name} = $name;

  $device->{equip} = $self->query("select e.contact, e.equip_status as \
    status, e.managed_by, e.comments from equipment e where e.name = ?",
    $name)->hash;

  if (not $device->{equip}) {
    return ();
  }

  $device->{place} = $self->query("select p.city, p.building, p.room from \
    places p, equipment e where e.name = ? and e.place_id = p.id", $name)->hash;

  $device->{comp} = $self->query("select c.os, c.pxelink, c.system_model, \
    c.num_cpus, c.cpu_type, c.cpu_speed, c.memory, c.hard_drives, \
    c.total_disk, c.other_drives, c.network_cards, c.video_cards, c.os_name, \
    c.os_version, c.os_dist, c.info_time, c.boot_time from computers c where \
    c.name = ?", $name)->hash;

  if ($device->{comp}) {
    $device->{classes} = $self->query("select cc.name from comp_classes \
      cc, computers c, comp_classes_computers ccc where c.name = ? and \
      ccc.comp_class = cc.id and ccc.computer = c.name and cc.os = ?", $name,
      $device->{comp}->{os})->flat;
  }

  $device->{'switch'} = $self->query("select ns.fqdn, ns.num_ports, \
    ns.num_blades, ns.switch_type, ns.port_prefix, ns.connection, ns.username, \
    ns.pass from net_switches ns where ns.name = ?", $name)->hash;

  $device->{interfaces} = $self->query("select ni.id, ni.ethernet, \
    np.switch, np.port_num, np.blade_num, np.wall_plate from equipment e, \
    net_interfaces ni, net_ports np where e.name = ? and e.name = \
    ni.equip_name and ni.port_id = np.id", $name)->hashes;

  if (not $device->{interfaces}) {
    $device->{interfaces} = $self->query("select ni.id, ni.ethernet from \
      equipment e, net_interfaces ni where e.name = ? and e.name = \
      ni.equip_name", $name)->hashes;
  }

  $device->{ipaddr} = $self->query("select na.ipaddr from equipment e, \
    net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na \
    where e.name = ? and e.name = ni.equip_name and nani.net_interfaces_id = \
    ni.id and nani.net_addresses_id = na.id",$name)->flat;


  $device->{aliases} = $self->query("select nde.dns_name from \
    net_dns_entries nde, net_addresses_net_interfaces nani, net_interfaces ni, \
    net_addresses na where ni.equip_name = ? and nani.net_interfaces_id = \
    ni.id and nani.net_addresses_id = na.id and na.id = nde.address and \
    nde.authoritative = false", $name)->flat;

  $device->{services} = $self->query("select nans.net_services_id from \
    equipment e, net_addresses_net_interfaces nani, net_interfaces ni, \
    net_addresses na, net_addresses_net_services nans where e.name = ? and \
    e.name = ni.equip_name and nani.net_interfaces_id = ni.id and \
    nani.net_addresses_id = na.id and nans.net_addresses_id = \
    na.id",$name)->flat;

  return $device;
}

sub get_vlan {
  my $self = shift;
  my ($ip) = @_;

  my ($vlan) = $self->query("select vlan_num from net_vlans v where ? << \
    v.network", $ip)->flat;

  die "Can't find vlan for $ip!\n" if not $vlan;
  return $vlan;
}

sub is_protected {
  my $self = shift;
  my ($name) = @_;

  my ($protected) = $self->query("select e.protected from equipment e where e.name = \
    ?", $name)->flat;

  return $protected;
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

#
# Multi-record queries
#

sub get_all_ips {
  my $self = shift;
  return $self->query("select ipaddr from net_addresses")->flat;
}

sub all_hosts_in_room {
  my $self = shift;
  my ($room) = @_;
  return $self->query("select e.name from places p, equipment e where \
    e.place_id = p.id and p.room = ? order by e.name", $room)->flat;
}

sub all_hosts_in_class {
  my $self = shift;
  my ($name, $os) = @_;
  return $self->query("select c.name from comp_classes cc, computers c, \
    comp_classes_computers ccc where ccc.comp_class = cc.id and ccc.computer = \
    c.name and cc.name = ? and cc.os = ?", $name, $os)->flat;
}

sub get_host_class_map {
  my $self = shift;
  return $self->query("select c.name as name, cc.name as class from \
    comp_classes cc, computers c, comp_classes_computers ccc where \
    ccc.comp_class = cc.id and ccc.computer = c.name")->map_hashes("name");
}

#
# Inserts
#

sub insert_host {
  my $self = shift;
  my($host) = @_;

  my $protected = 0;

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
  if ((defined $ethernet) and ($ethernet eq "0:0:0:0:0:0")) {
    $ethernet = undef;
  }

  my $ipaddr = $host->{'ip_addr'};
  my $vlan_id;
  if ((!$ipaddr) or ($ipaddr eq "")) {
    $ipaddr = undef;
    $vlan_id = 36;
  } else {
    $vlan_id = $self->get_vlan($ipaddr);
  }

  my $status = $host->{'status'};

  my $monitored = 0;
  if ($status eq "monitored") {
    $monitored = 1;
  }

  my $os = $host->{'os_type'};
  if (($os eq "other") or ($os eq "") or ($os eq "windows")) {
    $os = undef;
  }

  my $equip_status = "deployed";
  if (defined $os and (($os eq "linux-xen") or ($os eq "linux64-xen"))) {
    $equip_status = "virtual";
  }

  if (defined $os and (($os eq "linux-server") or ($os eq "linux64-server"))) {
    $protected = 1;
  }

  my $managed_by = $host->{'managed_by'};

  my $comments = $host->{'comment'};
  if (!$comments) {
    $comments = undef;
  }

  # create an equipment entry...

  $self->query("INSERT INTO equipment (equip_status, managed_by, name, \
    contact, comments) VALUES (??)", $equip_status, $managed_by, $hostname,
    $contact, $comments);

  my $pxelink = $host->{'pxelink'};
  if ((defined $pxelink) and ($pxelink eq "")) {
    $pxelink = undef;
  }

  $self->query("INSERT INTO computers (name, os, pxelink) VALUES (??)",
    $hostname, $os, $pxelink);

  my ($address_id) = $self->query("INSERT INTO net_addresses (vlan_num, \
    ipaddr, monitored) VALUES (??) RETURNING id", $vlan_id, $ipaddr,
    $monitored)->flat;

  my ($interface_id) = $self->query("INSERT INTO net_interfaces (equip_name, \
    ethernet, primary_address) VALUES (??) RETURNING id", $hostname, $ethernet,
    $address_id)->flat;

  $self->query("INSERT INTO net_addresses_net_interfaces (net_addresses_id,
    net_interfaces_id) VALUES (??)", $address_id, $interface_id);

  my $domain = 'cs.brown.edu';
  if ($host->{prim_grp} eq 'ilab') {
    $domain = 'ilab.cs.brown.edu';
  }

  my $dns_query = "INSERT INTO net_dns_entries (dns_name, domain, address, authoritative, dns_region) VALUES (??)";

  $self->query($dns_query, $hostname, $domain, $address_id, 1, "internal");
  $self->query($dns_query, $hostname, $domain, $address_id, 1, "external");

  if ( $#aliases != -1 ) {
    foreach (@aliases) {
      $self->query($dns_query, $_, $domain, $address_id, 0, "internal");
      $self->query($dns_query, $_, $domain, $address_id, 0, "external");
    }
  }

  if ( $#classes != -1 ) {
    foreach (@classes) {
      if (/^service\./) {
        s/^service\.//;
        $self->get_service_id($_);
        $self->query("INSERT INTO net_addresses_net_services \
          (net_addresses_id, net_services_id) VALUES (??)", $address_id, $_);
        $protected = 1;
      } else {
        my $class_id = $self->get_class_id($_, $os);
        $self->query("INSERT INTO comp_classes_computers (comp_class, \
          computer) VALUES (??)", $class_id, $hostname);
      }
    }
  }

  if ($protected) {
    $self->query("update equipment set protected = true where name = ?");
  }

}

sub insert_virtual_ip {
  my $self = shift;
  my($host) = @_;

  my $address_insert = $self->query("INSERT INTO net_addresses (vlan_num, ipaddr, monitored) VALUES (?, ?, ?) RETURNING id");

  my $dns_insert = $self->query("INSERT INTO net_dns_entries (dns_name, domain, address, authoritative, dns_region) VALUES (?, ?, ?, ?, ?)");

  my $addr_svc_insert = $self->query("INSERT INTO net_addresses_net_services (net_addresses_id, net_services_id) VALUES (?, ?)");

  my $hostname = $host->{'hostname'};

  $host->{'aliases'} =~ s/\s//g;
  my @aliases = split(/,/, $host->{'aliases'});

  $host->{'classes'} =~ s/\s//g;
  my @classes = split(/,/, $host->{'classes'});

  my $ipaddr = $host->{'ip_addr'};
  my $vlan_id;
  if ((!$ipaddr) or ($ipaddr eq "")) {
    die "no ip address for host $hostname!!!\n";
  } else {
    $vlan_id = $self->get_vlan($ipaddr);
  }

  my $status = $host->{'status'};

  my $monitored = 0;
  if ($status eq "monitored") {
    $monitored = 1;
  }

  $address_insert->execute($vlan_id, $ipaddr, $monitored);
  my $address_id = $address_insert->fetch()->[0];
  $address_insert->finish;

  my $domain = 'cs.brown.edu';
  if ($host->{prim_grp} eq 'ilab') {
    $domain = 'ilab.cs.brown.edu';
  }

  $dns_insert->execute($hostname, $domain, $address_id, 1, "internal");
  $dns_insert->execute($hostname, $domain, $address_id, 1, "external");

  if ( $#aliases != -1 ) {
    foreach (@aliases) {
      $dns_insert->execute($_, $domain, $address_id, 0, "internal");
      $dns_insert->execute($_, $domain, $address_id, 0, "external");
    }
  }

  $dns_insert->finish;

  if ( $#classes != -1 ) {
    foreach (@classes) {
      if (/^service\./) {
        s/^service\.//;
        $self->get_service_id($_);
        $addr_svc_insert->execute($address_id, $_);
      } else {
      }
    }
  }

  $addr_svc_insert->finish;

}

sub insert_switch {
  my $self = shift;
  my($switch) = @_;

  # create an equipment entry...

  my $equip_insert = $self->query("INSERT INTO equipment (name, equip_status, managed_by, contact, place_id) VALUES (?, ?, ?, ?, ?)");

  my $fqdn = $switch->{'fqdn'};

  my @split_fqdn = split(/\./, $fqdn);
  my $name = $split_fqdn[0];

  my $equip_status = "deployed";
  my $managed_by = "cis";
  my $contact = 'help@brown.edu';
  my $location = $switch->{'location'};
  my $place = $self->get_location_id($location);
  
  $equip_insert->execute($name, $equip_status, $managed_by, $contact, $place);
  $equip_insert->finish;

  # and a net_switches entry...

  my $switch_insert = $self->query("INSERT INTO net_switches (name, fqdn, num_ports, num_blades, switch_type, port_prefix, connection, username, pass) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");

  my $num_ports = $switch->{'numports'};
  my $num_blades = $switch->{'numblades'};
  my $switch_type = $switch->{'type'};
  my $port_prefix = $switch->{'prefix'};
  my $connection = $switch->{'mode'};
  my $username = $switch->{'user'};
  my $pass = $switch->{'login'};

  $switch_insert->execute($name, $fqdn, $num_ports, $num_blades, $switch_type, $port_prefix, $connection, $username, $pass);
  $switch_insert->finish;

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
