package BrownCS::udb::Util;

use 5.010000;
use strict;
use warnings;

use Exporter qw(import);
use Net::MAC;
use NetAddr::IP;

our @EXPORT_OK = qw(
  bool
  find_unused_ip
  fmt_time
  get_date
  get_host_class_map
  ipv4_n2x
  verify_hostname
  verify_ip_or_vlan
  verify_mac
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

sub bool {
  my ($bool) = @_;
  return $bool ? "yes" : "no";
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

sub verify_hostname {
  my $udb = shift;
  # TODO: check that value is not in use
  return sub {
    my($hostname) = @_;

    if($hostname !~ /^[a-zA-Z]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$/) {
      return undef;
    }

    return $hostname;
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
      return undef;
    } else {
      return $mac_str;
    }
  };
}

sub verify_ip {
  my $udb = shift;
  # TODO: check that value is not in use
  return sub {
    my ($ipaddr) = @_;

    my $netaddr_ip = new NetAddr::IP ($ipaddr);
    if (not $netaddr_ip) {
      print "Invalid IP address: $netaddr_ip!\n";
      return undef;
    }

    my $vlan = $udb->db->resultset('NetVlans')->search({
        network => {'>>', $ipaddr},
      })->single;

    if (not $vlan) {
      print "Invalid IP address: $netaddr_ip is not on a recognized subnet.\n";
      return undef;
    }

    return ($ipaddr, $vlan);
  };
}

sub verify_ip_or_vlan {
  my $udb = shift;
  # TODO: check that value is not in use
  return sub {
    my ($ip_or_vlan_str) = @_;

    if ($ip_or_vlan_str =~ /\./) {
      # we got an IP address
      my ($ipaddr, $vlan) = verify_ip($udb, $ip_or_vlan_str);
      return ($ipaddr, $vlan);
    }

    # we got a VLAN
    my $vlan = $udb->db->resultset('NetVlans')->search({
        vlan_num => $ip_or_vlan_str,
      })->single;

    if (not $vlan) {
      print "Invalid VLAN: $ip_or_vlan_str!\n";
      return undef;
    }

    my $ipaddr = $udb->find_unused_ip($vlan);
    return ($ipaddr, $vlan);
  };
}

sub verify_walljack {
  my $udb = shift;
  return sub {
    my ($walljack_str) = @_;
    my $walljack = $udb->db->resultset('NetPorts')->search({
        wall_plate => $walljack_str,
      })->single;
    return ($walljack ? $walljack : undef);
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
