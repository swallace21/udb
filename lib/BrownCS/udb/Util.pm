package BrownCS::udb::Util;

use 5.010000;
use strict;
use warnings;

use Exporter qw(import);
use Net::MAC;
use NetAddr::IP;
#use BrownCS::udb::Net qw(:all);

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
  ipv4_n2x
  verify_unprotected
	verify_blade
  verify_device_name
  verify_ip_or_vlan
  verify_mac
  verify_nonempty
	verify_port_num
  verify_port
  verify_switch
  verify_walljack
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

sub verify_nonempty {
  my ($answer) = @_;
  if ((defined $answer) and ($answer ne '')) {
    return (1, $answer);
  } else {
    return (0, undef);
  }
}

sub verify_device_name {
	my $udb = shift;
	return sub {
  	my($device, $verbose) = @_;

		if ($verbose) {
			print "Ensuring all device names are lowercase\n";
		}
  	$device = lc($device);
  	if($device !~ /^[a-z0-9]([a-z0-9\-\_]{0,253}[a-z0-9])?$/) {
    	return (0, $device);
  	}

  	return (1, $device);
	};
}

sub verify_mac {
  my $udb = shift;
  # TODO: check that value is not in use
  return sub {
    my ($mac_str) = @_;
    my $mac;
    eval {
      $mac = Net::MAC->new('mac' => $mac_str);
    };
    if ($@) {
      return (0, undef);
    } else {
      return (1, $mac_str);
    }
  };
}

sub verify_switch {
	my $udb = shift;
	return sub {
		my ($switch) = @_;
    if ($udb->resultset('NetSwitches')->find($switch)) {
			return (1, $switch);
		} else {
			return (0, undef);
		}
	}
}

sub verify_blade {
	my $udb = shift;
	my ($switch) = @_;
	return sub {
		my ($blade_num) = @_;
		my $num_blades = $udb->resultset('NetSwitches')->find($switch)->num_blades;
		if (1 <= $blade_num && $blade_num <= $num_blades) {
			return (1, $blade_num);
		} else {
			return (0, undef);
		}
	}
}

sub verify_port_num {
	my $udb = shift;
	my ($switch) = @_;
	return sub {
		my ($port_num) = @_;
		my $num_ports = $udb->resultset('NetSwitches')->find($switch)->num_ports;
		if (1 <= $port_num && $port_num <= $num_ports) {
			return (1, $port_num);
		} else {
			return (0, undef);
		}
	}
}

sub verify_port {
  print "check to make sure specified port isn't already in use\n";
}

#sub verify_ip {
#  my $udb = shift;
#  # TODO: check that value is not in use
#  return sub {
#    my ($ipaddr) = @_;
#
#    my $netaddr_ip = new NetAddr::IP ($ipaddr);
#    if (not $netaddr_ip) {
#      print "Invalid IP address: $netaddr_ip!\n";
#      return (0, undef);
#    }
#
#    my $vlan = $udb->resultset('NetVlans')->search({
#        network => {'>>', $ipaddr},
#      })->single;
#
#    if (not $vlan) {
#      print "Invalid IP address: $netaddr_ip is not on a recognized subnet.\n";
#      return (0, undef);
#    }
#
#    return (1, $ipaddr, $vlan);
#  };
#}

sub verify_ip_or_vlan {
  my $udb = shift;
  # TODO: check that value is not in use
  return sub {
    my ($ip_or_vlan_str) = @_;

    return (0, undef) if not $ip_or_vlan_str;

    if ($ip_or_vlan_str =~ /\./) {
      # we got an IP address
      return BrownCS::udb::Net::verify_ip($udb)->($ip_or_vlan_str);
    }

    # we got a VLAN

    my $dynamic = 0;
    my $vlan_num = $ip_or_vlan_str;
    my $ipaddr;

    if (($ip_or_vlan_str =~ /^d(\d+)$/) or
      ($ip_or_vlan_str =~ /^(\d+)d$/)) {
      # we got a dynamic vlan
      $dynamic = 1;
      $vlan_num = $1;
    } elsif ($ip_or_vlan_str =~ /^(\d+)$/) {
      $vlan_num = $1;
    } else {
      return (0, undef);
    }

    my $vlan = $udb->resultset('NetVlans')->search({
        vlan_num => $vlan_num,
      })->single;

    if (not $vlan) {
      print "Invalid VLAN: $vlan_num!\n";
      return (0, undef);
    }

    if (not $dynamic) {
      $ipaddr = find_unused_ip($udb, $vlan);
    }

    return (1, $ipaddr, $vlan);
  };
}

sub verify_walljack {
  my $udb = shift;
  return sub {
    my ($walljack_str) = @_;
    my $walljack = $udb->resultset('NetPorts')->search({
        wall_plate => $walljack_str,
      })->single;
    return ($walljack ? (1, $walljack) : (0, undef));
  };
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

  if(system("klist -5 2> /dev/null | grep '/admin' -q")) {
       print "Warning: You do not have Kerberos admin credentials.\n";
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
