package BrownCS::udb::Net;

use 5.010000;
use strict;
use warnings;

use BrownCS::udb::Console qw(:all);

use Exporter qw(import);

our @EXPORT_OK = qw(
  dns_insert
  dns_update
  verify_dns_alias
  verify_dns_region
  verify_ip
  verify_ip_or_vlan
  verify_mac
  verify_blade
  verify_port_num
  verify_switch
  verify_port_iface
  verify_wall_plate
);

our %EXPORT_TAGS = ("all" => [@EXPORT_OK]);

sub dns_insert {
  my $udb = shift;
  my ($name, $domain, $addr, $auth, $region) = @_;

  if (! $region) {
    # query the database to determine which vlans are private.
    # by default, those vlans that are private are not given DNS
    # entries on the external servers
    my $private_vlans_rs = $udb->resultset('NetVlans')->search({
      private => 't',
    });
    my @private_vlans = ();
    while (my $private_vlan = $private_vlans_rs->next) {
      push @private_vlans, $private_vlan->vlan_num;
    }

    my $vlan = $addr->vlan_num;
    my $device = $udb->resultset('Devices')->find($name);
    if (grep(/$vlan/, @private_vlans) || ! ($device->usage->equip_usage_type =~ /tstaff/ || $device->usage->equip_usage_type =~ /server/ || $device->usage->equip_usage_type =~ /virtual/)) {
      $region = "internal";
    } else {
      $region = "all";
    }
  }

  $udb->resultset('NetDnsEntries')->find_or_create({
    dns_name => $name,
    domain => $domain,
    net_address => $addr,
    authoritative => $auth,
    dns_region => $region,
  });
}

sub dns_update{
  my $udb = shift;
  my ($old_addr, $new_addr) = @_;
}  

sub verify_dns_alias {
  my $udb = shift;
  return sub {
    my ($dns_alias) = @_;

    if ($dns_alias eq "") {
      print "ERROR: DNS alias can not be blank\n";
      return (0, undef);
    }

    my $uc = new BrownCS::udb::Console(udb => $udb);

    # if the aliases if fully qualified, split it up
    my ($alias, $domain) = $dns_alias =~ /([^\.]+)\.?(.*)/;
    if (! $domain) {
      $domain = 'cs.brown.edu';
    }

    # ensure this DNS alias doesn't match a primary device name of any CS devices
    if ($domain eq 'cs.brown.edu') {
      my $device = $udb->resultset('Devices')->find($alias);
      if ($device) {
        print "\nERROR: DNS alias \"$alias\" conflicts with a device of the same name.\n";
        return (0, undef);
      }
    } 

    # determine if any other hosts currently have this DNS alias
    my $net_dns_entries_rs = $udb->resultset('NetDnsEntries')->search({
      dns_name => {'=', $alias},
      domain => {'=', $domain},
    });

    # warn user if this name is already in use and confirm they want to setup a DNS round robin
    if ($net_dns_entries_rs->count) {
      print "This DNS alias is already associated with the following\n";
      print "IP addresses (devices):\n\n";
      while (my $net_dns_entry = $net_dns_entries_rs->next) {
        my $ipaddr = $net_dns_entry->net_address->ipaddr;
        my $device = "";
        if ($net_dns_entry->net_address->net_interfaces->single) {
          $device .= " (";
          $device .= $net_dns_entry->net_address->net_interfaces->single->device->device_name;
          $device .= ")";
        }
   
        my $region = $net_dns_entry->dns_region->dns_region;
        print "IP: $ipaddr$device, DNS Region: $region\n";
      }
      if (! $uc->confirm("\nAre you sure you want to enter another DNS alias (y/N)?",'n')) {
        return (0, undef, undef);
      }
    }

    return (1, $alias, $domain);
  }
}

sub verify_dns_region {
  my $udb = shift;
  return sub {
    my ($region) = @_;
    if ($udb->resultset('DnsRegions')->find($region)) {
      return(1, $region);
    } else {
      return(0, undef);
    }
  };
}

sub verify_ip {
  my $udb = shift;

  return sub {
    my ($ipaddr) = @_;

    my $netaddr_ip = $udb->resultset('NetAddresses')->search({
        ipaddr => $ipaddr,
      })->single;

    if ($netaddr_ip) {
      print "\nIP address $ipaddr is already in use\n";
      return (0, undef);
    }

    $netaddr_ip = new NetAddr::IP ($ipaddr);
    if (not $netaddr_ip) {
      print "\nInvalid IP address: $netaddr_ip!\n";
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
      $ipaddr = BrownCS::udb::Util::find_unused_ip($udb, $vlan);
    }

    return (1, $ipaddr, $vlan);
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
      return (0, undef);
    } else {
      # make sure it's not already in use
      my $iface = $udb->resultset('NetInterfaces')->search({
        ethernet => $mac_str,
      })->single;

      if ($iface) {
        print "Ethernet address \"$mac_str\" already associated with device \"" . $iface->device_name . "\"\n";
        return(0, undef);
      } else {
        return (1, $mac_str);
      }
    }
  };
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

sub verify_port_iface {
  my $udb = shift;
  my ($port,$iface) = @_;

  if (!$port) {
    return 0;
  }

  my $uc = new BrownCS::udb::Console(udb => $udb);

  my $switch_name = $port->switch_name;
  my $net_switch = $udb->resultset('NetSwitches')->find($switch_name);
  my $switch = BrownCS::udb::Switch->new({
    net_switch => $net_switch,
    verbose => 0,
  });

  my $primary_vlan;
  if ($iface->primary_address_id) {
    $primary_vlan = $iface->primary_address->vlan_num;
  }

  my $addr_rs = $iface->net_addresses;
  my @vlans;
  while (my $addr = $addr_rs->next) {
      push @vlans, $addr->vlan_num;
  } 

  # determine what the native VLAN of this port is
  my ($native_vlan, @other_vlans) = $switch->get_port_vlans($port);

  # determine what, if any, other machines are connected to this port
  my (@devices) = $switch->get_port_devices($port);  

  # get a list of dynamic vlans
  my $net_zones_rs = $udb->resultset('NetZones')->search({
    dynamic_dhcp => 't',
   });
  my @dynamic_vlans;
  while (my $net_zone = $net_zones_rs->next) {
    my $net_vlans_rs = $udb->resultset('NetVlans')->search({
      zone_name => $net_zone->zone_name,
    });
    while (my $net_vlan = $net_vlans_rs->next) {
      push @dynamic_vlans, $net_vlan->vlan_num;
    }
  }

  my @msg = ("----------------------- WARNING ---------------------------");
  push @msg, "";
  if ($primary_vlan && $primary_vlan != $native_vlan && ! grep(/$native_vlan/, @dynamic_vlans)) {
    push @msg, "* The primary VLAN of this device's interface is $primary_vlan while";
    push @msg, "the switch port's native VLAN is $native_vlan.  If continue, this";
    push @msg, "interface will not be able to netboot";
    push @msg, "";
  }

  if (! @other_vlans && (@vlans > 1 || (($primary_vlan && $primary_vlan != $native_vlan) && ! grep(/$native_vlan/, @dynamic_vlans)))) {
    push @msg, "* The switch port is currently not configured to support";
    push @msg, "trunking.  Adding this interface to the switch port will";
    push @msg, "require the following hosts support trunking:";
    push @msg, "";
    foreach my $device (@devices) {
      push @msg,$device;
    }
    push @msg, "";
  }

  push @msg, "-----------------------------------------------------------";

  if (@msg > 3) {
    foreach my $msg (@msg) {
      print $msg . "\n";
    }
    my @choices = ();
    push @choices, { key => 1, name => "reassign", desc => "Automatically reassign " . $iface->device_name . " an IP address on the $native_vlan vlan"};
    push @choices, { key => 2, name => "reenter", desc => "Re-enter network information for " . $iface->device_name};
    push @choices, { key => 3, name => "trunk", desc => "Reconfigure network port for trunking"};
    push @choices, { key => 4, name => "quit", desc => "Quit"};
    my $choice = $uc->choose_from_menu("What would you like to do", \@choices);

    if ($choice =~ /quit/) {
      exit;
    } elsif ($choice =~ /reassign/) {
      my ($valid, $new_ipaddr, $new_vlan) = verify_ip_or_vlan($udb)->($native_vlan);

      # find the old network address associated with this interface
      my $old_addr = $udb->resultset('NetAddresses')->find($iface->primary_address_id);
 
      # associate this new network address with this interface
      my $new_addr = $udb->resultset('NetAddresses')->create({
        vlan => $new_vlan,
        ipaddr => $new_ipaddr,
        monitored => 0,
      });

      $new_addr->add_to_net_interfaces($iface);
      if($iface->primary_address_id) {
        $iface->update({
          primary_address => $new_addr,
        });
      }

      my $net_dns_entries_rs = $udb->resultset('NetDnsEntries')->search({
        net_address_id => $old_addr->net_address_id,
      });
      while (my $net_dns_entry = $net_dns_entries_rs->next) {
        $net_dns_entry->update({
          net_address_id => $new_addr->net_address_id,
        });
      }

      # delete the old network address associated with the interface
      $old_addr->delete;
    } elsif ($choice =~ /reenter/) {
      return (undef,$iface);
    }
  }

  return ($port, $iface);
}

sub verify_wall_plate {
  my $udb = shift;
  return sub {
    my ($wall_plate_str) = @_;
    $wall_plate_str = uc($wall_plate_str);
    my $port = $udb->resultset('NetPorts')->search({
        wall_plate => $wall_plate_str,
      })->single;

    if($port) {
      my $wall_plate = $port->wall_plate;
      return (1, $wall_plate);
    }

    return (0, undef);
  };
}

1;

__END__

=head1 NAME

BrownCS::udb::Net - network functions

=head1 SYNOPSIS

  use BrownCS::Net qw(:all);

=head1 DESCRIPTION

Network functions which are useful for the udb library and helper
programs.

=head1 AUTHOR

Mark Dieterich.

=head1 SEE ALSO

B<udb>(1), B<perl>(1)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 Brown University. All rights reserved.

For now, this is "all rights reserved" since it is of no use outside
of the CS Department.  If you think of some use, let us know.

=cut
