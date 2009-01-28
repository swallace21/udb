#!/usr/bin/perl -w

use strict;
use DBI;

my $dbname = "udb";
#print "importing equip...\n";
my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=db", 'aleks', 'NohR0kei')
	or die "Couldn't connect to database: " . DBI->errstr;

my $sth = $dbh->prepare("DELETE FROM equipment;");
$sth->execute;
$sth->finish;

my $DBFILE = "/u/system/admin/inventory/pc.db";
open(DBFILE, $DBFILE) or die "Couldn't open $DBFILE.";
while (my $line = <DBFILE>) {
  my $equip_name = $line;
  chomp($equip_name);
  my $description = <DBFILE>;
  chomp($description);
  my $brown_inv_no = <DBFILE>;
  chomp($brown_inv_no);
  my $upgrade_serial_no = <DBFILE>;
  chomp($upgrade_serial_no);
  my $serial_no = <DBFILE>;
  chomp($serial_no);
  my $upgrade_po_no = <DBFILE>;
  chomp($upgrade_po_no);
  my $po_no = <DBFILE>;
  chomp($po_no);
  my $po_remarks_1 = <DBFILE>;
  chomp($po_remarks_1);
  my $po_remarks_2 = <DBFILE>;
  chomp($po_remarks_2);
  my $purchase_date = <DBFILE>;
  chomp($purchase_date);
  my $purchase_date_remarks_1 = <DBFILE>;
  chomp($purchase_date_remarks_1);
  my $purchase_date_remarks_2 = <DBFILE>;
  chomp($purchase_date_remarks_2);
  my $ethernet_addr = <DBFILE>;
  chomp($ethernet_addr);
  my $installation_date = <DBFILE>;
  chomp($installation_date);
  my $installation_date_remarks_1 = <DBFILE>;
  chomp($installation_date_remarks_1);
  my $installation_date_remarks_2 = <DBFILE>;
  chomp($installation_date_remarks_2);
  my $location = <DBFILE>;
  chomp($location);
  my $configuration = <DBFILE>;
  chomp($configuration);
  my $config_remarks = <DBFILE>;
  chomp($config_remarks);
  my $wall_plate = <DBFILE>;
  chomp($wall_plate);
  my $type = <DBFILE>;
  chomp($type);
  my $users = <DBFILE>;
  chomp($users);
  my $blank = <DBFILE>;
  chomp($blank);

  print "$equip_name\n";

  # my $fields;
  # my $values;

  # $fields .= "dns_name, ";
  # $values .= $dbh->quote($hostname) . ", ";
  # $fields .= "domain, ";
  # $values .= $dbh->quote("intranet") . ", ";
  # if($ipaddr) {
  #   $fields .= "ipaddr, ";
  #   $values .= $dbh->quote($ipaddr) . ", ";
  # }
  # if($ethernet) {
  #   $fields .= "ethernet, ";
  #   $values .= $dbh->quote($ethernet) . ", ";
  # }
  # $fields .= "wall_plate, ";
  # $values .= $dbh->quote(undef) . ", ";
  # $fields .= "ssh_hostkey, ";
  # $values .= $dbh->quote(undef) . ", ";
  # $fields .= "status, ";
  # if($status eq "active") {
  #   $status = "trusted"; }
  # if($status eq "special") {
  #   $status = "monitored"; }
  # if(($netgroup eq "dynamic") or ($subnet eq "36")) {
  #   $status = "untrusted"; }
  # $values .= $dbh->quote($status) . ", ";
  # if($comment) {
  #   $fields .= "comments, ";
  #   $values .= $dbh->quote($comment) . ", ";
  # }
# #    $fields .= "mxhost, ";
# #    $values .= $dbh->quote($mxhost) . ", ";
  # $fields .= "netboot, ";
  # $values .= $dbh->quote($netgroup) . ", ";
  # $fields .= "last_changed";
  # $values .= "now()";

  # print "importing cdb $hostname";

  # my $sth = $dbh->prepare("INSERT INTO equipment (equi_name,) VALUES ($values)");
  # $sth->execute();
  # $sth->finish;

}

$dbh->disconnect || die "Can't disconnect from database: $DBI::errstr\n";

