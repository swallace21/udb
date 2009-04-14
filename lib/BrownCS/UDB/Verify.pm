package BrownCS::UDB::Verify;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(
  verify_hostname verify_mac verify_ip_or_vlan verify_walljack
  );

use Net::MAC;
use NetAddr::IP;

use BrownCS::UDB::Util qw(:all);

# TODO: check that value is not in use

sub verify_hostname {
  my $udb = shift;
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

