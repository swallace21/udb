package BrownCS::udb::Net;

use 5.010000;
use strict;
use warnings;

use BrownCS::udb::Console qw(:all);

use Exporter qw(import);

our @EXPORT_OK = qw(
  dns_insert
  verify_dns_alias
	verify_dns_region
  verify_ip
  verify_ip_or_vlan
  verify_mac
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
