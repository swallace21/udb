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
  $out->{"Primary user"} = $device->contact;
  $out->{"Owner"} = $device->owner;
  $out->{"Comments"} = $device->comments;
  if ($device->computer) {
    $self->format_computer($out, $device->computer);
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
  $out->{"CPUs"} = $comp->num_cpus;
  $out->{"CPU type"} = $comp->cpu_type;
  $out->{"CPU speed"} = $comp->cpu_speed;
  $out->{"Memory"} = $comp->memory;
  $out->{"Hard drives"} = $comp->hard_drives;
  $out->{"Video cards"} = $comp->video_cards;
  $out->{"Last updated"} = $comp->last_updated;
  @{$out->{"Classes"}} = $comp->comp_classes->get_column("name")->all;
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
  }
  return $out;
}

sub format_interface {
  my $self = shift;
  my ($iface) = @_;
  my $out = {};
  $out->{"MAC address"} = $iface->ethernet;
  if ($iface->primary_address) {
    $out->{"Primary IP"} = $iface->primary_address->ipaddr;
  }
  if ($iface->net_port) {
    my $port = $iface->net_port;
    $out->{"Switch"} = $port->net_switch->device_name;
    $out->{"Blade"} = $port->blade_num;
    $out->{"Port"} = $port->port_num;
    $out->{"Wall plate"} = $port->wall_plate;
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
      contact => $in->{"Primary user"},
      owner => $in->{"Owner"},
      comments => $in->{"Comments"},
    });

  if ($device->computer) {
    $self->update_computer($device->computer, $in);
  } elsif ($device->net_switch) {
    $self->update_switch($device->net_switch, $in);
  }

  $self->update_location($device, $in->{"Location"});

  #my $ifaces = [];
  #foreach my $iface ($in->{"Interfaces"}) {
  #  $self->update_interface(
  #  push @$ifaces, $self->update_interface($iface);
  #}
  #$in->{"Interfaces"} = $ifaces;
  $device->update;
}

sub update_computer {
  my $self = shift;
  my ($comp, $in) = @_;

  $comp->update({
      os_type => $in->{"OS"},
      pxelink => $in->{"PXE link"},
      num_cpus => $in->{"CPUs"},
      cpu_type => $in->{"CPU type"},
      cpu_speed => $in->{"CPU speed"},
      memory => $in->{"Memory"},
      hard_drives => $in->{"Hard drives"},
      video_cards => $in->{"Video cards"},
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
  #$in->{"MAC address"} = $iface->ethernet;
  #if ($iface->primary_address) {
  #  $in->{"Primary IP"} = $iface->primary_address->ipaddr;
  #}
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
      authoritative => str2bool($in->{"Authoritative"}),
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