package BrownCS::udb::Net;

use 5.010000;
use strict;
use warnings;

use BrownCS::udb::Console qw(:all);
use BrownCS::udb::Util qw(:all);

use Exporter qw(import);

our @EXPORT_OK = qw(
  add_interface
  add_addr
  dynamic_vlan
  dns_insert
  dns_update
  iface_port
  wall_plate_port
  monitored_vlan
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

sub add_interface {
  my $udb = shift;
  my ($device) = @_;

  my $uc = new BrownCS::udb::Console(udb => $udb);

  # retrieve any existing interfaces associated with this device
  my $iface_rs = $$device->net_interfaces;

  # retreive any existing interfaces, with an assigned mac address, but no associated IP address
  my $avail_iface_rs = $udb->resultset('NetInterfaces')->search({
      device_name => $$device->device_name,
      primary_address_id => { '=' => undef },
      master_net_interface_id => { '=' => undef },
  });

  if ($iface_rs->count == 0 || $avail_iface_rs->count != 0 || \
    $uc->confirm("Do you want to associate a new IP address with this network connection (Y/n)?", "yes")) {

    my $iface;

    my $mac_addr;
    if ($avail_iface_rs->count > 0) {
      $iface = $uc->choose_interface($$device->device_name, "available");
    } else {
      if (xen_device($$device)) {
        $iface = $$device->add_to_net_interfaces({
          device => $$device,
        });
      } else {
        $mac_addr = $uc->get_mac(); 

        $iface = $$device->add_to_net_interfaces({
          device => $$device,
          ethernet => $mac_addr,
        });
      }

      $$device->update;
    }

    my ($ipaddr, $vlan) = $uc->get_ip_and_vlan(1);

    my $monitored = 0;
    if (monitored_vlan($udb, $vlan->vlan_num)) {
      $monitored = 1;
    }

    # associate the ip address and vlan with the interface
    my $addr = $udb->resultset('NetAddresses')->create({
      vlan => $vlan,
      ipaddr => $ipaddr,
      monitored => $monitored,
      notification => 0,
    });
    
    if ($iface) {
      $addr->add_to_net_interfaces($iface);

      # if this device doesn't have a primary interface defined, then 
      # assume this will be the device's primary interface
      my $primary_iface_rs = $udb->resultset('NetInterfaces')->search({
        device_name => $$device->device_name,
        primary_address_id => { '!=' => undef },
      });
  
      if (! $primary_iface_rs->count) {
        $iface->update({
          primary_address => $addr,
        });
      }
    }

    if ($ipaddr) {
      dns_insert($udb, $$device->device_name, 'cs.brown.edu', $addr, 1);
  
      # If this is a non-virtual device, then it must be associated with a switch port
      if ($iface && ! virtual_device($$device)) {
        # get port information from the user
        my $port;
        ($port,$iface) = $uc->get_port($iface);
  
        # it's possible, if there was a conflict, that the addr could have changed
        # make sure we are still referencing the correct addr
        $addr = $udb->resultset('NetAddresses')->find($iface->primary_address_id);
  
        # associate port information with interface
        if ($port) {
          $iface->net_port($port);
          $iface->update;
        }
  
        if ($port and (! grep { $_ = $vlan } $port->net_vlans)) {
          $port->add_to_net_vlans($vlan);
        }
      }
    }
  } else {
    print "\n----------------------- WARNING ---------------------------\n";
    print "This requires that the switch and device be configured to support\n";
    print "bonded interfaces.  At the moment, udb does not take care of\n";
    print "configuring the network switch, so this must be configured in advance\n";
    print "Please talk with someone in the software group if you aren't sure what\n";
    print "this means before continuing.\n";
    print "------------------------------------------------------------\n";
    if (!$uc->confirm("Are you sure you want to continue? (y/N)", "no")) {
      exit (0);
    }

    my $mac_addr = $uc->get_mac(); 

    my $existing_iface = $uc->choose_interface($$device->device_name, "primary");

    # create the new interface
    my $iface = $$device->add_to_net_interfaces({
      device => $$device,
      ethernet => $mac_addr,
    });
    
    # associate network port with this interface
    my $port;
    ($port,$iface) = $uc->get_port($iface);
    if ($port) {
      $iface->net_port($port);
      $iface->update;
    }

    # make interface a slave to master interface
    $iface->master_net_interface_id($existing_iface->net_interface_id);
    $iface->update;

    # associate existing ip addresses with this new network interface
    my $addrs_rs = $existing_iface->net_addresses;
    while (my $addr = $addrs_rs->next) {
      $addr->add_to_net_interfaces($iface);
    }
  }
}

sub add_addr {
  my $udb = shift;
  my ($iface) = @_;

  my $uc = new BrownCS::udb::Console(udb => $udb);

  my ($ipaddr, $vlan) = $uc->get_ip_and_vlan(1);

  my $monitored = 0;
  if (monitored_vlan($udb, $vlan->vlan_num)) {
    $monitored = 1;
  }

  # associate the ip address and vlan with the interface
  my $addr = $udb->resultset('NetAddresses')->create({
    vlan => $vlan,
    ipaddr => $ipaddr,
    monitored => $monitored,
    notification => 0,
  });
    
  $addr->add_to_net_interfaces($$iface);
}

sub dynamic_vlan {
  my $udb = shift;
  my ($vlan) = @_;

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

  if (grep(/$vlan/, @dynamic_vlans)) {
    return 1;
  } else {
    return 0;
  }
}

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

sub iface_port {
  my $self = shift;
  my ($iface) = @_;
  my $port;

  my ($switch_name, $blade_num, $port_num) = "";

  # if this is an existing interface, then try and retrieve current port information
  if ($iface && $iface->net_port_id) {
    $switch_name = $iface->net_port->switch_name;
    $blade_num = $iface->net_port->blade_num;
    $port_num = $iface->net_port->port_num;

    $port = $self->udb->resultset('NetPorts')->search({
      switch_name => $switch_name,
      blade_num => $blade_num,
      port_num => $port_num,
     })->single;
  }

  return $port;
}

sub wall_plate_port {
  my $self = shift;
  my ($wall_plate) = @_;
  my $port;

  $wall_plate = uc($wall_plate);
  if ($wall_plate !~ /MR/) {
    $port = $self->udb->resultset('NetPorts')->search({
      wall_plate => $wall_plate,
      })->single;
  }

  return $port;
}

sub monitored_vlan {
  my $udb = shift;
  my ($vlan) = @_;

  # get a list of monitored vlans
  my $net_vlans_rs = $udb->resultset('NetVlans')->search({
    monitored => 't',
  });

  my @monitored_vlans;
  while (my $net_vlan = $net_vlans_rs->next) {
    push @monitored_vlans, $net_vlan->vlan_num;
  }

  if (grep(/$vlan/, @monitored_vlans)) {
    return 1;
  } else {
    return 0;
  }
}

sub verify_dns_alias {
  my ($udb, $existing_name, $region) = @_;

  return sub {
    my ($dns_alias) = @_;

    my $authoritative = 0;
    if (! $existing_name) {
      $authoritative = 1;
    }

    if ($dns_alias eq "") {
      print "ERROR: DNS alias can not be blank\n";
      return (0, undef, undef, undef);
    }

    my $uc = new BrownCS::udb::Console(udb => $udb);

    # if the aliases if fully qualified, split it up
    my ($alias, $domain) = $dns_alias =~ /([^\.]+)\.?(.*)/;
    if (! $domain) {
      $domain = 'cs.brown.edu';
    }

    my $verified;
    
    # ensure the DNS alias only contains valid characters
    ($verified, $alias) = verify_hostname($udb)->($alias);
    if (! $verified) {
      print "ERROR: DNS alias contains illegal characters\n";
      return (0, undef, undef, undef);
    }
 
    # ensure the DNS domain name only contains valid characters
    ($verified, $domain) = verify_domainname($udb)->($domain);
    if (! $verified) {
      print "ERROR: DNS domain name contains illegal characters\n";
      return (0, undef, undef, undef);
    }

    # ensure this DNS alias doesn't match a primary device name of any CS devices
    if ($domain eq 'cs.brown.edu') {
      my $device = $udb->resultset('Devices')->find($alias);
      if ($device) {
        print "\nERROR: DNS alias \"$alias\" conflicts with a device of the same name.\n";
        return (0, undef, undef, undef);
      }
    } 

    # determine if any other hosts currently have this DNS alias
    my $net_dns_entries_rs = $udb->resultset('NetDnsEntries')->search({
      'dns_name' => {'=', $alias},
      'domain' => {'=', $domain},
    });

    # if this new alias is being associated with an existing dns alias (i.e. we are creating a
    # CNAME), then make sure no other DNS entries exist.  DNS does not support round robins via
    # CNAMEs and this will cause bind to fail.
    if ($net_dns_entries_rs->count && $existing_name) {
      if ($net_dns_entries_rs->count == 1 && $region !~ /all/ && $net_dns_entries_rs->single->dns_region !~ /$region/) {
        return (1, $alias, $domain, $authoritative);
      } else {
        print "\nERROR: You are trying to create a DNS CNAME, with a name that already exists.\n";
        print "DNS does not support round robins via CNAMEs.\n";
        return (0, undef, undef, undef);
      }
    }

    # warn user if this name is already in use and confirm they want to setup a DNS round robin
    my $adding_to_existing_round_robin = 0;
    if ($net_dns_entries_rs->count) {
      # walk through the existing entries check for conflicts
      while (my $net_dns_entry = $net_dns_entries_rs->next) {
        # all existing entries must be authoritative
        if (! $net_dns_entry->authoritative) {
          print "\nERROR: You are trying to create an A record, with a name that is already used\n";
          print "as a CNAME.  You must choose a different DNS alias name\n";   
          return (0, undef, undef, undef);
        }

        # if the region is all and any of the existing entries aren't all
        if ($region =~ /all/ && $net_dns_entry->dns_region->dns_region !~ /all/) {
          print "\nERROR: One or more of these entries has a DNS region specified.  You are trying\n";
          print "to place this entry in all regions which will conflict.\n";
          return(0, undef, undef, undef);
        }

        # if another entry exists in the same DNS region, warn user this will create a DNS round robin
        if ($net_dns_entry->dns_region->dns_region =~ /$region/) {
          $adding_to_existing_round_robin = 1;
        }
      }

      if ($adding_to_existing_round_robin) {
        print "Adding this alias will create a DNS round robin\n";
        if (! $uc->confirm("\nAre you sure you want to enter another DNS alias (y/N)?",'n')) {
          return (0, undef, undef, undef);
        }
      }
    }

    return (1, $alias, $domain, $authoritative);
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

    my $uc = new BrownCS::udb::Console(udb => $udb);

    my $netaddr_ip = $udb->resultset('NetAddresses')->search({
        ipaddr => $ipaddr,
      })->single;

    if ($netaddr_ip) {
      print "\nIP address $ipaddr is already in use, which should only happen\n";
      print "in one of two situations:\n\n";
      print "1) You are creating an additional A record pointing to an existing\n";
      print "   ip address, (i.e. a DNS round robin)\n";
      print "2) You are creating a bonded network interface\n\n";
      print "If neither of these are true or you don't know what this means\n";
      print "then please don't continue with this operation\n\n";
      
      if (!$uc->confirm("Are you sure you want to continue? (y/N)", "no")) {
        return(0, undef);
      }
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
      print "\nInvalid IP address: $netaddr_ip is not on a recognized subnet.\n";
      return (0, undef);
    }

    # if this is a dynamic vlan, make sure static ip doesn't fall within DHCP
    # range.
    if (dynamic_vlan($udb, $vlan->vlan_num)) {
      my $dhcp_start_ip = new NetAddr::IP ($vlan->dynamic_dhcp_start);
      my $dhcp_end_ip = new NetAddr::IP ($vlan->dynamic_dhcp_end);
      if ($netaddr_ip > $dhcp_start_ip && $netaddr_ip < $dhcp_end_ip) {
        print "\nIP address falls within dynamic DHCP range.\n";
        return(0, undef);
      }
    }

    return (1, $ipaddr, $vlan);
  };
}

sub verify_ip_or_vlan {
  my $udb = shift;

  return sub {
    my ($ip_or_vlan_str) = @_;

    if (! $ip_or_vlan_str) {
      my $net_zones_rs = $udb->resultset('NetZones');
      my %net_zones;
      while (my $net_zone = $net_zones_rs->next) {
        $net_zones{$net_zone->zone_name} = $net_zone->description;
      }      

      print "ERROR: IP address or VLAN must be specified.  If you are unsure of\n"; 
      print "the VLAN to select, these descriptions might help:\n\n";
      my $net_vlans_rs = $udb->resultset('NetVlans');
      print "VLAN\t\tNetwork\t\tDescription\n";
      print "------------------------------------------------\n";
      while (my $vlan = $net_vlans_rs->next) {
        my $network = sprintf("%18s", $vlan->network);
        print $vlan->vlan_num . "\t" . $network . "\t" . $net_zones{$vlan->zone_name} . "\n";
      }
      print "\n";
      return (0, undef);
    }

    if ($ip_or_vlan_str =~ /\./) {
      # we got an IP address
      return verify_ip($udb)->($ip_or_vlan_str);
    }

    # we got a VLAN

    my $ipaddr;
    my $vlan_num = $ip_or_vlan_str;

    # check to make sure it is a valid vlan
    my $vlan = $udb->resultset('NetVlans')->search({
        vlan_num => $vlan_num,
      })->single;

    if (not $vlan) {
      print "Invalid VLAN: $vlan_num!\n";
      return (0, undef);
    }

    # assign it a ip address if it's not dynamic
    if (! dynamic_vlan($udb, $vlan_num)) {
      $ipaddr = BrownCS::udb::Util::find_unused_ip($udb, $vlan);
    }

    return (1, $ipaddr, $vlan);
  };
}

sub verify_mac {
  my $udb = shift;
  my ($iface) = @_;

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
      my $iface_tmp = $udb->resultset('NetInterfaces')->search({
        ethernet => $mac_str,
      })->single;

      if (($iface_tmp && !$iface) || ($iface_tmp && $iface && $iface->ethernet ne $iface_tmp->ethernet)) {
        print "Ethernet address \"$mac_str\" already associated with device \"" . $iface_tmp->device_name . "\"\n";
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

  my @msg = ("----------------------- WARNING ---------------------------");
  push @msg, "";
  if ($primary_vlan && $primary_vlan != $native_vlan && ! dynamic_vlan($udb, $native_vlan)) {
    push @msg, "* The primary VLAN of this device's interface is $primary_vlan while";
    push @msg, "the switch port's native VLAN is $native_vlan.  If continue, this";
    push @msg, "interface will not be able to netboot";
    push @msg, "";
  }

  if (! @other_vlans && (@vlans > 1 || (($primary_vlan && $primary_vlan != $native_vlan) && ! dynamic_vlan($udb, $native_vlan)))) {
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
    my ($wall_plate) = @_;
    $wall_plate = uc($wall_plate);

    if ($wall_plate =~ /^MR$/ ) {
      return (1, $wall_plate);
    } elsif ($wall_plate =~ /^\d\d\d\w?(-\d+)?-(D\d+|\d\w)$/ ) {
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
