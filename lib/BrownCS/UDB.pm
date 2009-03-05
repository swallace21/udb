package BrownCS::UDB;

use 5.010000;
use strict;
use warnings;

use Crypt::Simple;

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

use BrownCS::UDB::Util qw(:all);

my $debug = 0;

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
  my ($username) = @_;

  my $old_umask = umask(0077);
  my $enc_password;
  my $password;
  my $filename = "/tmp/udb_cc.$username";
  if (-r $filename) {
    open(FH, $filename);
    $enc_password = <FH>;
    chomp $enc_password;
    $password = decrypt($enc_password);
    close(FH);
  } else {
    $password = &ask_password;
  }
  $enc_password = encrypt($password);
  open(FH, ">$filename");
  print FH "$enc_password\n";
  close(FH);
  umask($old_umask);

  $self->{dbh} = DBI->connect("dbi:Pg:dbname=udb;host=sysdb", $username, $password, {AutoCommit=>0, pg_errorlevel=>2}) or die "Couldn't connect to database: " . DBI->errstr;

  #$self->{dbh}->trace(2);

  if ($debug) {
    my $dbg_file = "/tmp/test.debug.log";
    open ($self->{dbg_fh}, ">>$dbg_file") or die qq{Could not open "$dbg_file": $!\n};
    $self->{dbh}->pg_server_trace($self->{dbg_fh});
  }

}

sub create {
  my $self = shift;
  my ($table, $field, $value) = @_;

  my $sth_insert = $self->prepare("insert into $table ($field) values (?)");
  my $sth_select = $self->prepare("select $field from $table where $field = ?");

  $sth_select->execute($value);

  if ($sth_select->rows == 0) {
    $sth_insert->execute($value);
  }
}

sub get_class_id {
  my $self = shift;
  my ($name, $os) = @_;

  my $id;

  my $sth_insert = $self->prepare("insert into comp_classes (name, os) values (?, ?)");

  my $sth_select = $self->prepare("select id from comp_classes where name = ? and os = ?");
  $sth_select->execute($name, $os);
  $sth_select->bind_columns(\$id);

  if ($sth_select->rows == 0) {
    $sth_insert->execute($name, $os);
    $id = $self->{dbh}->last_insert_id(undef, undef, "comp_classes", undef);
    return $id;
  } else {
    $sth_select->fetch;
    return $id;
  }
}

sub get_service_id {
  my $self = shift;
  my ($service) = @_;
  return $self->create("net_services", "service", $service);
}

sub get_location_id {
  my $self = shift;
  my($room) = shift;

  my $id;

  my $sth_insert = $self->prepare("insert into places (city, building, room) values (?, ?, ?)");

  my $sth_select = $self->prepare("select id from places where room = ?");
  $sth_select->execute($room);
  $sth_select->bind_columns(\$id);

  if ($sth_select->rows == 0) {
    $sth_insert->execute("Providence", "CIT", $room);
    return $self->{dbh}->last_insert_id(undef, undef, "places", undef);
  } else {
    $sth_select->fetch;
    return $id;
  }
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

sub all_hosts_in_room {
  my $self = shift;
  my ($room) = @_;
  my @hosts_in_room = ();
  my $host;

  my $all_hosts_in_room_select = $self->prepare("select e.name from places p, equipment e where e.place_id = p.id and p.room = ?");

  $all_hosts_in_room_select->execute($room);
  $all_hosts_in_room_select->bind_columns(\$host);
  
  while ($all_hosts_in_room_select->fetch) {
    push @hosts_in_room, $host;
  }

  return @hosts_in_room;
}

sub all_hosts_in_class {
  my $self = shift;
  my ($name, $os) = @_;
  my @hosts_in_class = ();
  my $host;

  my $all_hosts_in_class_select = $self->prepare("select c.name from comp_classes cc, computers c, comp_classes_computers ccc where ccc.comp_class = cc.id and ccc.computer = c.name and cc.name = ? and cc.os = ?");

  $all_hosts_in_class_select->execute($name, $os);
  $all_hosts_in_class_select->bind_columns(\$host);
  
  while ($all_hosts_in_class_select->fetch) {
    push @hosts_in_class, $host;
  }

  return @hosts_in_class;
}

sub get_equip {
  my $self = shift;
  my ($name) = @_;
  my %host = ();

  my $aliases_select = $self->prepare("select nde.dns_name from net_dns_entries nde, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where ni.equip_name = ? and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id and na.id = nde.address and nde.authoritative = false");
  my $classes_select = $self->prepare("select cc.name from comp_classes cc, computers c, comp_classes_computers ccc where c.name = ? and ccc.comp_class = cc.id and ccc.computer = c.name and cc.os = ?");
  my $comp_select = $self->prepare("select c.os, c.pxelink, c.system_model, c.num_cpus, c.cpu_type, c.cpu_speed, c.memory, c.hard_drives, c.total_disk, c.other_drives, c.network_cards, c.video_cards, c.os_name, c.os_version, c.os_dist, c.info_time, c.boot_time from computers c where c.name = ?");
  my $equip_select = $self->prepare("select e.contact, e.equip_status, e.managed_by from equipment e where e.name = ?");
  my $iface_select = $self->prepare("select ni.ethernet, np.switch, np.port_num, np.blade_num, np.wall_plate from equipment e, net_interfaces ni, net_ports np where e.name = ? and e.name = ni.equip_name and ni.port_id = np.id");
  my $ethernet_select = $self->prepare("select ni.ethernet from equipment e, net_interfaces ni where e.name = ? and e.name = ni.equip_name");
  my $ip_addr_select = $self->prepare("select na.ipaddr from equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.name = ? and e.name = ni.equip_name and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id");
  my $place_select = $self->prepare("select p.city, p.building, p.room from places p, equipment e where e.name = ? and e.place_id = p.id");
  my $service_select = $self->prepare("select nans.net_services_id from equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na, net_addresses_net_services nans where e.name = ?  and e.name = ni.equip_name and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id and nans.net_addresses_id = na.id");
  my $switch_select = $self->prepare("select ns.fqdn, ns.num_ports, ns.num_blades, ns.switch_type, ns.port_prefix, ns.connection, ns.username, ns.pass from net_switches ns where ns.name = ?");

  $host{name} = $name;

  $equip_select->execute($name);
  $equip_select->bind_columns(\$host{contact}, \$host{status}, \$host{managed_by});
  $equip_select->fetch;

  if ($equip_select->rows == 0) {
    return ();
  }

  $place_select->execute($name);
  $place_select->bind_columns(\$host{city}, \$host{building}, \$host{room});
  $place_select->fetch;

  $comp_select->execute($name);
  $comp_select->bind_columns(\$host{os_type}, \$host{pxelink},
    \$host{system_model}, \$host{num_cpus}, \$host{cpu_type},
    \$host{cpu_speed}, \$host{memory}, \$host{hard_drives},
    \$host{total_disk}, \$host{other_drives}, \$host{network_cards},
    \$host{video_cards}, \$host{os_name}, \$host{os_version},
    \$host{os_dist}, \$host{info_time}, \$host{boot_time});
  $comp_select->fetch;
  $host{is_comp} = $comp_select->rows;

  if ($host{is_comp}) {
    $host{classes} = [];
    my $class;
    $classes_select->execute($name, $host{os_type});
    $classes_select->bind_columns(\$class);
    while ($classes_select->fetch) {
      if ($class ne $name) {
        push @{$host{classes}}, $class;
      }
    }
  }

  $switch_select->execute($name);
  $switch_select->bind_columns(\$host{fqdn}, \$host{num_ports},
    \$host{num_blades}, \$host{switch_type}, \$host{port_prefix},
    \$host{connection}, \$host{username}, \$host{pass});
  $switch_select->fetch;
  $host{is_switch} = $switch_select->rows;

  $host{interfaces} = [];
  my %interface = ();
  $iface_select->execute($name);
  $iface_select->bind_columns(\$interface{ethernet},
    \$interface{'switch'}, \$interface{port_num}, \$interface{blade_num},
    \$interface{wall_plate});
  while ($iface_select->fetch) {
    push @{$host{interfaces}}, \%interface;
  }

  if ($iface_select->rows == 0) {
    $ethernet_select->execute($name);
    $ethernet_select->bind_columns(\$interface{ethernet});
    $interface{'switch'} = undef;
    $interface{'port_num'} = undef;
    $interface{'blade_num'} = undef;
    $interface{'wall_plate'} = undef;
    while ($ethernet_select->fetch) {
      push @{$host{interfaces}}, \%interface;
    }
  }

  $host{ip_addr} = [];
  my $ip_addr; 
  $ip_addr_select->execute($name);
  $ip_addr_select->bind_columns(\$ip_addr);
  while ($ip_addr_select->fetch) {
    push @{$host{ip_addr}}, $ip_addr;
  }

  $host{aliases} = [];
  my $alias;
  $aliases_select->execute($name);
  $aliases_select->bind_columns(\$alias);
  while ($aliases_select->fetch) {
    if ($alias ne $name) {
      push @{$host{aliases}}, $alias;
    }
  }

  $host{services} = [];
  my $service;
  $service_select->execute($name);
  $service_select->bind_columns(\$service);
  while ($service_select->fetch) {
    if ($service ne $name) {
      push @{$host{services}}, $service;
    }
  }

  return %host;
}

sub get_host {
  my $self = shift;
  my ($hostname) = @_;
  my %host = $self->get_equip($hostname);

  if ($host{is_comp}) {
    return %host;
  } else {
    return ();
  } 
}

sub finish {
  my $self = shift;
  foreach my $sth (@{$self->{sths}}) {
    $sth->finish;
  }

  if ($debug) {
    $self->{dbh}->pg_server_untrace;
    close($self->{dbg_fh});
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

sub get_vlan {
  my $self = shift;
  my ($ip) = @_;

  my $sth = $self->prepare("select vlan_num from net_vlans v where ? << v.network");

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

  my $protected = 0;

  my $equip_insert = $self->prepare("INSERT INTO equipment (equip_status, managed_by, name, contact) VALUES (?, ?, ?, ?)");

  my $comp_insert = $self->prepare("INSERT INTO computers (name, os, pxelink) VALUES (?, ?, ?)");

  my $address_insert = $self->prepare("INSERT INTO net_addresses (vlan_num, ipaddr, monitored) VALUES (?, ?, ?) RETURNING id");
  $address_insert->bind_param(1, undef, SQL_INTEGER);
  $address_insert->bind_param(2, undef, {pg_type => PG_INET});
  $address_insert->bind_param(3, undef, {pg_type => PG_BOOL});

  my $interface_insert = $self->prepare("INSERT INTO net_interfaces (equip_name, ethernet, primary_address) VALUES (?, ?, ?) RETURNING id");
  $interface_insert->bind_param(2, undef, {pg_type => PG_MACADDR});
  $interface_insert->bind_param(3, undef, SQL_INTEGER);

  my $addr_iface_insert = $self->prepare("INSERT INTO net_addresses_net_interfaces (net_addresses_id, net_interfaces_id) VALUES (?, ?)");
  $addr_iface_insert->bind_param(1, undef, SQL_INTEGER);
  $addr_iface_insert->bind_param(2, undef, SQL_INTEGER);

  my $dns_insert = $self->prepare("INSERT INTO net_dns_entries (dns_name, domain, address, authoritative, dns_region) VALUES (?, ?, ?, ?, ?)");
  $dns_insert->bind_param(3, undef, SQL_INTEGER);
  $dns_insert->bind_param(4, undef, {pg_type => PG_BOOL});

  my $class_comp_insert = $self->prepare("INSERT INTO comp_classes_computers (comp_class, computer) VALUES (?,?)");

  my $addr_svc_insert = $self->prepare("INSERT INTO net_addresses_net_services (net_addresses_id, net_services_id) VALUES (?, ?)");
  $addr_svc_insert->bind_param(1, undef, SQL_INTEGER);

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

  my $managed_by = "tstaff";

  # create an equipment entry...

  $equip_insert->execute($equip_status, $managed_by, $hostname, $contact);
  $equip_insert->finish;

  my $pxelink = $host->{'pxelink'};
  if ((defined $pxelink) and ($pxelink eq "")) {
    $pxelink = undef;
  }

  $comp_insert->execute($hostname, $os, $pxelink);
  $comp_insert->finish;

  $address_insert->execute($vlan_id, $ipaddr, $monitored);
  my $address_id = $address_insert->fetch()->[0];
  $address_insert->finish;

  $interface_insert->execute($hostname, $ethernet, $address_id);
  my $interface_id = $interface_insert->fetch()->[0];
  $interface_insert->finish;

  $addr_iface_insert->execute($address_id, $interface_id);
  $addr_iface_insert->finish;

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
        $protected = 1;
      } else {
        my $class_id = $self->get_class_id($_, $os);
        $class_comp_insert->execute($class_id, $hostname);
      }
    }
  }

  $addr_svc_insert->finish;
  $class_comp_insert->finish;

  if ($protected) {
    my $sth = $self->prepare("update equipment set protected = true where name = ?");
    $sth->execute($hostname);
    $sth->finish;
  }

}

sub insert_virtual_ip {
  my $self = shift;
  my($host) = @_;

  my $address_insert = $self->prepare("INSERT INTO net_addresses (vlan_num, ipaddr, monitored) VALUES (?, ?, ?) RETURNING id");
  $address_insert->bind_param(1, undef, SQL_INTEGER);
  $address_insert->bind_param(2, undef, {pg_type => PG_INET});
  $address_insert->bind_param(3, undef, {pg_type => PG_BOOL});

  my $dns_insert = $self->prepare("INSERT INTO net_dns_entries (dns_name, domain, address, authoritative, dns_region) VALUES (?, ?, ?, ?, ?)");
  $dns_insert->bind_param(3, undef, SQL_INTEGER);
  $dns_insert->bind_param(4, undef, {pg_type => PG_BOOL});

  my $addr_svc_insert = $self->prepare("INSERT INTO net_addresses_net_services (net_addresses_id, net_services_id) VALUES (?, ?)");
  $addr_svc_insert->bind_param(1, undef, SQL_INTEGER);

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

sub get_host_class_map {
  my $self = shift;

  my $sth = $self->prepare("select c.name, cc.name from comp_classes cc, computers c, comp_classes_computers ccc where ccc.comp_class = cc.id and ccc.computer = c.name");
  $sth->execute();
  my $array_ref = $sth->fetchall_arrayref({});

  my $host_classes = {};

  foreach my $ccc (@{$array_ref}) {
    if (not defined @{$host_classes->{$ccc->{name}}}) {
      $host_classes->{$ccc->{name}} = [];
    }
    push @{$host_classes->{$ccc->{name}}}, $ccc->{class};
  }
  
  return $host_classes;
}

sub insert_switch {
  my $self = shift;
  my($switch) = @_;

  # create an equipment entry...

  my $equip_insert = $self->prepare("INSERT INTO equipment (name, equip_status, managed_by, contact, place_id) VALUES (?, ?, ?, ?, ?)");

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

  my $switch_insert = $self->prepare("INSERT INTO net_switches (name, fqdn, num_ports, num_blades, switch_type, port_prefix, connection, username, pass) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");

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

sub is_protected {
  my $self = shift;
  my ($name) = @_;

  my $sth = $self->prepare("select e.protected from equipment e where e.name = ?");

  my $protected = 0;

  $sth->execute($name);
  $sth->bind_columns(\$protected);
  $sth->fetch;

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
