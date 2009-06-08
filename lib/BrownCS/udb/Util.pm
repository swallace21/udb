package BrownCS::udb::Util;

use 5.010000;
use strict;
use warnings;

use Exporter qw(import);
use Net::MAC;
use NetAddr::IP;

our @EXPORT_OK = qw(
  bool2str
  str2bool
  def_msg
  find_unused_ip
  fmt_time
  get_date
  get_host_class_map
  ipv4_n2x
	verify_blade
  verify_device_name
  verify_ip_or_vlan
  verify_mac
  verify_nonempty
	verify_port_num
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

sub verify_ip {
  my $udb = shift;
  # TODO: check that value is not in use
  return sub {
    my ($ipaddr) = @_;

    my $netaddr_ip = new NetAddr::IP ($ipaddr);
    if (not $netaddr_ip) {
      print "Invalid IP address: $netaddr_ip!\n";
      return (0, undef);
    }

    my $vlan = $udb->resultset('NetVlans')->search({
        network => {'>>', $ipaddr},
      })->single;

    if (not $vlan) {
      print "Invalid IP address: $netaddr_ip is not on a recognized subnet.\n";
      return (0, undef);
    }

    return (1, $ipaddr, $vlan);
  };
}

sub verify_ip_or_vlan {
  my $udb = shift;
  # TODO: check that value is not in use
  return sub {
    my ($ip_or_vlan_str) = @_;

    return (0, undef) if not $ip_or_vlan_str;

    if ($ip_or_vlan_str =~ /\./) {
      # we got an IP address
      return verify_ip($udb)->($ip_or_vlan_str);
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
