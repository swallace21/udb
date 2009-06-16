package BrownCS::udb::Net;

use 5.010000;
use strict;
use warnings;

use BrownCS::udb::Console qw(:all);

use Exporter qw(import);

our @EXPORT_OK = qw(
  verify_dns_alias
	verify_dns_region
  verify_ip
);

our %EXPORT_TAGS = ("all" => [@EXPORT_OK]);

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
  # TODO: check that value is not in use
  return sub {
    my ($ipaddr) = @_;

print "ipaddr: $ipaddr\n";
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
