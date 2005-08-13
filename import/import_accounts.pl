#!/usr/local/bin/perl -w

use strict;
use DBI;
use Getopt::Std;
use vars qw($opt_d $opt_v);

sub trimwhitespace($);

my $passwd_file = "/maytag/sys0/NIS/src/passwd.NEW";
my $group_file = "/maytag/sys0/NIS/src/group";
my $usage_file = "/maytag/sys0/NIS/src/usage.byID";
my $identity_file = "/maytag/sys0/NIS/src/identity";
my $dbname = "udb";
getopts('d:v');
if($opt_d) {
$dbname = $opt_d;
}
print "importing accounts...\n";
my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=db", 'tstaff', 'pr0bl3m')
	or die "Couldn't connect to database: " . DBI->errstr;

my $sth = $dbh->prepare("
DELETE FROM group_list;
DELETE FROM identity_list;
DELETE FROM identities;
DELETE FROM accounts;
DELETE FROM groups;
DELETE FROM people;
");
$sth->execute;
$sth->finish;
  
open(INPUT, "<$group_file") or die("Couldn't open file: $group_file");

while(<INPUT>) {

	chomp($_);
	if ($_ eq "") {next;}

	my @list = split /:/,	$_;

	if($opt_v){ print "adding group: $list[0] \tgid: $list[2]\n";}

	my $sth_create = $dbh->prepare("INSERT INTO groups (group_name, gid) VALUES (?, ?)");
	$sth_create->execute($list[0], $list[2]);
	$sth_create->finish;
}

close(INPUT);
open(INPUT, "<$passwd_file") or die("Couldn't open file: $passwd_file");

while(<INPUT>) {

	chomp($_);
	if ($_ eq "") {next;}

	my @list = split /:/,	$_;
	my @info = split /,/,	$list[4];

	if($opt_v){ print "adding account: $list[0]\n"; }

	my $sth = $dbh->prepare("SELECT nextval FROM nextval('person_id_seq')");
	$sth->execute;
	my $row = $sth->fetchrow_hashref;
	my $person_id = $row->{nextval};
	$sth->finish;	

	$sth = $dbh->prepare("INSERT INTO people (person_id, full_name, office, office_phone, home_phone) VALUES (?,?,?,?,?)");
	$sth->execute($person_id, $info[0], $info[1], $info[2], $info[3]);
	$sth->finish;
	
	if($info[0] =~ m/(\w+)\s(.*)\s(\w+)/) {
		$sth = $dbh->prepare("UPDATE people SET first_name=?,middle_name=?,last_name=? WHERE person_id=?");
		$sth->execute($1,$2,$3,$person_id);
		$sth->finish;
	}
	elsif($info[0] =~ m/(\w+)\s(\w+)/) {
		$sth = $dbh->prepare("UPDATE people SET first_name=?,last_name=? WHERE person_id=?");
		$sth->execute($1,$2,$person_id);
		$sth->finish;
	}

	$sth = $dbh->prepare("INSERT INTO accounts (uid, person_id, login, gid, shell, home_dir, last_changed) VALUES (?, ?, ?, ?, ?, ?, now())");
	$sth->execute($list[2], $person_id, $list[0], $list[3], $list[6], $list[5]);
	$sth->finish;
}
close(INPUT);
open(INPUT, "<$group_file") or die("Couldn't open file: $group_file");

while(<INPUT>) {

        chomp($_);
	if ($_ eq "") {next;}

        my @list = split /:/,   $_;
	if (!defined($list[3])) {next;}
	my @grplst = split /,/,   $list[3];

	foreach (@grplst) {

		if($opt_v){ print "adding login $_ to group $list[0]\n"; }
		my $sth = $dbh->prepare("INSERT INTO group_list (group_name, login) VALUES (?, ?)");
        	$sth->execute($list[0], trimwhitespace($_));
        	$sth->finish;
	}
}
close(INPUT);
open(INPUT, "<$usage_file") or die("Couldn't open file: $usage_file");

while(<INPUT>) {

        chomp($_);
        if ($_ eq "") {next;}
        my @list = split /:/,   $_;
        if (!defined($list[1])) {next;}

        if($opt_v){ print "adding identity $list[0]:$list[1]\n"; }
        my $sth = $dbh->prepare("INSERT INTO identities (identity, space) VALUES (?,?)");
        $sth->execute($list[0], $list[1]);
        $sth->finish;
}
close(INPUT);
open(INPUT, "<$identity_file") or die("Couldn't open file: $identity_file");

while(<INPUT>) {

        chomp($_);
        if ($_ eq "") {next;}

        my @list = split /:/,   $_;
        if (!defined($list[1])) {next;}
        my @identities = split /,/,   $list[1];

        foreach (@identities) {

                if($opt_v){ print "adding identity $_ to login $list[0]\n"; }
                my $sth = $dbh->prepare("INSERT INTO identity_list (identity, login) VALUES(?,?)");
                $sth->execute(trimwhitespace($_),trimwhitespace($list[0]));
                $sth->finish;
        }
}
close(INPUT);

$dbh->disconnect || die "Can't disconnect from database: $DBI::errstr\n";


sub trimwhitespace($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
