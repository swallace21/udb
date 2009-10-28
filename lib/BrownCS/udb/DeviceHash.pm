package BrownCS::udb::DeviceHash;
use Moose;

use BrownCS::udb::Util qw(:all);

has 'udb' => ( is => 'ro', isa => 'BrownCS::udb::Schema', required => 1 );

sub format_generic {
  my $self = shift;
  my ($arg) = @_;
  my $out = {};
  $out->{"Something"} = $arg->something;
  return $out;
}

# TODO collect all IPs, all aliases
sub format_device {
  my $self = shift;
  my ($device) = @_;
  my $out = {};
  $out->{"Name"} = $device->device_name;
  $out->{"Location"} = $self->format_location($device->place);
  $out->{"Status"} = $device->status->equip_status_type;
  $out->{"Usage"} = $device->usage->equip_usage_type;
  $out->{"Managed by"} = $device->manager->management_type;
  $out->{"Purchase date"} = $device->purchased_on;
  $out->{"Install date"} = $device->installed_on;
  $out->{"Brown inv number"} = $device->brown_inv_num;
  $out->{"Serial number"} = $device->serial_num;
  $out->{"Purchase order"} = $device->po_num;
  $out->{"Contact"} = $device->contact;
  $out->{"Owner"} = $device->owner;
  $out->{"Protected"} = bool2str($device->protected);
  $out->{"Comments"} = $device->comments;
  if ($device->computer) {
    $self->format_computer($out, $device->computer);
    $self->format_sysinfo($out, $device->comp_sysinfo);
  } elsif ($device->net_switch) {
    $self->format_switch($out, $device->net_switch);
  }
  my $ifaces = [];
  foreach my $iface ($device->net_interfaces) {
    push @$ifaces, $self->format_interface($iface);
  }
  $out->{"Interfaces"} = $ifaces;
  return $out;
}

sub format_computer {
  my $self = shift;
  my ($out, $comp) = @_;
  $out->{"OS"} = ($comp->os_type and $comp->os_type->os_type);
  $out->{"PXE link"} = $comp->pxelink;
  @{$out->{"Classes"}} = $comp->comp_classes->get_column("name")->all;
}

sub format_sysinfo {
  my $self = shift;
  my ($out, $sysinfo) = @_;
  if ($sysinfo) {
    $out->{"CPUs"} = $sysinfo->num_cpus;
    $out->{"CPU type"} = $sysinfo->cpu_type;
    $out->{"CPU speed"} = $sysinfo->cpu_speed;
    $out->{"Memory"} = $sysinfo->memory;
    $out->{"Hard drives"} = $sysinfo->hard_drives;
    $out->{"Video cards"} = $sysinfo->video_cards;
    $out->{"Last updated"} = $sysinfo->last_updated;
  }
}

sub format_switch {
  my $self = shift;
  my ($out, $switch) = @_;
  $out->{"Switch"} = "me on";
}

sub format_location {
  my $self = shift;
  my ($place) = @_;
  my $out = {};
  if ($place) {
    $out->{"City"} = $place->city;
    $out->{"Building"} = $place->building;
    $out->{"Room"} = $place->room;
    $out->{"Description"} = $place->description;
  }
  return $out;
}

sub format_interface {
  my $self = shift;
  my ($iface) = @_;
  my $out = {};
  $out->{"ID"} = $iface->net_interface_id;
  $out->{"MAC address"} = $iface->ethernet;
  if ($iface->primary_address) {
    $out->{"Primary address"} = $self->format_address_short($iface->primary_address);
  }
  my $addrs_rs = $iface->net_addresses;
  my $addrs = [];
  while (my $addr = $addrs_rs->next) {
    if (!$iface->primary_address || $addr->net_address_id ne $iface->primary_address->net_address_id) {
      push @$addrs, $self->format_address_short($addr);
    }
  }
  $out->{"Other Addresses"} = $addrs;
  if ($iface->net_port) {
    my $port_out = $self->format_port($iface->net_port);
    $out->{$_} = $port_out->{$_} for keys %{$port_out};
  }
  return $out;
}

sub format_port {
  my $self = shift;
  my ($port) = @_;
  my $out = {};
  $out->{"Switch"} = $port->net_switch->device_name;
  $out->{"Blade"} = $port->blade_num;
  $out->{"Port"} = $port->port_num;
  $out->{"Wall plate"} = $port->wall_plate;
  return $out;
}

sub format_address_short {
  my $self = shift;
  my ($addr) = @_;
  my $out = {};
  if ($addr->ipaddr) {
    $out->{"IP"} = $addr->ipaddr . " (";
    # collect DNS names and associated zones
    my $dns_entries_rs = $self->udb->resultset('NetDnsEntries')->search({
      net_address_id => $addr->net_address_id,
      });
    while (my $dns_entry = $dns_entries_rs->next) {
      $out->{"IP"} .= " " . $dns_entry->dns_name . ":" . $dns_entry->dns_region->dns_region;
    }
    $out->{"IP"} .= " )";
    if ($addr->monitored) {
      $out->{"IP"} .= " - monitored ";
      if ($addr->notification) {
        $out->{"IP"} .= "with notifications";
      } else {
        $out->{"IP"} .= "without notifications";
      }
    }
  } else {
    $out->{"Dynamic IP on VLAN"} = $addr->vlan_num;
  }
  return $out;
}

sub format_address {
  my $self = shift;
  my ($arg) = @_;
  my $out = {};
  $out->{"IP address"} = $arg->ipaddr;
  $out->{"Zone"} = $arg->zone->zone_name;
  $out->{"VLAN"} = $arg->vlan_num;
  $out->{"Enabled"} = bool2str($arg->enabled);
  $out->{"Monitored"} = bool2str($arg->monitored);
  my $dns = [];
  foreach my $entry ($arg->net_dns_entries) {
    push @$dns, $self->format_dns_entry($entry);
  }
  $out->{"DNS"} = $dns;
  return $out;
}

sub format_dns_entry {
  my $self = shift;
  my ($arg) = @_;
  my $out = {};
  $out->{"Name"} = $arg->dns_name . "." . $arg->domain;
  $out->{"DNS region"} = $arg->dns_region->dns_region;
  $out->{"Authoritative"} = bool2str($arg->authoritative);
  return $out;
}

sub format_surplus {
  my $self = shift;
  my ($device) = @_;
  my $out = {};
  $out->{"Surplus date"} = $device->surplus_date;
  $out->{"Purchase date"} = $device->purchased_on;
  $out->{"Install date"} = $device->installed_on;
  $out->{"Hostname"} = $device->name;
  $out->{"Buyer"} = $device->buyer;
  $out->{"Brown inv number"} = $device->brown_inv_num;
  $out->{"Serial number"} = $device->serial_num;
  $out->{"Purchase order"} = $device->po_num;
  $out->{"Comments"} = $device->comments;
  return $out;
}

# TODO collect all IPs, all aliases
sub update_device {
  my $self = shift;
  my ($device, $in) = @_;

  $device->update({
      device_name => $in->{"Name"},
      status => $in->{"Status"},
      usage => $in->{"Usage"},
      manager => $in->{"Managed by"},
      purchased_on => $in->{"Purchase date"},
      installed_on => $in->{"Install date"},
      brown_inv_num => $in->{"Brown inv number"},
      serial_num => $in->{"Serial number"},
      po_num => $in->{"Purchase order"},
      contact => $in->{"Contact"},
      owner => $in->{"Owner"},
      protected => $in->{"Protected"},
      comments => $in->{"Comments"},
    });

  if ($device->computer) {
    $self->update_computer($device->computer, $in);
  } elsif ($device->net_switch) {
    $self->update_switch($device->net_switch, $in);
  }

  $self->update_location($device, $in->{"Location"});

  my $ifaces = {};
  foreach my $iface_hash (@{$in->{"Interfaces"}}) {
    my $iface = $device->related_resultset('net_interfaces')->find($iface_hash->{'ID'});
    $ifaces->{$iface_hash->{"ID"}} = $self->update_interface($iface, $iface_hash);
  }
  foreach my $iface ($device->net_interfaces) {
    if (not grep { $_->{"ID"} == $iface->net_interface_id } (@{$in->{"Interfaces"}})) {
      $device->remove_from_net_interfaces($iface);
    }
  }
  $in->{"Interfaces"} = $ifaces;
  $device->update;
}

sub update_computer {
  my $self = shift;
  my ($comp, $in) = @_;

  $comp->update({
      os_type => $in->{"OS"},
      pxelink => $in->{"PXE link"},
    });

  $self->update_classes($comp, $in->{"Classes"});
}

sub update_classes {
  my $self = shift;
  my ($comp, $classes_ref) = @_;

  $self->udb->resultset('CompClassesComputers')->search({
      device_name => $comp->device_name,
    })->delete;

  if ($classes_ref) {
    foreach my $class_name (@$classes_ref) {
      my $class = $self->udb->resultset('CompClasses')->find_or_create({
          name => $class_name,
          os_type => $comp->os_type,
        });
      $comp->add_to_comp_classes($class);
    }
  }
}

sub update_switch {
  my $self = shift;
  my ($switch, $in) = @_;
  #$in->{"Switch"} = "me on";
  $switch->update;
}

sub update_location {
  my $self = shift;
  my ($device, $in) = @_;
  my $place = $self->udb->resultset('Places')->find_or_create({
      city => $in->{"City"},
      building => $in->{"Building"},
      room => $in->{"Room"},
    });
  $device->place($place);
  $device->update;
}

sub update_interface {
  my $self = shift;
  my ($iface, $in) = @_;
  $iface->ethernet($in->{"MAC address"});
  if ($in->{"Primary IP"}) {
    my $ver = verify_ip_or_vlan($self->udb);
    my $new_ip = $in->{"Primary IP"};
    my ($ignore_this, $ip_addr, $vlan) = $ver->($new_ip);
    my $new_primary_addr = $self->udb->resultset('NetAddresses')->find_or_create({
        ipaddr => $ip_addr,
        vlan => $vlan,
      });
    $iface->primary_address($new_primary_addr);
  }
  #if ($iface->net_port) {
  #  my $port = $iface->net_port;
  #  $in->{"Switch"} = $port->net_switch->device_name;
  #  $in->{"Blade"} = $port->blade_num;
  #  $in->{"Port"} = $port->port_num;
  #  $in->{"Wall plate"} = $port->wall_plate;
  #}
  $iface->update;
}

sub update_address {
  my $self = shift;
  my ($addr, $in) = @_;
  #$in->{"IP address"} = $arg->ipaddr;
  #$in->{"Zone"} = $arg->zone->zone_name;
  #$in->{"VLAN"} = $arg->vlan_num;
  #$in->{"Enabled"} = bool2str($arg->enabled);
  #$in->{"Monitored"} = bool2str($arg->monitored);
  #my $dns = [];
  #foreach my $entry ($arg->net_dns_entries) {
  #  push @$dns, $self->update_dns_entry($entry);
  #}
  #$in->{"DNS"} = $dns;
  $addr->update;
}

sub update_dns_entry {
  my $self = shift;
  my ($entry, $in) = @_;

  my ($dns_name, $domain);
  if ($in->{"Name"} =~ /([a-z0-9\-\_]+)\.(.+)/) {
    $dns_name = $1;
    $domain = $2;
  }

  $entry->update({
      dns_name => $dns_name,
      domain => $domain,
      dns_region => $in->{"DNS region"},
      authoritative => $in->{"Authoritative"},
    });
  $entry->update;
}

sub update_surplus {
  my $self = shift;
  my ($device, $in) = @_;
  $device->update({
      surplus_date => $in->{"Surplus date"},
      purchased_on => $in->{"Purchase date"},
      installed_on => $in->{"Install date"},
      name => $in->{"Hostname"},
      buyer => $in->{"Buyer"},
      brown_inv_num => $in->{"Brown inv number"},
      serial_num => $in->{"Serial number"},
      po_num => $in->{"Purchase order"},
      comments => $in->{"Comments"},
    });
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

BrownCS::udb::DeviceHash - utility functions

=head1 SYNOPSIS

  use BrownCS::DeviceHash qw(:all);

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
