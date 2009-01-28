#!/usr/bin/perl -w

################################################################################
#
# Prologue
#
################################################################################

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);
use Data::Dumper;

eval('require "/tstaff/share/cdb/db.pl";');

my $dbname = "udb";
my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=db", 'aleks', 'NohR0kei',
  {AutoCommit=>0, pg_errorlevel=>2}) or die "Couldn't connect to database: " . DBI->errstr;

$dbh->trace('SQL');

################################################################################
#
# Hosts
#
################################################################################

my $equip_insert = $dbh->prepare("INSERT INTO equipment (equip_status, usage, equip_name, contact) VALUES ('deployed', 'academic', ?, ?) RETURNING id");

my $comp_insert = $dbh->prepare("INSERT INTO computers (equipment_id, machine_name, hw_arch, os, pxelink, comments) VALUES (?, ?, ?, ?, ?, ?) RETURNING id");
$comp_insert->bind_param(1, undef, SQL_INTEGER);

my $interface_insert = $dbh->prepare("INSERT INTO net_interfaces (equipment_id, ethernet) VALUES (?, ?) RETURNING id");
$interface_insert->bind_param(1, undef, SQL_INTEGER);
$interface_insert->bind_param(2, undef, {pg_type => PG_MACADDR});

my $address_insert = $dbh->prepare("INSERT INTO net_addresses (vlan_id, dns_name, ipaddr, monitored) VALUES (?, ?, ?, ?) RETURNING id");
$address_insert->bind_param(1, undef, SQL_INTEGER);
$address_insert->bind_param(3, undef, {pg_type => PG_INET});
$address_insert->bind_param(4, undef, {pg_type => PG_BOOL});

my $addr_iface_insert = $dbh->prepare("INSERT INTO net_addresses_net_interfaces (net_addresses_id, net_interfaces_id) VALUES (?, ?)");
$addr_iface_insert->bind_param(1, undef, SQL_INTEGER);
$addr_iface_insert->bind_param(2, undef, SQL_INTEGER);

my $dns_insert = $dbh->prepare("INSERT INTO net_dns_entries (name, domain, net_address_id) VALUES (?, 'cs.brown.edu', ?)");
$dns_insert->bind_param(2, undef, SQL_INTEGER);

my $class_comp_insert = $dbh->prepare("INSERT INTO comp_classes_computers (comp_classes_id, computers_id) VALUES (?,?)");
$class_comp_insert->bind_param(1, undef, SQL_INTEGER);
$class_comp_insert->bind_param(2, undef, SQL_INTEGER);

sub insert_host {
  my($host) = @_;

  my $machine_name = $host->{'hostname'};

  print "importing cdb $machine_name";

  my $contact = $host->{'contact'};

  my $prim_grp = $host->{'prim_grp'};
  $host->{'aliases'} =~ s/\s//g;
  my @aliases = split(/,/, $host->{'aliases'});
  $host->{'classes'} =~ s/\s//g;
  my @classes = split(/,/, $host->{'classes'});

  my $ethernet = $host->{'ethernet'};

  my $ipaddr = $host->{'ip_addr'};
  my $vlan_id;
  if ((!$ipaddr) or ($ipaddr eq "")) {
    $ipaddr = undef;
    $vlan_id = get_vlan("128.148.36.1");
  } else {
    $vlan_id = get_vlan($ipaddr);
  }

  my $status = $host->{'status'};

  my $monitored = 0;
  if ($status eq "monitored") {
    $monitored = 1;
  }

  # create an equipment entry...

  $equip_insert->execute($machine_name, $contact);
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

  # a bunch of stuff from the comp database that we don't care
  # about...

  my $pxelink = $host->{'pxelink'};
  if ($pxelink eq "") {
    $pxelink = undef;
  }

  my $comments = $host->{'comment'};
  if ($comments eq "") {
    $comments = undef;
  }

  $comp_insert->execute($equip_id, $machine_name, $hw_arch, $os, $pxelink, $comments);
  my $comp_id = $comp_insert->fetch()->[0];

  $interface_insert->execute($equip_id, $ethernet);
  my $interface_id = $interface_insert->fetch()->[0];

  $address_insert->execute($vlan_id, $machine_name, $ipaddr, $monitored);
  my $address_id = $address_insert->fetch()->[0];

  $addr_iface_insert->execute($address_id, $interface_id);

  $dns_insert->execute($machine_name, $address_id);

  if ( $#aliases != -1 ) {
    foreach (@aliases) {
      print ", alias $_";
      $dns_insert->execute($_, $address_id);
    }
  }

  if ( $#classes != -1 ) {
    foreach (@classes) {
      print ", class $_";
      my $class_id = get_class($_);
      $class_comp_insert->execute($class_id, $comp_id);
    }
  }

  print "\n";
}

################################################################################
#
# Classes
#
################################################################################

my $class_select = $dbh->prepare("SELECT id from comp_classes where class = ?");
my $class_insert = $dbh->prepare("INSERT INTO comp_classes (class) VALUES (?) RETURNING id");

sub get_class {
  $class_select->execute($_);

  my $class_id;

  if ($class_select->rows == 0) {
    $class_insert->execute($_);
    $class_id = $class_insert->fetch()->[0];
  } else {
    print "...";
    $class_id = $class_select->fetchrow_arrayref()->[0];
    print "!!!";
  }

  return $class_id;
}

################################################################################
#
# VLANs
#
################################################################################

my $vlan_select = $dbh->prepare("SELECT id from net_vlans v where ? << v.network");

sub get_vlan {
  my ($ip) = @_;
  $vlan_select->execute($ip);

  my $vlan_id;

  if ($vlan_select->rows == 0) {
    die "Can't find vlan for $ip!\n";
  } else {
    $vlan_id = $vlan_select->fetchrow_arrayref()->[0];
  }

  return $vlan_id;
}

################################################################################
#
# Main
#
################################################################################

$dbh->do("DELETE FROM equipment;");
$dbh->do("DELETE FROM computers;");
$dbh->do("DELETE FROM net_interfaces;");
$dbh->do("DELETE FROM net_addresses;");
$dbh->do("DELETE FROM net_addresses_net_interfaces;");
$dbh->do("DELETE FROM net_dns_entries;");
$dbh->do("DELETE FROM comp_classes;");
$dbh->do("DELETE FROM comp_classes_computers;");

print "importing cdb...\n";

my($key, $data);
while ( ($key, $data) = each(%$cdb_by_hostname) ) {
  if (( $data->{'status'} ne 'disabled' ) and ($data->{'ethernet'} ne '' )) {
    &insert_host($data);
  }
}

$dbh->commit;

$equip_insert->finish;
$comp_insert->finish;
$interface_insert->finish;
$address_insert->finish;
$addr_iface_insert->finish;
$dns_insert->finish;
$class_comp_insert->finish;
$class_select->finish;
$class_insert->finish;
$vlan_select->finish;

$dbh->disconnect or die "Can't disconnect from database: $DBI::errstr\n";

