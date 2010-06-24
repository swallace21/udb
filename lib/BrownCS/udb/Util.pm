package BrownCS::udb::Util;

use 5.010000;
use strict;
use warnings;

use Exporter qw(import);
use Net::MAC;
use NetAddr::IP;
use Time::ParseDate;

our @EXPORT_OK = qw(
  bool2str
  str2bool
  def_msg
  device_exists
  dns_name_exists
  find_unused_ip
  fmt_time
  get_date
  get_host_class_map
  host_is_trusted
  ipv4_n2x
  log
  verify_domainname
  verify_equip_usage_types
  verify_hostname
  verify_nonempty
  verify_unprotected
  verify_username
  virtual_device
);

our %EXPORT_TAGS = ("all" => [@EXPORT_OK]);

# get_date :: ???
# Return current date using nice format
sub get_date {
  my(@elems);
  my($raw);

  chop($raw = localtime(time));
  @elems = split(/\s+/, $raw);
  return $elems[2] . $elems[1] . substr($elems[4], -2);
}

# fmt_time :: ???
# Return specified time using nice format
sub fmt_time {
  my($time) = @_;
  my($sec, $min, $hour, $mday, $mon, $year) = localtime($time);

  my(@moname) = ( 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' );

  return "${mday}${moname[$mon]}${year} ${hour}:${min}:${sec}";
}

sub bool2str {
  my ($bool) = @_;
  return $bool ? "yes" : "no";
}

sub str2bool {
  my ($str) = @_;
  if ($str =~ /y(es)?/i) {
    return 1;
  } elsif ($str =~ /t(rue)?/i) {
    return 1;
  } elsif ($str =~ /n(o)?/i) {
    return 0;
  } elsif ($str =~ /f(alse)?/i) {
    return 0;
  } else {
    die "Don't know how to coerce '$str' into a bool.\n";
  }
}

sub def_msg {
  my ($str) = @_;
  return $str ? $str : "<blank>";
}

sub device_exists {
  my ($udb, $name) = @_;

  my $uc = new BrownCS::udb::Console(udb => $udb);

  my $device = $udb->resultset('Devices')->find($name);
  if (! $device) {
    return 0;
  }

  if ($device->protected) {
    printf("The device %s is protected!\n", $device->device_name);
    print "Do not modify or delete this entry unless you know what you're doing.\n";
    if (! $uc->confirm("Are you sure (y/n)?")) {
      return 0;
    }
  }
 
  return 1;

}

sub dns_name_exists {
  my ($udb, $name) = @_;

  my $net_dns_entry = $udb->resultset('NetDnsEntries')->search({
    dns_name => {'=', $name},
  });

  my $records = $net_dns_entry->count;

  if ($records) {
    return $records;
  } else {
    return 0;
  }
}

sub host_is_trusted {
  my ($host) = @_;

  if (($host->device->manager->management_type eq 'tstaff') || ($host->os_type && $host->os_type->trusted_nfs)) {
    return 1;
  } else {
    return 0;
  }
}

sub ipv4_n2x {
  my ($ipaddr_n) = @_;
  $ipaddr_n =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
  my $ipaddr_x = sprintf("%0.2X%0.2X%0.2X%0.2X", $1, $2, $3, $4);
  return $ipaddr_x;
}

sub get_host_class_map {
  my ($udb) = @_;

  my $hash = {};

  my $rs = $udb->resultset('CompClassesComputers')->search({},
    {
      prefetch => ['computer', 'comp_class'],
      include_columns => ['comp_class.name'],
    });

  while (my $item = $rs->next) {
    my $name = $item->computer->device_name;
    if (not defined @{$hash->{$name}}) {
      $hash->{$name} = [];
    }
    push @{$hash->{$name}}, $item->comp_class->name;
  }

  return $hash;
}

sub find_unused_ip {
  my ($udb, $vlan) = @_;

  my($subnet) = new NetAddr::IP ($vlan->network);

  my(%ip_addrs) = ();

  # Build hash of used IP addresses to avoid

  my $all_ips = $udb->resultset('NetAddresses');;

  while (my $ip = $all_ips->next) {
    if ($ip->ipaddr) {
      $ip_addrs{$ip->ipaddr} = 1;
    }
  }

  # Skip the broadcast, gateway, and network addresses
  $ip_addrs{$subnet->broadcast} = 1;
  $ip_addrs{$subnet->network} = 1;
  $ip_addrs{$vlan->gateway} = 1;

  my $ip_end = $subnet;
  my $ip_iterator = $ip_end;

  while ((++$ip_iterator) != $ip_end) {
    my $ip_addr_test = $ip_iterator->addr;
    next if(defined($ip_addrs{$ip_addr_test}));
    return $ip_addr_test;
  }

  die "No addresses are available for the $subnet subnet.\n";
}

sub log {
  my ($msg) = @_;
  my $date = get_date;
  my $logfile = "/tstaff/share/udb/log/$date";

  use File::NFSLock;
  use Fcntl qw(LOCK_EX LOCK_NB);

  use Date::Format;
  my $now = time2str("%T", time);

  if (my $lock = new File::NFSLock {
    file => $logfile,
    lock_type => LOCK_EX|LOCK_NB,
    blocking_timeout => 10,
    stale_lock_timeout => 30 * 60,
  }) {
    open(LOGFILE, ">> $logfile") || die "ERROR: can't open log file: $!";
    $lock->uncache;

    print LOGFILE "$now [$$]: $msg\n";

    close(LOGFILE);
    $lock->unlock();
  } else {
    die "ERROR: unable to lock log file: $!\n";
  }
}

sub verify_unprotected {
  my $udb = shift;
  
	return sub {
    my $uc = new BrownCS::udb::Console(udb => $udb);
    my $device = $udb->device;

    if ($device->protected) {
      printf("The device %s is protected!\n", $device->device_name);
      print "Do not modify or delete this entry unless you know what you're doing.\n";
      if (! $uc->confirm("Are you sure (y/n)?")) {
        return 0;
      }
    }
    return 1;
  }  
}

sub verify_username {
  my ($input_username) = @_;
  if (not $input_username) {
    return (0, undef);
  }
  my $retval = system("getent passwd $input_username > /dev/null 2> /dev/null");
  if ($retval == 0) {
    return (1, $input_username);
  } else {
    return (0, undef);
  }
}

sub verify_nonempty {
  my ($answer) = @_;
  if ((defined $answer) and ($answer ne '')) {
    return (1, $answer);
  } else {
    return (0, undef);
  }
}

sub verify_domainname {
	my $udb = shift;
	return sub {
  	my($domainname, $verbose) = @_;

		if ($verbose) {
			print "Ensuring all domain names are lowercase\n";
		}
  	$domainname = lc($domainname);
  	if($domainname !~ /^[a-z0-9]([a-z0-9\-\.]{0,253}[a-z0-9])?$/) {
    	return (0, $domainname);
  	}

  	return (1, $domainname);
	};
}

sub verify_equip_usage_types {
  my $udb = shift;
  return sub {
    my ($equip_usage_type, $verbose) = @_;

    my $equip_usage_types_rs = $udb->resultset('EquipUsageTypes');
    my %equip_usage_types;
    while (my $type = $equip_usage_types_rs->next) {
      $equip_usage_types{$type->equip_usage_type} =  $type->description;
    }

    if (! $equip_usage_type || ! $equip_usage_types{$equip_usage_type}) {
      print "ERROR: Uknown equipment usage type.  It must be one of:\n\n";
      print "Type      Description\n";
      print "----------------------------\n";
      foreach my $key (keys(%equip_usage_types)) {
        printf "%-10s%s\n", $key, $equip_usage_types{$key};
      }
      print "\n";
      return (0, undef);
    }

    return (1, $equip_usage_type);
  };
}

sub verify_hostname {
	my $udb = shift;
	return sub {
  	my($hostname, $verbose) = @_;

		if ($verbose) {
			print "Ensuring all hostnames names are lowercase\n";
		}
  	$hostname = lc($hostname);
  	if($hostname !~ /^[a-z0-9]([a-z0-9\-]{0,253}[a-z0-9])?$/) {
    	return (0, $hostname);
  	}

  	return (1, $hostname);
	};
}

sub virtual_device {
  my ($device) = @_;

  if ($device->usage && $device->usage->equip_usage_type =~ /virtual/) {
    return 1;
  } else {
    return 0;
  }
}

sub okay_adminhost {
  my $self = shift;
  
  use Sys::Hostname;
  my $hostname = hostname();
  chomp($hostname);
  if($hostname ne 'adminhost') {
    print "Warning: You are not on adminhost.\n";
    return 0;
  }
  return 1;
}

sub okay_kerberos {
  my $self = shift;

  my $now = time;

  my $credentials = 0;
  open(KLIST, "/usr/bin/klist -5 |") || die "ERROR: can't run klist\n";
  
  my $expiration;
  while(<KLIST>) {
    if (/Default principal:.*\/admin\@CS\.BROWN\.EDU/) {
      $credentials = 1;
    }
    if (/krbtgt\/CS\.BROWN\.EDU\@CS\.BROWN\.EDU/) {
      ($expiration) = /\d+\/\d+\/\d+\s+\d+:\d+:\d+\s+(\d+\/\d+\/\d+\s+\d+:\d+:\d+)\s+krbtgt.*/;
    }
  }
  $expiration = parsedate($expiration);

  if (! $credentials) {
    print "ERROR: You do not have Kerberos admin credentials.\n";
    print "Please run kinit to get new admin credentials.\n";
    return 0;
  }

  if ($now > $expiration) {
    print "ERROR: Your Kerberos admin credentials are expired.\n";
    print "Please run kinit to get new admin credentials.\n";
    return 0;
  }

  return 1;
}

sub okay_root {
  my $self = shift;

  if ($> != 0) {
    print "Warning: You are not root.\n";
    return 0;
  }
  return 1;
}

sub okay_root_silent {
  my $self = shift;

  if ($> != 0) {
    return 0;
  }
  return 1;
}

sub okay_sudo {
  my $self = shift;

  unless (okay_root_silent && $ENV{'SUID_USER'}){
    print "WARNING: Please logout and run with sudo.\n";
    return 0;
  }
  return 1;
}

sub okay_tstaff_user {
  my $self = shift;

  my @groupinf = getgrnam("tstaff");
  my $user = getlogin || getpwuid($<);
  if((!$user) || $groupinf[3] !~ /\b$user\b/){
    print "Sorry, you're not in tstaff.\n";
    return 0;
  }
  return 1;
}

sub okay_tstaff_machine {
  my $self = shift;

  use Sys::Hostname;
  my $hostname = hostname();
  $hostname = $hostname . ".cs.brown.edu";

  my @machines = `netgroup tstaff`;
  my $host;
  foreach $host (@machines) {
    chomp($host);
    if ($host eq $hostname) {
      return 1;
    }
  }
  if (okay_adminhost()){
    return 1;
  }
  print "Sorry, this is not a tstaff machine.\n";
  return 0;
}

sub okay_tstaff {
  my $self = shift;

  my $privs;
  $privs += okay_tstaff_machine;
  $privs += okay_tstaff_user;
  if($privs == 2){
    return 1;
  }
  return 0;
}

sub okay_to_build {
  my $privs = 0;

  $privs += okay_kerberos();
  $privs += okay_root();
  $privs += okay_adminhost();

  if ($privs != 3) {
    print "Sorry, can't build. Check the warnings.\n";
    return 0;
  } else {
    return 1;
  }
}

1;
__END__

=head1 NAME

BrownCS::udb::Util - utility functions

=head1 SYNOPSIS

  use BrownCS::Util qw(:all);

=head1 DESCRIPTION

Utility functions which are useful for the udb library and helper
programs.

=head1 AUTHOR

Aleks Bromfield.

=head1 SEE ALSO

B<udb>(1), B<perl>(1)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 Brown University. All rights reserved.

For now, this is "all rights reserved" since it is of no use outside
of the CS Department.  If you think of some use, let us know.

=cut
