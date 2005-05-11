#!/usr/bin/perl -w

#use strict;
use DBI;
use Getopt::Std;
use vars qw($opt_d $opt_v);

require '/u/system/lib/cdb_data.pl';

my $dbname = "udb";
getopts('d:v');
if($opt_d) {
$dbname = $opt_d;
}
print "importing cdb...\n";
my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=db", 'tstaff', 'pr0bl3m')
	or die "Couldn't connect to database: " . DBI->errstr;

my $sth = $dbh->prepare("DELETE FROM aliases; DELETE FROM net_service; DELETE FROM netobj;");
$sth->execute;
$sth->finish;

my($key, $data);
while ( ($key, $data) = each(%$cdb_by_hostname) ) {
    &insert_host($data);
}

$dbh->disconnect || die "Can't disconnect from database: $DBI::errstr\n";

sub insert_host {
    my($host) = @_;


    my $hostname = $host->{'hostname'};
    my $netgroup = $host->{'prim_grp'};
    my $os_type = $host->{'os_type'};
    my $mxhost = $host->{'mxhost'};
    my $ipaddr = $host->{'ip_addr'};
    my $subnet = (split(/\./, $ipaddr))[2];
    my $comment = $host->{'comment'};
    my $hw_arch = $host->{'hw_arch'};
    my $ethernet = $host->{'ethernet'};
    my $status = $host->{'status'};
    $host->{'aliases'} =~ s/\s//g;
    my @aliases = split(/,/, $host->{'aliases'});
    $host->{'supp_grps'} =~ s/\s//g;
    my @sup_groups = split(/,/, $host->{'supp_grps'});
    $host->{'classes'} =~ s/\s//g;
    my @classes = split(/,/, $host->{'classes'});
    my $contact = $host->{'contact'};
    my $expertise = $host->{'expertise'};
    
    my $fields;
    my $values;

    $fields .= "dns_name, ";
    $values .= $dbh->quote($hostname) . ", ";
    $fields .= "domain, ";
    $values .= $dbh->quote("intranet") . ", ";
    if($ipaddr) {
      $fields .= "ipaddr, ";
      $values .= $dbh->quote($ipaddr) . ", ";
    }
    if($ethernet) {
      $fields .= "ethernet, ";
      $values .= $dbh->quote($ethernet) . ", ";
    }
    $fields .= "wall_plate, ";
    $values .= $dbh->quote(undef) . ", ";
    $fields .= "ssh_hostkey, ";
    $values .= $dbh->quote(undef) . ", ";
    $fields .= "status, ";
    if($status eq "active") {
      $status = "trusted"; }
    if($status eq "special") {
      $status = "monitored"; }
    if(($netgroup eq "dynamic") or ($subnet eq "36")) {
      $status = "untrusted"; }
    $values .= $dbh->quote($status) . ", ";
    if($comment) {
      $fields .= "comments, ";
      $values .= $dbh->quote($comment) . ", ";
    }
    $fields .= "mxhost, ";
    $values .= $dbh->quote($mxhost) . ", ";
    $fields .= "netboot, ";
    $values .= $dbh->quote($netgroup) . ", ";
    $fields .= "dirty";
    $values .= $dbh->quote("changed");

    if($opt_v) { print "importing cdb $hostname"; }
    my $sth = $dbh->prepare("INSERT INTO netobj ($fields) VALUES ($values)");
    $sth->execute();
    $sth->finish;


    if ( $#aliases != -1 ) {
    	foreach (@aliases) {
        if($opt_v) { print ", alias $_"; }
	      $sth = $dbh->prepare("INSERT INTO aliases (alias, dns_name, domain, status, dirty) VALUES (?,?,?,?,?)");
        $sth->execute($_, $hostname, "intranet", "trusted", "changed");
        $sth->finish;
    	}
    }

    if ( $#classes != -1 ) {
    	foreach (@classes) {
        if($opt_v) { print ", class $_"; }
        create_class($_);
	      $sth = $dbh->prepare("INSERT INTO net_service (dns_name, domain, class) VALUES (?,?,?)");
        $sth->execute($hostname, "intranet", $_);
        $sth->finish;
    	}
    }

    if($opt_v) { print "\n"; }
}

sub create_class {
  my $sth = $dbh->prepare("SELECT * from classes where class = ?");
  $sth->execute($_);

  if ($sth->rows == 0) {
    my $sth_create = $dbh->prepare("INSERT INTO classes (class) VALUES (?)");
    $sth_create->execute($_);
    $sth_create->finish;
  }
    $sth->finish;
}

