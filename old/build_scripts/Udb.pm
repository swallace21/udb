#!/usr/local/bin/perl -w

# $Id$

package Udb;

use strict;
use DBI;

sub new {
    my($type) = shift;
    my($dbh, $r);

#    $dbh = DBI->connect("dbi:Pg:dbname=udb;host=db", 'twh', 'changeme');
    $dbh = DBI->connect("dbi:Pg:dbname=udb", 'twh', 'changeme');
    $dbh || die "Can't connect to data base: $DBI::errstr\n";
    $dbh->{AutoCommit} = 0;
    $r->{dbh} = $dbh;
    $r->{print} = 0;
    bless $r, $type;
}

sub close {
    my($r) = shift;
    $r->{dbh}->disconnect
      || die "Can't disconnect from database: $DBI::errstr\n";
}

sub commit {
    my($r) = shift;
    $r->{dbh}->commit;
}

sub rollback {
    my($r) = shift;
    $r->{dbh}->rollback;
}

#
# To use:
#
# my($result) = $db->select("SELECT foo FROM bar");
# if ( !$result ) {
#     die "error\n";
# }
# if ( $#{$result} == -1 ) {
#    print "no matches\n";
# }
# foreach $row ( @{$result} ) {
#    $foo = $row->[0];
# }
#
sub select {
    my($r, $cmd) = @_;
    my($sth, $rv);

    if ( $r->{print} ) {
	print $cmd, "\n";
    }
    $sth = $r->{dbh}->prepare($cmd);
    if ( !$sth ) {
	warn $r->{dbh}->errstr, "\n";
	return undef;
    }
    $rv = $sth->execute;
    if ( !$rv ) {
	warn $sth->errstr, "\n";
	return undef;
    }
    $sth->fetchall_arrayref;
}

sub do {
    my($r, $cmd) = @_;
    my($sth, $rc);

    if ( $r->{print} ) {
	print $cmd, "\n";
    }
    $rc = $r->{dbh}->do($cmd);
    if ( !$rc ) {
	warn $r->{dbh}->errstr, "\n";
	return undef;
    }
    $rc;
}

sub create_id {
    my($r) = shift;

    my(@result) = $r->select("SELECT NEXTVAL('equipment_id_seq')");
    if ( $#result != 0 ) {
	return undef;
    }
    $result[0]->[0]->[0];
}

sub create_nid {
    my($r) = shift;

    my(@result) = $r->select("SELECT NEXTVAL('network_nid_seq')");
    if ( $#result != 0 ) {
	return undef;
    }
    $result[0]->[0]->[0];
}

sub quote {
    my($r, $st) = @_;

    if ( !$st ) {
	return 'NULL';
    }
    if ( $st eq '' ) {
	return 'NULL';
    }
    $r->{dbh}->quote($st);

}

sub has_entry {
    my($r, $id, $table) = @_;
    my(@result) = $r->select("SELECT * FROM $table WHERE id = '$id'");
    if ( $#result == -1 ) {
	0;
    }
    else {
	1;
    }
}

sub set_print {
    my($r, $val) = @_;
    $r->{print}= $val;
}

1;
