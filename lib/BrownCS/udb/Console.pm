package BrownCS::udb::Console;

use 5.010000;
use strict;
use warnings;

use Term::ReadKey;
use Term::ReadLine;
use File::Temp qw(tempfile);

use Exporter qw(import);

our @EXPORT_OK = qw(
  ask
  ask_password
  choose
  choose_from_menu
  confirm
  demand
  edit
  fix_width
  format_address
  format_device
  format_surplus
  get_key
  get_new
  get_new_location
  get_new_name
  get_new_os
  get_new_user
  print_record
  sprint_record
);

our %EXPORT_TAGS = ("all" => [@EXPORT_OK]);

my $term = new Term::ReadLine 'udb';
$term->ornaments(0);

sub get_key {
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
  print STDERR "Password: ";
  ReadMode 'noecho';
  my $password = ReadLine 0;
  chomp $password;
  ReadMode 'normal';
  print STDERR "\n";
  return $password;
}

# confirm :: string -> boolean
# Prompt the user for yes or no and return appropriate value.
sub confirm {
  my($prompt, $default) = @_;
  while (1) {
    my $answer = $term->readline($prompt);
    if ($answer eq '') {
      return $default;
    } elsif ($answer =~ /^y(es)?$/i) {
      return 1;
    } elsif ($answer =~ /^n(o)?$/i) {
      return 0;
    } else {
      print "Invalid answer. Please answer yes or no (y/n).\n"
    }
  }
}

# ask :: string -> string
# Gets a line from the user.
sub ask {
  my($prompt, $default) = @_;
  my $answer = $term->readline("$prompt ");
  return ($answer or $default);
}

# demand :: string * (string -> boolean) -> string
# Gets a line from the user and verifies it.
# If no verification procedure is supplied, then
# verifies that the input is nonempty.
sub demand {
  my($prompt, $verify_sub) = @_;
  if (not $verify_sub) {
    $verify_sub = sub {
      my ($ans) = @_;
      return ((defined $ans) and ($ans ne ''));
    }
  }
  while (1) {
    my $answer = $term->readline("$prompt ");
    my $is_valid;
    eval {
      $is_valid = &$verify_sub($answer);
    };
    if ($@) {
      print "Error: $@\n";
      print "Please try again.\n";
    } elsif ($is_valid) {
      return $answer;
    } else {
      print "Invalid answer. Please try again.\n";
    }
  }
}

# choose :: string * [string] -> string
# Gets an answer from the user. The answer must belong to a specified
# list.
sub choose {
  my($prompt, $choices) = @_;

  my $answer;
  while (1) {
    $|++;
    print "$prompt ";
    $|--;
    chop($answer = <STDIN>);
    last if grep {$_ eq $answer} @{$choices};
    print "\nInvalid choice. Valid choices are:\n";
    foreach my $i (sort(@{$choices})) {
      if (not $i) {
        print "  <blank>\n";
      } else {
        print "  $i\n";
      }
    }
  }
  return $answer;
}

# choose_from_menu :: string * [(string * string * string)] -> string
# Gets an answer from the user. The answer must belong to a specified
# list. The user is presented with a menu of choices, and is asked to
# select one by number.
sub choose_from_menu {
  my($prompt, $choices) = @_;

  my $answer = undef;

  print "$prompt\n";

  foreach my $choice (@{$choices}) {
    printf(" [%s] %s\n", $choice->{'key'}, $choice->{'desc'});
  }

  while (1) {
    $|++;
    print STDOUT  "Choose an option: ";
    $|--;
    chop($answer = <STDIN>);
    foreach my $choice (@{$choices}) {
      if ($choice->{'key'} eq $answer) {
        return $choice->{'name'};
      }
    }
    print "Invalid choice. Please try again.\n";
  }
}

sub fix_width {
  my ($str, $width) = @_;
  my $spaces = ' ' x ($width - length($str));
  return ($str . $spaces);
};

sub get_new {
  my ($maybe, $desc, $verify_proc) = @_;

  my $answer;
  while (1) {
    $answer = ask("Enter the new $desc (blank for no change):",'');
    if (not defined $answer) {
      print "\n";
      last;
    }
    last if $answer eq '';
    next if not &$verify_proc($answer);
    last;
  }
  return $answer;
}

sub udb_sort {
  return -1 if ($a eq 'Name');
  return 1 if ($b eq 'Name');
  return 1 if ($a eq 'Comments');
  return -1 if ($b eq 'Comments');
  return $a cmp $b;
}

sub sprint_record {
  my ($prefix, $hash) = @_;

  my $out = "";

  foreach my $key (sort udb_sort (keys(%{$hash}))) {
    my $val = $hash->{$key};
    next if not defined $val;
    if ((ref($val) eq "ARRAY")) {
      if (scalar(@{$val}) > 0) {
        $out .= ($prefix . $key . ":\n");
        $out .= sprint_array(($prefix."  "), $val);
      }
    } elsif ((ref($val) eq "HASH")) {
      $out .= ($prefix . $key . ":\n");
      $out .= sprint_record(($prefix."  "), $val);
    } elsif ($val) {
      $out .= sprintf("%s%s: %s\n", $prefix, $key, $val);
    }
  }

  return $out;
}

sub sprint_array {
  my ($prefix, $array) = @_;

  my $out = "";

  foreach my $item (sort @{$array}) {

    next if not defined $item;

    if ((ref($item) eq "ARRAY")) {
      $out .= "$prefix-\n";
      $out .= sprint_array(($prefix."- "), $item);
    } elsif ((ref($item) eq "HASH")) {
      $out .= "$prefix-\n";
      $out .= sprint_record(($prefix."  "), $item);
    } elsif ($item) {
      $out .= sprintf("%s- %s\n", $prefix, $item);
    }
  }

  return $out;
}

sub print_record {
  print (sprint_record (@_));
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
  $out->{"Name"} = $device->device_name;
  $out->{"Location"} = format_location($device->place);
  $out->{"Status"} = $device->status->equip_status_type;
  $out->{"Usage"} = $device->usage->equip_usage_type;
  $out->{"Managed by"} = $device->manager->management_type;
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
  if ($iface->net_port) {
    my $port = $iface->net_port;
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

sub get_new_name {
  my ($maybe) = @_;
  return get_new($maybe, "device name", \&verify_hostname);
}

sub get_new_user {
  my ($maybe) = @_;
  return get_new($maybe, "primary user or contact person", \&yes);
}

sub get_new_os {
  my ($maybe) = @_;
  return get_new($maybe, "OS type", \&yes);
}

sub get_new_location {
  my ($maybe) = @_;
  return get_new($maybe, "location", \&yes);
}

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
