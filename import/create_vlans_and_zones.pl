#!/usr/bin/perl -w

use strict;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

my $dbname = "udb";
print "creating vlans and zones...\n";
my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=db", 'aleks', 'NohR0kei',
  {AutoCommit=>0}) or die "Couldn't connect to database: " . DBI->errstr;

$dbh->do("DELETE FROM net_zones; DELETE FROM net_vlans;");

my $zone_insert = $dbh->prepare("INSERT INTO net_zones (owner, routing, comments) VALUES (?, ?, ?)");

my $vlan_insert = $dbh->prepare("INSERT INTO net_vlans (zone_id, vlan_num, network, comments) VALUES (?, ?, ?, ?)");
$vlan_insert->bind_param(1, undef, SQL_INTEGER);
$vlan_insert->bind_param(2, undef, SQL_INTEGER);
$vlan_insert->bind_param(3, undef, {pg_type => PG_CIDR});

$zone_insert->execute("tstaff", "DMZ", undef);
my $tstaff_DMZ_id = $dbh->last_insert_id(undef, undef, "net_zones", undef);

$zone_insert->execute("tstaff", "private", undef);
my $tstaff_private_id = $dbh->last_insert_id(undef, undef, "net_zones", undef);

$zone_insert->execute("tstaff", "standard", undef);
my $tstaff_standard_id = $dbh->last_insert_id(undef, undef, "net_zones", undef);

$zone_insert->execute("user", "DMZ", undef);
my $user_DMZ_id = $dbh->last_insert_id(undef, undef, "net_zones", undef);

$zone_insert->execute("user", "private", "cs166 (security course)");
my $cs166_id = $dbh->last_insert_id(undef, undef, "net_zones", undef);

$zone_insert->execute("user", "special", "completely outside the department");
my $outside_id = $dbh->last_insert_id(undef, undef, "net_zones", undef);

$zone_insert->execute("user", "special", "OSHEAN subnet (for jj)");
my $jj_id = $dbh->last_insert_id(undef, undef, "net_zones", undef);

$zone_insert->execute("user", "special", "techhouse");
my $techhouse_id = $dbh->last_insert_id(undef, undef, "net_zones", undef);

$zone_insert->execute("user", "special", "ipsec");
my $ipsec_id = $dbh->last_insert_id(undef, undef, "net_zones", undef);

$zone_insert->execute("user", "standard", undef);
my $user_standard_id = $dbh->last_insert_id(undef, undef, "net_zones", undef);

$vlan_insert->execute($tstaff_DMZ_id, 32, "128.148.32.0/25", undef);
$vlan_insert->execute($tstaff_private_id, 192, "192.168.1.0/24", undef);
$vlan_insert->execute($tstaff_private_id, 898, "10.116.0.0/16", "ilab network");
$vlan_insert->execute($tstaff_standard_id, 31, "128.148.31.0/24", undef);
$vlan_insert->execute($tstaff_standard_id, 33, "128.148.33.0/24", undef);
$vlan_insert->execute($tstaff_standard_id, 37, "128.148.37.0/24", undef);
$vlan_insert->execute($tstaff_standard_id, 38, "128.148.38.0/24", undef);
$vlan_insert->execute($user_DMZ_id, 892, "128.148.32.128/25", undef);
$vlan_insert->execute($cs166_id, 893, "192.168.100.0/24", undef);
$vlan_insert->execute($outside_id, 34, "128.148.34.0/24", undef);
$vlan_insert->execute($jj_id, 698, "198.7.242.32/28", undef);
$vlan_insert->execute($techhouse_id, 360, "138.16.60.0/24", undef);
$vlan_insert->execute($user_standard_id, 36, "128.148.36.0/24", undef);
$vlan_insert->execute($ipsec_id, 885, "10.117.0.0/16", undef);

$dbh->commit;

$dbh->disconnect or die "Can't disconnect from database: $DBI::errstr\n";

