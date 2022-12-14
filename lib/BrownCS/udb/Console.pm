package BrownCS::udb::Console;
use Moose;

use Term::ReadKey;
use Term::ReadLine;
use File::Temp qw(tempfile);
use BrownCS::udb::Util qw(:all);
use BrownCS::udb::Net qw(:all);
use BrownCS::udb::Switch;

has 'udb' => ( is => 'ro', isa => 'BrownCS::udb::Schema', required => 1 );
has 'term' => ( is => 'ro', isa => 'Term::ReadLine' );

sub BUILD {
  my $self = shift;
  $self->{term} = new Term::ReadLine 'udb';
  $self->term->ornaments(0);
}

sub get_key {
  my $self = shift;
  ReadMode 'cbreak';
  my $key = ReadKey(0);
  ReadMode 'normal';
  if ($key ne "\n") {
    print "\n";
  }
  return $key;
}

# edit :: string -> string
# Write a string to a temporary file, let the user edit it with a text
# editor, and return the modified contents as a string.
sub edit {
  my $self = shift;
  my ($str) = @_;

  my ($fh, $filename) = tempfile(UNLINK => 1);
  print $fh $str;
  close($fh);

  my $editor = ($ENV{"EDITOR"} or "nano");
  system("$editor $filename");

  open(NEWFILE, $filename);
  my @new_lines = <NEWFILE>;
  my $new_str = join('', @new_lines);
  close(NEWFILE);

  return $new_str;
}

# ask_password :: void -> string
# Prompt the user for a password and return it.
sub ask_password {
  my $self = shift;
  print STDERR "Password: ";
  ReadMode 'noecho';
  my $password = ReadLine 0;
  chomp $password;
  ReadMode 'normal';
  print STDERR "\n";
  return $password;
}

# query :: string * string * string * (string -> boolean) -> string
# Gets a line from the user and optionally verifies/canonicalizes it.

my %QUERY_DEFAULTS = (
  prompt     => ">",
  error_str  => "Invalid answer. Please try again.",
  default    => '',
  verify_sub => sub {
    my ($ans) = @_;
    return (1, $ans);
  },
); 

sub query {
  my $self = shift;
  my ($arg_ref) = @_;
  my %args = ref $arg_ref eq 'HASH' ? (%QUERY_DEFAULTS, %{$arg_ref}): %QUERY_DEFAULTS;
  my $verify_sub = $args{verify_sub};
  while (1) {
    my $answer = $self->term->readline($args{prompt}." ");
    if (not $answer) {
      $answer = $args{default};
    }
    my ($is_valid, @canon_answer);
    eval {
      ($is_valid, @canon_answer) = &$verify_sub($answer);
    };
    if ($@) {
      print "Error: $@\n";
      print "Please try again.\n";
    } elsif ($is_valid) {
      if (wantarray()) {
        return @canon_answer;
      } elsif (scalar(@canon_answer) > 0) {
        return $canon_answer[0];
      } else {
        return undef;
      }
    } else {
      print $args{error_str}, "\n";
    }
  }
}

# confirm :: string -> boolean
# Prompt the user for yes or no and return appropriate value.
sub confirm {
  my $self = shift;
  my($prompt, $default) = @_;
  return $self->query({
      prompt => $prompt,
      error_str => "Invalid answer. Please answer yes or no (y/n).",
      default => $default,
      verify_sub => sub {
        my ($answer) = @_;
        if ($answer =~ /^y(es)?$/i) {
          (1, 1);
        } elsif ($answer =~ /^n(o)?$/i) {
          (1, 0);
        } else {
          (0, undef);
        }
      },
    });
}

# ask :: string -> string
# Gets a line from the user.
sub ask {
  my $self = shift;
  my($prompt, $default) = @_;
  return $self->query({
      prompt => $prompt,
      default => $default ? $default : '',
      verify_sub => sub {
        my ($answer) = @_;
        return (1, $answer);
      },
    });
}

# demand :: string * (string -> boolean) -> string
# Gets a line from the user and verifies it.
# If no verification procedure is supplied, then
# verifies that the input is nonempty.
sub demand {
  my $self = shift;
  my($prompt, $verify_sub) = @_;

  my $query_args = {};
  $query_args->{prompt} = $prompt;
  $query_args->{verify_sub} = $verify_sub ? $verify_sub : verify_nonempty;

  return $self->query($query_args);
}

# Checks that the answer is neither empty nor a question mark (?).
sub verify_nonempty_nonq {
  my ($answer) = @_;
  if ((defined $answer) and ($answer ne '') and ($answer ne '?')) {
    return (1, $answer);
  } else {
    return (0, undef);
  }
}

# choose :: string * [string] -> string
# Gets an answer from the user. The answer must belong to a specified
# list.
sub choose {
  my $self = shift;
  my($prompt, $choices, $default) = @_;

  my $query_args = {};
  $query_args->{prompt} = $prompt;
  if ((defined $default) and $default) {
    $query_args->{default} = $default;
  }

  my $error_str = "\nInvalid choice. Valid choices are:\n";
  foreach my $i (sort(@{$choices})) {
    $error_str .= ("  " . def_msg($i) . "\n");
  }
  chomp($error_str);
  $query_args->{error_str} = $error_str;

  $query_args->{verify_sub} = sub {
    my ($answer) = @_;
    if (not defined $answer) {
      return (0, undef);
    } elsif (grep {$_ eq $answer} @{$choices}) {
      return (1, $answer);
    } else {
      return (0, undef);
    }
  };

  return $self->query($query_args);
}

# choose_from_menu :: string * [(string * string * string)] -> string
# Gets an answer from the user. The answer must belong to a specified
# list. The user is presented with a menu of choices, and is asked to
# select one by number.
sub choose_from_menu {
  my $self = shift;
  my($prompt, $choices) = @_;

  $prompt .= "\n";
  foreach my $choice (@{$choices}) {
    $prompt .= sprintf(" [%s] %s\n", $choice->{'key'}, $choice->{'desc'});
  }

  $prompt .= "Choose an option:";

  return $self->query({
      prompt => $prompt,
      error_str => "Invalid choice. Please try again.",
      default => undef,
      verify_sub => sub {
        my ($answer) = @_;
        if ((not defined $answer) or ($answer eq '')) {
          return (0, undef);
        }
        foreach my $choice (@{$choices}) {
          if ($choice->{'key'} eq $answer) {
            return (1, $choice->{'name'});
          }
        }
        return (0, undef);
      },
    });
}

sub udb_sort {
  my $self = shift;
  return -1 if ($a eq 'Name');
  return 1 if ($b eq 'Name');
  return 1 if ($a eq 'Comments');
  return -1 if ($b eq 'Comments');
  return $a cmp $b;
}

sub sprint_record {
  my $self = shift;
  my ($prefix, $hash) = @_;

  my $out = "";

  foreach my $key (sort udb_sort (keys(%{$hash}))) {
    my $val = $hash->{$key};
    next if not defined $val;
    if ((ref($val) eq "ARRAY")) {
      if (scalar(@{$val}) > 0) {
        $out .= ($prefix . $key . ":\n");
        $out .= $self->sprint_array(($prefix."  "), $val);
      }
    } elsif ((ref($val) eq "HASH")) {
      $out .= ($prefix . $key . ":\n");
      $out .= $self->sprint_record(($prefix."  "), $val);
    } elsif ($val) {
      $out .= sprintf("%s%s: %s\n", $prefix, $key, $val);
    }
  }

  return $out;
}

sub sprint_array {
  my $self = shift;
  my ($prefix, $array) = @_;

  my $out = "";

  foreach my $item (sort @{$array}) {

    next if not defined $item;

    if ((ref($item) eq "ARRAY")) {
      $out .= "$prefix-\n";
      $out .= $self->sprint_array(($prefix."- "), $item);
    } elsif ((ref($item) eq "HASH")) {
      $out .= "$prefix-\n";
      $out .= $self->sprint_record(($prefix."  "), $item);
    } elsif ($item) {
      $out .= sprintf("%s- %s\n", $prefix, $item);
    }
  }

  return $out;
}

sub print_record {
  my $self = shift;
  print ($self->sprint_record (@_));
}

# ask_with_help_option :: string -> string
# Gets a line from the user. If the user enters '?', give a help screen.
sub ask_with_help_option {
  my $self = shift;
  my($prompt, $default, $help) = @_;
  return $self->query({
      prompt => $prompt,
      default => $default ? $default : '',
      error_str => $help,
      verify_sub => sub {
        my ($answer) = @_;
        if ($answer eq '?') {
          return (0, undef);
        } else {
          return (1, $answer);
        }
      },
    });
}

sub get_dns_alias {
  my $self = shift; 
  
  my ($name) = @_;

  my @regions = $self->udb->resultset('DnsRegions')->get_column('dns_region')->all;
  my $region = $self->choose('DNS region [all]:', \@regions,'all');

  my ($alias, $domain, $authoritative) = $self->get_updated_val('DNS alias','', verify_dns_alias($self->udb, $name, $region));

  return ($alias, $domain, $region, $authoritative);
}

sub get_dns_alias_ip {
  my $self = shift;
  my $ip;

  print "$ip\n";
}

sub choose_interface {
  my $self = shift;
  my ($name, $filter_type) = @_;
  my $iface;

  my $device = $self->udb->resultset('Devices')->find($name);
  my $ifaces_rs = $device->net_interfaces;

  if ($ifaces_rs->count == 0) {
    print "The device $device->device_name does not have any network interfaces.\n";
    exit(0);
  } elsif ($ifaces_rs->count == 1) {
    $iface = $ifaces_rs->single;
  } else {
    my $iface_idx = 1;
    my @choices = ();
    while (my $iface = $ifaces_rs->next) {
      my $ip = "";
      if ($iface->net_addresses->single) {
        $ip = " (" . $iface->net_addresses->single->ipaddr . ")";
      }

      # if user only requested primary interfaces, skip anything which references a master interface id
      if ($filter_type && $filter_type =~ /primary/ && $iface->master_net_interface_id) {
        next;
      }

      # if user only requested secondary interfaces, skip anything that references a primary address id
      if ($filter_type && $filter_type =~ /secondary/ && $iface->primary_interface_id) {
        next;
      }

      # if user only requested an available interface, skip anything that references either a master interface
      # id or primary address id
      if ($filter_type && $filter_type =~ /available/ && ($iface->master_net_interface_id || $iface->primary_interface_id)) {
        next;
      }

      my $flag = "";
      if (! $iface->master_net_interface_id) {
        $flag = "*";
      }

      push @choices, {
        key => $iface_idx++,
        name => $iface,
        desc => $iface->ethernet . $ip . $flag,
      };
    }

    $iface = $self->choose_from_menu("Select an interface ('*' indicates primary interface)", \@choices);
  }

  return $iface;
}
 
sub choose_addr {
  my $self = shift;
  my ($name, $filter_type) = @_;
  my $addr;

  my $device = $self->udb->resultset('Devices')->find($name);
  my $ifaces_rs = $device->net_interfaces;

  my $addr_idx = 1;
  my @choices = ();
  if ($ifaces_rs->count == 0) {
    print "The device \"$device->device_name\" does not have any network interfaces.\n";
    print "Network addresses must be asociated with a network interface.  Did you\n";
    print "mean to delete a DNS alias instead?\n";
    exit(0);
  } else {
    while (my $iface = $ifaces_rs->next) {
      my $mac = $iface->ethernet;
      foreach my $addr ($iface->net_addresses) {
        push @choices, {
          key => $addr_idx++,
          name => $addr,
          desc => $addr->ipaddr,
        };
      }
    }

    $addr = $self->choose_from_menu("Select an IP address", \@choices);
  }

  return $addr;
}

sub get_management_type {
  my $self = shift;
  my ($default) = @_;
  if (ref($default) eq 'BrownCS::udb::Schema::ManagementTypes') {
    $default = $default->management_type;
  }
  my @management_types = $self->udb->resultset('ManagementTypes')->get_column("management_type")->all;
  my $management_prompt = <<EOF;

Who is in charge of managing this computer?
EOF
  my $def_msg = def_msg($default);
  if ($default) {
    $management_prompt .= "Managed by [default: $def_msg]:";
  } else {
    $management_prompt .= "Managed by:";
  }
  return $self->choose($management_prompt, \@management_types, $default);
}

sub get_equip_usage_type {
  my $self = shift;

  my $equip_usage_prompt = <<EOF;

What is the usage type of this computer?
EOF
  $equip_usage_prompt .= "Usage:";

  return $self->demand($equip_usage_prompt, verify_equip_usage_types($self->udb));
}

sub get_os_type {
  my $self = shift;
  my ($default) = @_;
  if (ref($default) eq 'BrownCS::udb::Schema::OsTypes') {
    $default = $default->os_type;
  }
  my @os_types = ('', $self->udb->resultset('OsTypes')->get_column("os_type")->all);
  my $os_prompt = <<EOF;

What OS will this computer have?
If you don't know, or if this computer is user-maintained,
you can safely leave this blank.
EOF
  my $def_msg = def_msg($default);
  if ($default) {
    $os_prompt .= "OS [default: $def_msg]:";
  } else {
    $os_prompt .= "OS:";
  }
  my $answer = $self->choose($os_prompt, \@os_types, $default);
  if (not $answer) {
    $answer = undef;
  }
  return $answer;
}

sub get_comp_classes {
  my $self = shift;
  my (@default_classes) = @_;
  my $default = join(",", @default_classes);
  my $classes_prompt = <<EOF;

What OS classes should this computer belong to?
If you don't know, just say 'desktop' for a department workstation,
or leave it blank for a user-maintained computer.
EOF
  my $def_msg = def_msg($default);
  if ($default) {
    $classes_prompt .= "Classes [comma-separated list, default: $def_msg]:";
  } else {
    $classes_prompt .= "Classes [comma-separated list]:";
  }
  my $classes_str = $self->ask_with_help_option($classes_prompt,'','');
  $classes_str =~ s/\s//g;
  my @classes = split(/,/, $classes_str);
  return \@classes;
}

sub get_ip_and_vlan {
  my $self = shift;

  my $ip_or_vlan_preamble = <<EOF;
What is IP address do you want assigned?
If you just want an arbitrary IP on a given VLAN (e.g. 31, 3962 (was 4007)),
enter the VLAN number, and an IP will be picked for you.
EOF

  my $ip_or_vlan_prompt = "\n${ip_or_vlan_preamble}IP or VLAN:";
  my ($ipaddr, $vlan) = $self->demand($ip_or_vlan_prompt, verify_ip_or_vlan($self->udb));
  return ($ipaddr, $vlan);
}

sub get_port {
  my $self = shift;
  my ($iface) = @_;

  my $uc = new BrownCS::udb::Console(udb => $self->udb);
  
  my $port;
  my ($switch_name, $blade_num, $port_num) = "";
  my ($existing_switch_name, $existing_blade_num, $existing_port_num) = "";

  # prompt user for updated port information
  my $wall_plate = $self->get_updated_val("Wall Plate", "", verify_wall_plate($self->udb));

  # retrieve the existing port information if one already exists
  my $existing_port = wall_plate_port($self, $wall_plate);

  if ($existing_port) {
    # if given an interface and port already exists, we are just adding a device
    if ($iface) {
      # make sure it jibes with what is already connected to this port
      ($port, $iface) = verify_port_iface($self->udb,$existing_port,$iface);

      return ($port, $iface);
    }

    $existing_switch_name = $existing_port->switch_name;
    $existing_blade_num = $existing_port->blade_num;
    $existing_port_num = $existing_port->port_num;
  }

  $switch_name = $self->get_updated_val("Switch",$existing_switch_name, verify_switch($self->udb));
  my $net_switch = $self->udb->resultset('NetSwitches')->find($switch_name);
  
  if ($net_switch->num_blades > 0 ) {
    $blade_num = $self->get_updated_val("Blade Number",$existing_blade_num,verify_blade($self->udb,$switch_name));
  } else {
    $blade_num = 0;
  }
  
  $port_num = $self->get_updated_val("Port Number",$existing_port_num,verify_port_num($self->udb,$switch_name));

  my $conflicting_port = $self->udb->resultset('NetPorts')->find({
    net_switch => $net_switch,
    port_num => $port_num,
    blade_num => $blade_num,
  });

  if ($conflicting_port || $existing_port) {
    if ($conflicting_port) {
      print "\nPort is already asosciated with wall plate " . $conflicting_port->wall_plate . ".\n";
      if (! $uc->confirm("Are you sure you want to continue (y/N)", "no")) {
        return;
      }

      # if there is also an existing port, then we need to remove the existing port
      if ($existing_port) {
        print "\nThis will remove the existing port entry associated with blade \"" . $existing_port->blade_num . "\", port \"" . $existing_port->port_num . "\" on switch " . $existing_port->switch_name . ".\n";
        if (! $uc->confirm("Are you sure you want to continue (y/N)", "no")) {
          return;
        }

        $existing_port->delete;
      }

      $port = $conflicting_port;
    } else {
      $port = $existing_port;
    }

    $port->net_switch($net_switch);
    $port->port_num($port_num);
    $port->blade_num($blade_num);
    $port->wall_plate($wall_plate);
      
    $port->update;
  }else {
    $port = $self->udb->resultset('NetPorts')->create({
      net_switch => $net_switch,
      port_num => $port_num,
      blade_num => $blade_num,
      wall_plate => $wall_plate,
    });
  }
  
  return ($port, $iface);
}

sub get_updated_val {
  my $self = shift;
  my ($title, $default, $verify_sub) = @_;
  my $query_args = {};
  if ($verify_sub) {
    $query_args->{verify_sub} = $verify_sub;
  }
  if ($default) {
    $query_args->{default} = $default;
    my $def_msg = def_msg($default);
    $query_args->{prompt} = "\n$title [default: $def_msg]:";
  } else {
    $query_args->{prompt} = "\n$title:";
  }
  return $self->query($query_args);
}

sub get_mac {
  my $self = shift;
  my ($iface) = @_;
 
  my $default;

  # if given a particular interface, use it as a default
  if ($iface) {
    $default = $iface->ethernet;
  } 

  return $self->get_updated_val("MAC address", $default, verify_mac($self->udb,$iface));
}

sub get_comments {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("Comments [optional]",$default);
}

sub get_device_name {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("Device name", $default, verify_hostname($self->udb));
}

sub get_contact {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("Primary user/contact", $default, \&verify_nonempty_nonq);
}

sub get_owner {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val(
    "Who paid for this computer?\nOwner",
    $default,
    \&verify_nonempty_nonq,
  );
}

sub get_pxelink {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("PXElink");
}

sub get_serial_num {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("Serial number [optional]",$default);
}

sub get_brown_inv_num {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("Brown inventory number [optional]",$default);
}

sub get_po_num {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("Purchase order [optional]",$default);
}

sub get_place {
  my $self = shift;
  my ($default_place) = @_;

  my ($default_city, $default_building, $default_room, $default_description);
  my ($new_city, $new_building, $new_room, $new_description);

  if ($default_place) {
    $default_city = $default_place->city;
    $default_building = $default_place->building;
    $default_room = $default_place->room;
    $default_description = $default_place->room;
  }

  my $is_in_cit = $self->confirm("\nIs this device located in the CIT? (Y/n)", "y");

  if ($is_in_cit) {
    $new_city = 'Providence';
    $new_building = 'CIT';
    $new_room = $self->get_updated_val("Room number", $default_room);
  } else {
    my $is_in_arnold = $self->confirm("\nIs this device located in the Arnold? (Y/n)", "y");
    if ($is_in_arnold) {
      $new_city = 'Providence';
      $new_building = 'Arnold';
      $new_room = $self->get_updated_val("Room number", $default_room);
    } else {
      my $is_on_campus = $self->confirm("\nIs this device located on campus? (Y/n)", "y");
      if ($is_on_campus) {
        $new_city = 'Providence';
        $new_building = $self->get_updated_val("Building", $default_building);
        $new_room = $self->get_updated_val("Room number", $default_room);
      } else {
        $new_city = $self->get_updated_val("City", $default_city);
        $new_description = $self->get_updated_val("Description", $default_description);
      }
    }
  }

  $new_room = uc($new_room);

  return ($new_city, $new_building, $new_room, $new_description);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

BrownCS::udb::Console - utility functions

=head1 SYNOPSIS

  use BrownCS::Console qw(:all);

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
