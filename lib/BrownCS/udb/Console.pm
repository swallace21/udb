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

  my @regions = $self->udb->resultset('DnsRegions')->get_column('dns_region')->all;

  my ($alias, $domain) = $self->get_updated_val('DNS alias','', verify_dns_alias($self->udb));
  my $region = $self->choose('DNS region [all]:', \@regions,'all');

  return ($alias, $domain, $region);
}

sub get_dns_alias_ip {
  my $self = shift;
  my $ip;

  print "$ip\n";
}

sub choose_interface {
  my $self = shift;
  my ($name) = @_;
  my $iface;

  my $device = $self->udb->resultset('Devices')->find($name);
  my $ifaces_rs = $device->net_interfaces;
  if ($ifaces_rs->count == 0) {
    print "The device $device->device_name does not have any network interfaces.\n";
    exit(0);
  } elsif ($ifaces_rs->count == 1) {
    $iface = $ifaces_rs->single;
  } else {
    my $iface_ix = 1;
    my @choices = ();
    while (my $iface = $ifaces_rs->next) {
      my $ip = $iface->net_addresses->single->ipaddr;
      push @choices, {
        key => $iface_ix++,
        name => $iface,
        desc => $iface->ethernet,
        ip => $ip,
      };
    }

    $iface = choose_from_menu("Select an interface", \@choices);
  }

  return $iface;
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
  my ($default) = @_;
  if (ref($default) eq 'BrownCS::udb::Schema::EquipUsageTypes') {
    $default = $default->equip_usage_type;
  }
  my @equip_usage_types = $self->udb->resultset('EquipUsageTypes')->get_column("equip_usage_type")->all;
  my $equip_usage_prompt = <<EOF;

What is the usage type of this computer?
EOF
  my $def_msg = def_msg($default);
  if ($default) {
    $equip_usage_prompt .= "Usage [default: $def_msg]:";
  } else {
    $equip_usage_prompt .= "Usage:";
  }
  return $self->choose($equip_usage_prompt, \@equip_usage_types, $default);
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
  my ($dynamic) = @_;

#print "dynamic: $dynamic\n";
#
#  if ($dynamic) { 
#    $dynamic = 1; 
#  } else {
#    $dynamic = 0;
#  }
#
#print "dynamic: $dynamic\n";

  my $ip_or_vlan_preamble = <<EOF;
What is IP address do you want assigned?
If you just want an arbitrary IP on a given VLAN (e.g. 31, 36),
enter the VLAN number, and an IP will be picked for you.
EOF

if ($dynamic) {
  $ip_or_vlan_preamble .= "If you want a dynamic IP address, add a \"d\" to the start of the VLAN.\n";
  $ip_or_vlan_preamble .= "For example, use 'd36' instead of '36'.\n";
}

  my $ip_or_vlan_prompt = "\n${ip_or_vlan_preamble}IP or VLAN:";
  my ($ipaddr, $vlan) = $self->demand($ip_or_vlan_prompt, verify_ip_or_vlan($self->udb));
  return ($ipaddr, $vlan);
}

sub get_port {
  my $self = shift;
  my ($iface, $vlan) = @_;
  my $place = $iface->device->place;
  my $port;

  if ($place && $place->room) {
    my $room = $place->room;
    # FIX ME - this check needs to be checked against a db entry, but I need this working now!
    if ($room eq '531' || $room eq '310') {
      $port = $self->get_switchport($iface, $vlan);
    } else {
      $port = $self->get_walljack($iface);
    }
  }

  return $port;
}

sub get_switchport {
  my $self = shift;
  my ($iface, $vlan) = @_;

  my $room = $iface->device->place->room;

  my ($switch_name, $blade_num, $port_num, $wall_plate) = "";

  # if this is an existing port, then retrieve current port information
  if ($iface->net_port_id) {
    $switch_name = $iface->net_port->net_switch->switch_name;
    $blade_num = $iface->net_port->net_switch->blade_num;
    $port_num = $iface->net_port->net_switch->port_num;
    $wall_plate = $iface->net_port->net_switch->wall_plate;
  }

  my $port;

  # prompt user for updated port information
  $switch_name = $self->get_updated_val("Switch",$switch_name, verify_switch($self->udb));
  $blade_num = $self->get_updated_val("Blade Number",$blade_num,verify_blade($self->udb,$switch_name));
  $port_num = $self->get_updated_val("Port Number",$port_num,verify_port_num($self->udb,$switch_name));
  
  # FIX ME - this needs to be checked against a db entry
  if ($room  && ($room == '531' || $room == '310')) {
    $wall_plate = "MR";
  } else {
    $wall_plate = $self->get_updated_val("Wall Plate", $wall_plate);
  }

  my $net_switch = $self->udb->resultset('NetSwitches')->find($switch_name);

  # get the associated port number
  $port = $self->udb->resultset('NetPorts')->search({
      switch_name => $switch_name,
      blade_num => $blade_num,
      port_num => $port_num,
    })->single;
  
  # if the port doesn't exist, then insert an entry
  if (!$port) {
    $port = $self->udb->resultset('NetPorts')->find_or_create({
      net_switch => $net_switch,
      port_num => $port_num,
      blade_num => $blade_num,
      wall_plate => $wall_plate,
    });

    return $port;
  }

  # if the port already exists, do some sanity checks to make sure this change wouldn't knowingly 
  # break anything else
  my $switch = BrownCS::udb::Switch->new({
      net_switch => $net_switch,
      verbose => 0,
    });

  # make sure wall plate given by users matches wall plate associated with switch port
  if ("$wall_plate" ne $port->wall_plate) {
    print "ERROR: the wall plate your provided ($wall_plate) doesn't match the wall plate\n";
    print "associated with this switch port (" . $port->wall_plate . ")\n";
    return undef;
  }

  # make sure that vlan matches the native vlan for non-dynamic subnets
  my ($native_vlan, @other_vlans) = $switch->get_port_vlans($port);

  my $dynamic_vlans_rs = $self->udb->resultset('NetVlans')->search({
      dynamic_dhcp_start => { '!=', undef }
    });

  my @dynamic_vlans;
  while (my $dynamic_vlan = $dynamic_vlans_rs->next) {
    push @dynamic_vlans, $dynamic_vlan->vlan_num;
  }

  if($vlan && $vlan != $native_vlan && ! grep(/$native_vlan/, @dynamic_vlans)) {
    print "ERROR: primary VLAN of port is set to $native_vlan, which doesn't match the\n";
    print "VLAN entered of $vlan\n";
    return undef;
  }

  return $port;
}

sub get_walljack {
  my $self = shift;
  my ($iface) = @_;

  my $walljack_preamble = <<EOF;
What wall jack will the computer be plugged into?
If this computer will not be tied to any particular wall jack (e.g.
laptops), or if you aren't sure which wall jack the computer will be
attached to, you can safely leave this blank and fill it in later.

EOF
  my $walljack_prompt = "\n${walljack_preamble}Wall jack:";
  my $port = $self->demand($walljack_prompt, sub {
      my ($answer) = @_;
      return $answer ? verify_walljack($self->udb)->($_[0]) : (1, undef);
    });
  return $port;
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
  my ($default) = @_;
  return $self->get_updated_val("MAC address", $default, verify_mac($self->udb));
}

sub get_protected {
  my $self = shift;
  my ($default) = @_;
  my $msg_tail;
  if ($default) {
    $msg_tail = "(Y/n)";
  } else {
    $msg_tail = "(y/N)";
  }
  return $self->confirm("Should this device entry be protected? ".$msg_tail, $default);
}

sub get_comments {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("Comments [optional]",$default);
}

sub get_device_name {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("Device name", $default, verify_device_name($self->udb));
}

sub get_contact {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("Primary user", $default, \&verify_nonempty_nonq);
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

  return ($new_city, $new_building, $new_room, $new_description);
}

sub get_dns_region {
  print "region\n";
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
