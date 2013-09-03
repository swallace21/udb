package BrownCS::udb::Search;

use 5.010000;
use strict;
use warnings;

use Switch;
use BrownCS::udb::Console qw(:all);

use Exporter qw(import);

our @EXPORT_OK = qw(
  search_brown_id
  search_class
  search_comment
  search_contact
  search_device
  search_dns
  search_ethernet
  search_os_type
  search_po
  search_room
  search_serial
  search_ssh_known_hosts
  search_spare
  search_usage
  search_walljack
);

our %EXPORT_TAGS = ("all" => [@EXPORT_OK]);

sub fuzzy_search {
  my $udb = shift;
  my ($table, $key, $value, $verbose) = @_;

  my $rs = $udb->resultset($table)->search({
    $key => $value,
  });

  if (!$rs->count) {
    if ($verbose) {
      print "No exact match, trying fuzzy search...\n";
    }
    $rs = $udb->resultset($table)->search({
      $key => { '~*' => $value },
    });
  }

  my @results;

  # sort out relevant items to return, based on table name
  switch($table) {
    case 'Devices' { 
      while (my $device = $rs->next) { 
        my $device_name = $device->device_name;
        if (! grep(/^$device_name$/,@results)) {
          push @results, $device->device_name;
        }
      }
    }

    case 'SurplusDevices' {
      while (my $device = $rs->next) {
        my $device_name = $device->device_name;
        if (! grep(/^$device_name$/,@results)) {
          push @results, $device->device_name;
        }
      }
    }

    case 'Computers' {
      while (my $comp = $rs->next) {
        my $name = $comp->device_name;
        if (! grep(/^$name$/, @results)) {
          my $additional_info = "";
          if ($comp->os_type) {
            $additional_info = " (" . $comp->os_type->os_type . ")";
          }
          push @results, $comp->device_name . $additional_info;
        }
      }
    }

    case 'NetDnsEntries' {
      while (my $net_dns_entry = $rs->next) {
        my $device_name;
        if ($net_dns_entry->net_address->net_interfaces->single) {
          $device_name = $net_dns_entry->net_address->net_interfaces->single->device->device_name;
          if (! grep(/^$device_name$/, @results)) {
            push @results, $net_dns_entry->net_address->net_interfaces->single->device->device_name;
          }
        } else {
          $device_name = $net_dns_entry->dns_name;
          if (! grep(/^$device_name$/, @results)) {
            push @results, $net_dns_entry->dns_name;
          }
        }
      }
    }
  }      

  return(@results);
}

sub search_class {
  my $udb = shift;
  return sub {
    my ($class, $verbose) = @_;

    my $comp_classes_rs = $udb->resultset('CompClasses')->search({
      name => $class,
    });

    my @results = (); 
    while (my $comp_classes = $comp_classes_rs->next) {
      my $comp_classes_computers_rs = $comp_classes->comp_classes_computers;
      while (my $comp_classes_computers = $comp_classes_computers_rs->next) {
        push @results, $comp_classes_computers->device_name;
      } 
    }
    
    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_brown_id {
  my $udb = shift;
  return sub {
    my ($id, $surplus, $verbose) = @_;

    my @results = fuzzy_search($udb, 'Devices', 'brown_inv_num', $id, $verbose);

    if ($surplus) {
      push @results, fuzzy_search($udb, 'SurplusDevices', 'brown_inv_num', $id, $verbose);
    }

    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_comment {
  my $udb = shift;
  return sub {
    my ($comment, $surplus, $verbose) = @_;

    my @results = fuzzy_search($udb, 'Devices', 'comments', $comment, $verbose);

    if ($surplus) {
      push @results, fuzzy_search($udb, 'SurplusDevices', 'comments', $comment, $verbose);
    }

    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_contact {
  my $udb = shift;
  return sub {
    my ($contact, $verbose) = @_;

    my @results = fuzzy_search($udb, 'Devices', 'contact', $contact, $verbose);

    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_device {
  my $udb = shift;
  return sub {
    my ($name, $surplus, $verbose) = @_;

    my @results = fuzzy_search($udb, 'Devices', 'device_name', $name, $verbose);

    if ($surplus) {
      push @results, fuzzy_search($udb, 'SurplusDevices', 'device_name', $name, $verbose);
    }

    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_dns {
  my $udb = shift;
  return sub {
    my ($name, $verbose) = @_;

    my @results = fuzzy_search($udb, 'NetDnsEntries', 'dns_name', $name, $verbose);

    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_os_type {
  my $udb = shift;
  return sub {
    my ($os_type, $verbose) = @_;

    my @results = fuzzy_search($udb, 'Computers', 'os_type', $os_type, $verbose);
    
    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_po {
  my $udb = shift;
  return sub {
    my ($po, $surplus, $verbose) = @_;

    my @results = fuzzy_search($udb, 'Devices', 'po_num', $po, $verbose);

    if ($surplus) {
      push @results, fuzzy_search($udb, 'SurplusDevices', 'po_num', $po, $verbose);
    }

    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_room {
  my $udb = shift;
  return sub {
    my ($room, $verbose) = @_;

    my $places_rs = $udb->resultset('Places')->search({
      room => $room,
    });
    
    if ($places_rs->count) {
      my @results;
      while (my $place = $places_rs->next) {
        my $devices_rs = $udb->resultset('Devices')->search ({
          place_id => $place->place_id,
        });
        while (my $device = $devices_rs->next) {
          if (! grep(/$device->device_name/, @results)) {
            push @results, $device->device_name;
          }
        }
      }
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_serial {
  my $udb = shift;
  return sub {
    my ($serial, $surplus, $verbose) = @_;

    my @results = fuzzy_search($udb, 'Devices', 'serial_num', $serial, $verbose);

    if ($surplus) {
      push @results, fuzzy_search($udb, 'SurplusDevices', 'serial_num', $serial, $verbose);
    }

    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_spare {
  my $udb = shift;
  return sub {
    my ($verbose) = @_;

    my $devices_rs = $udb->resultset('Devices')->search({
      status => 'spare',
    });

    my @results;

    while (my $device = $devices_rs->next) {
      my $room = "";

      if ($device->place->room) {
        $room = " (room: " . $device->place->room . ")";
      }

      push @results, $device->device_name . $room;
    }

    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_ssh_known_hosts {
  my $udb = shift;
  return sub {
    my ($verbose) = @_;
    my @results;

    # this should really be a join!
    my $devices_rs = $udb->resultset('Devices')->search ({
      manager => 'tstaff' ,
      status => 'deployed',
    });

    while (my $device = $devices_rs->next) {
      if ($device->computer) {
        my $os_type;

        if ($device->computer->os_type) {
          $os_type = $device->computer->os_type->os_type;
        }
          
        if ($os_type && ($os_type =~ /debian/ || $os_type =~ /centos/)) {
          push @results, $device->device_name;
        }
      }
    }

    my $dns_entries_rs = $udb->resultset('NetDnsEntries');

    while (my $dns_entry = $dns_entries_rs->next) {
      if ($dns_entry->net_address->monitored) {
        my $host = $dns_entry->dns_name;
        if (! grep(/$host/, @results)) {
          my $device = $udb->resultset('Devices')->find($host);
          if (!$device || ($device && $device->computer && $device->computer->os_type && (
            $device->computer->os_type->os_type =~ /debian/ ||
            $device->computer->os_type->os_type =~ /centos/))) {
            push @results, $dns_entry->dns_name;
          }
        }
      }
    }
    
    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_usage {
  my $udb = shift;
  return sub {
    my ($usage, $verbose) = @_;

    my @results = fuzzy_search($udb, 'Devices', 'usage', $usage, $verbose);

    if (@results) {
      return (1, @results);
    } else {
      return (0, undef);
    }
  };
}

sub search_walljack {
  my $udb = shift;

  return sub {
    my ($walljack, $verbose) = @_;

    # wall plates are always uppercase
    $walljack = uc($walljack);

    my $net_ports_rs = $udb->resultset('NetPorts')->search ({
      wall_plate => $walljack,
    });

    if (!$net_ports_rs->count) {
      if ($verbose) {
        print "No exact match, trying fuzzy search...\n";
      }
      $net_ports_rs = $udb->resultset('NetPorts')->search({
        wall_plate => { '~*' => $walljack },
      });
    }

    if ($net_ports_rs->count) {
      my @results;

      while (my $net_port = $net_ports_rs->next) {
        push @results, "\nWalljack " . $net_port->wall_plate . " is connected to\n";
        push @results, "  Switch: " . $net_port->switch_name;
        push @results, "  Blade: " . $net_port->blade_num;
        push @results, "  Port: " . $net_port->port_num . "\n";
        push @results, "The following hosts are attached to this port:\n";

        my $port_name = $net_port->wall_plate;
        foreach my $iface ($net_port->net_interfaces) {
          my $device_name = $iface->device_name;
          if (! grep(/$device_name/, @results)) {
            push @results, "  " . $iface->device_name;
          }
        }
      }

      if (@results) {
        return (1, @results);
      }
    }

    return (0, undef);
  }
}

sub search_ethernet {
  my $udb = shift;

  return sub {
    my ($ethernet, $verbose) = @_;

    my $ifaces_rs = $udb->resultset('NetInterfaces')->search({
      ethernet => $ethernet,
    });

    if ($ifaces_rs->count) {
      my @results;

      while (my $iface = $ifaces_rs->next) {
        push @results, $iface->device_name;
      }

      if (@results) {
        return (1, @results);
      }
    }

    return (0, undef);
  };
}

1;

__END__

=head1 NAME

BrownCS::udb::Search - search functions

=head1 SYNOPSIS

  use BrownCS::Search qw(:all);

=head1 DESCRIPTION

Common search functions

=head1 AUTHOR

Mark Dieterich.

=head1 SEE ALSO

B<udb>(1), B<perl>(1)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 Brown University. All rights reserved.

For now, this is "all rights reserved" since it is of no use outside
of the CS Department.  If you think of some use, let us know.

=cut
