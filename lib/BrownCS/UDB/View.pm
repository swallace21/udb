package BrownCS::UDB::View;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(print_record format_device format_address format_surplus);

use Pod::Usage;
use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);

use BrownCS::UDB::Util qw(:all);

sub udb_sort {
  return -1 if ($a eq 'Name');
  return 1 if ($b eq 'Name');
  return 1 if ($a eq 'Comments');
  return -1 if ($b eq 'Comments');
  return $a cmp $b;
}

sub print_record {
  my ($prefix, $hash) = @_;

  foreach my $key (sort udb_sort (keys(%{$hash}))) {
    my $val = $hash->{$key};
    next if not defined $val;
    if ((ref($val) eq "ARRAY")) {
      if (scalar(@{$val}) > 0) {
        print $prefix, $key, ":\n";
        print_array(($prefix."  "), $val);
      }
    } elsif ((ref($val) eq "HASH")) {
      print $prefix, $key, ":\n";
      print_record(($prefix."  "), $val);
    } elsif ($val) {
      printf "%s%s: %s\n", $prefix, $key, $val;
    }
  }
}

sub print_array {
  my ($prefix, $array) = @_;

  foreach my $item (sort @{$array}) {

    next if not defined $item;

    if ((ref($item) eq "ARRAY")) {
      print "$prefix-\n";
      print_array(($prefix."- "), $item);
    } elsif ((ref($item) eq "HASH")) {
      print "$prefix-\n";
      print_record(($prefix."  "), $item);
    } elsif ($item) {
      printf "%s- %s\n", $prefix, $item;
    }
  }

}

sub format_generic {
  my ($arg) = @_;
  my $out = {};
  $out->{"Something"} = $arg->something;
  return $out;
}

# TODO collect all IPs, all aliases
sub format_device {
  my ($device) = @_;
  my $out = {};
  $out->{"Name"} = $device->name;
  $out->{"Location"} = format_location($device->location);
  $out->{"Status"} = $device->equip_status->name;
  $out->{"Managed by"} = $device->managed_by->name;
  $out->{"Purchase date"} = $device->purchased_on;
  $out->{"Install date"} = $device->installed_on;
  $out->{"Brown inv number"} = $device->brown_inv_num;
  $out->{"Serial number"} = $device->serial_num;
  $out->{"Purchase order"} = $device->po_num;
  $out->{"Owner"} = $device->owner;
  $out->{"Contact"} = $device->contact;
  $out->{"Comments"} = $device->comments;
  if ($device->computer) {
    format_computer($out, $device->computer);
  } elsif ($device->switch) {
    format_switch($out, $device->switch);
  }
  my $ifaces = [];
  foreach my $iface ($device->net_interfaces) {
    push @$ifaces, format_interface($iface);
  }
  $out->{"Interfaces"} = $ifaces;
  return $out;
}

sub format_computer {
  my ($out, $comp) = @_;
  $out->{"OS"} = ($comp->os and $comp->os->name);
  $out->{"PXE link"} = $comp->pxelink;
  $out->{"CPUs"} = $comp->num_cpus;
  $out->{"CPU type"} = $comp->cpu_type;
  $out->{"CPU speed"} = $comp->cpu_speed;
  $out->{"Memory"} = $comp->memory;
  $out->{"Hard drives"} = $comp->hard_drives;
  $out->{"Video cards"} = $comp->video_cards;
  $out->{"Last updated"} = $comp->last_updated;
  @{$out->{"Classes"}} = $comp->classes->get_column("name")->all;
}

sub format_switch {
  my ($out, $switch) = @_;
  $out->{"Switch"} = "me on";
}

sub format_location {
  my ($loc) = @_;
  my $out = {};
  if ($loc) {
    $out->{"City"} = $loc->city;
    $out->{"Building"} = $loc->building;
    $out->{"Room"} = $loc->room;
  }
  return $out;
}

sub format_interface {
  my ($iface) = @_;
  my $out = {};
  $out->{"MAC address"} = $iface->ethernet;
  if ($iface->primary_address) {
    $out->{"Primary IP"} = $iface->primary_address->ipaddr;
  }
  if ($iface->port) {
    my $port = $iface->port;
    $out->{"Switch"} = $port->switch->name;
    $out->{"Blade"} = $port->blade_num;
    $out->{"Port"} = $port->port_num;
    $out->{"Wall plate"} = $port->wall_plate;
  }
  return $out;
}

sub format_address {
  my ($arg) = @_;
  my $out = {};
  $out->{"IP address"} = $arg->ipaddr;
  $out->{"Zone"} = $arg->zone->name;
  $out->{"VLAN"} = $arg->vlan_num;
  $out->{"Enabled"} = bool($arg->enabled);
  $out->{"Monitored"} = bool($arg->monitored);
  my $dns = [];
  foreach my $entry ($arg->net_dns_entries) {
    push @$dns, format_dns_entry($entry);
  }
  $out->{"DNS"} = $dns;
  return $out;
}

sub format_dns_entry {
  my ($arg) = @_;
  my $out = {};
  $out->{"Name"} = $arg->dns_name . "." . $arg->domain;
  $out->{"DNS region"} = $arg->dns_region->name;
  $out->{"Authoritative"} = bool($arg->authoritative);
  return $out;
}

sub format_surplus {
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

