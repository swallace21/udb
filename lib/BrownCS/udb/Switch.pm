package BrownCS::udb::Switch;

use Moose;
use Expect;
use BrownCS::udb::Util qw(:all);

has 'verbose' => ( is => 'ro', isa => 'Bool', required => 1 );
has 'net_switch' => (
  is => 'ro',
  isa => 'BrownCS::udb::Schema::NetSwitches',
  required => 1,
);

has 'con' => ( is => 'ro', isa => 'Expect' );
has 'modified' => ( is => 'rw', isa => 'Bool' );

sub connect {
  my $self = shift;

  my $connection_type = $self->net_switch->connection_type;
  my $name = $self->net_switch->device_name;
  my $username = $self->net_switch->username;
  my $password = $self->net_switch->pass;
  my $fqdn = $self->net_switch->fqdn;
  if ($connection_type eq "ssh") {
    $self->{con} = Expect->spawn("ssh -l $username $fqdn");
  } else {
    die "Unknown connection type: $connection_type!\n";
  }

  my $con = $self->con;

  # Control whether output should be logged to the terminal
  $con->log_stdout($self->verbose);

  if ($connection_type eq 'ssh') {
    # Login
    # this is not a typo: missing letter can be either p or P
    $self->wait_for("assword: ", "Never got a password prompt on $name");

    $self->send("$password\r");

    # Enter enable mode  
    $self->wait_for("$name\#", "Never got switch prompt");
  } else {
    die "Unknown connection type: $connection_type!\n";
  }
}

sub DEMOLISH {
  my $self = shift;
  my $name = $self->net_switch->device_name;
  my $con = $self->con;

  if ($con) {
    if ($self->modified) {
      $self->send("write mem\r");
      $self->wait_for("\[OK\]", "Never got write confirmation");
      $self->wait_for("$name#", "Never got final enable prompt");
    }
    $self->send("exit\r");
    $con->hard_close;
  }
}

sub send {
  my $self = shift;
  my $con = $self->con;
  print $con @_;
}

sub wait_for {
  my $self = shift;
  my ($prompt, $error) = @_;
  $self->con->expect(30, $prompt)
    or die ("$error, " .  $self->con->exp_error() .  "\n");
}

sub get_port_desc {
  my $self = shift;
  my ($port) = @_;
  my $ifaces = $port->net_interfaces;

	# TODO, this should really reference places instead, but the information
	# doesn't seem to be in the database!
	my ($room) = split(/-/, $port->wall_plate);

  my $desc;
  if ($ifaces->count == 0) {
    $desc = "";
  } elsif ($ifaces->count == 1) {
    $desc = $ifaces->single->device_name . " - " . $room;
  } else {
    $desc = "unmanaged switch " . $room;
  }

  return $desc;
}

sub get_port_vlans {
  my $self = shift;
  my ($port) = @_;
  my $ifaces = $port->net_interfaces;

  my $vlans_rs = $ifaces->search({},
    {
      prefetch => {
        'net_addresses_net_interfaces' => 'net_address',
      },
      '+select' => [ 'net_address.vlan_num' ],
      '+as'     => [ 'Vlan' ],
    });

  my %vlans = ();
  while (my $vlan = $vlans_rs->next) {
    $vlans{$vlan->get_column('Vlan')} = 1;
  }

  my $native_vlans_rs = $ifaces->search({},
    {
      prefetch => 'primary_address',
      '+select' => [ 'primary_address.vlan_num' ],
      '+as'     => [ 'Vlan' ],
    });

  my %native_vlans = ();
  while (my $vlan = $native_vlans_rs->next) {
    $native_vlans{$vlan->get_column('Vlan')} = 1;
  }

  my ($native_vlan, undef) = each(%native_vlans);

  # TODO check this in the database schema
  if (scalar(keys(%native_vlans)) > 1) {
    warn "Error: primary addresses should never have different VLANs!\n";
    $native_vlan = '36';
  } elsif (not $native_vlan) {
    $native_vlan = '36';
  }

  delete($vlans{$native_vlan});

  return ($native_vlan, (keys %vlans));
}

sub get_port_devices {
  my $self = shift;
  my ($port) = @_;
  my $ifaces = $port->net_interfaces;

	my @net_ifaces = $ifaces->search({
			net_port_id => $port->net_port_id,
		});

	my @devices;
	for my $iface (@net_ifaces) {
		push @devices, $iface->device_name;	
	} 

	return @devices;
}

sub update_port {
  my $self = shift;
  my ($port) = @_;

  my $con = $self->con;
  my $ifaces = $port->net_interfaces;
  my $desc = $self->get_port_desc($port);
  my $name = $self->net_switch->device_name;
  my $switch_type = $self->net_switch->switch_type;
  my $port_num = $port->port_num;
  my $blade_num = $port->blade_num;

  my ($native_vlan, @other_vlans) = $self->get_port_vlans($port);

  # Enter configuration mode
  $self->send("config term\r");
  $self->wait_for("$name\(config\)\#", "Never got config prompt");

  if ($switch_type eq '6500') {
    $self->send("int g$blade_num/$port_num\r");
  } elsif ($switch_type eq '3750E') {
    $self->send("int g$blade_num/0/$port_num\r");
  } else {
    die "Unknown switch type: $switch_type!\n";
  }

  $self->wait_for("$name\(config-if\)\#", "Never got config interface prompt");

  # Enter hostname
  $self->send("description $desc\r");
  $self->wait_for("$name\(config-if\)\#", "Wrong response while setting hostname");

  # Common configurations that all switch ports get

  # temporarily disable the port
  $self->send("shut\r");
  $self->wait_for("$name\(config-if\)\#", "Wrong response shutting port");

  # make sure the port is enabled
  $self->send("no shut\r");
  $self->wait_for("$name\(config-if\)\#", "Wrong response unshutting port");

  # make sure it's a layer two port
  $self->send("switchport\r");
  $self->wait_for("$name\(config-if\)\#", "Wrong response making port layer 2");

  # request full flowcontrol
  $self->send("flowcontrol receive desired\r");
  $self->wait_for("$name\(config-if\)\#", "Wrong response turning on flow control");

  # Determine if this is a trunk or not...
  if (@other_vlans) {
    my $all_vlans = join(',', $native_vlan, @other_vlans);

    # Set encapsulation mode
    $self->send("switchport trunk encapsulation dot1q\r");
    $self->wait_for("$name\(config-if\)\#", "Wrong response while setting dot1q encapsulation");

    # Set vlans
    $self->send("switchport trunk allowed vlan none\r");
    $self->wait_for("$name\(config-if\)\#", "Wrong response trying to unset vlans");
    $self->send("switchport trunk allowed vlan $all_vlans\r");
    $self->wait_for("$name\(config-if\)\#", "Wrong response trying to set trunked vlans");

    # Set native vlan
    $self->send("switchport trunk native vlan $native_vlan\r");
    $self->wait_for("$name\(config-if\)\#", "Wrong response trying to set native vlans");

    # Set mode
    $self->send("switchport mode trunk\r");
    $self->wait_for("$name\(config-if\)\#", "Wrong response trying to set trunk mode");

  } else {
    # Enter vlan
    $self->send("switchport access vlan $native_vlan\r");
    $self->wait_for("$name\(config-if\)\#", "Never got third config interface prompt");

    # Set mode access
    $self->send("switchport mode access\r");
    $self->wait_for("$name\(config-if\)\#", "Never got fourth config interface prompt");

    # Set encapsulation mode
    $self->send("switchport trunk encapsulation negotiate\r");
    $self->wait_for("$name\(config-if\)\#", "Wrong response while setting dot1q encapsulation");
  }

  # portfast/bpduguard should only be set for ports with a single device
  if ($ifaces->count > 1) {
    $self->send("spanning-tree portfast disable\r");
    $self->wait_for("$name\(config-if\)\#", "Wrong response setting spanning-tree portfast");

    $self->send("spanning-tree bpduguard disable\r");
    $self->wait_for("$name\(config-if\)\#", "Wrong response setting bpduguard");
  } else {
    $self->send("spanning-tree portfast\r");
    $self->wait_for("$name\(config-if\)\#", "Wrong response setting spanning-tree portfast");

    $self->send("spanning-tree bpduguard enable\r");
    $self->wait_for("$name\(config-if\)\#", "Wrong response setting bpduguard");
  }

  $self->send(sprintf("%c", 0x1A));
  $self->wait_for("$name#", "Never got next to enable prompt");

  $self->modified(1);
}

sub program {
  my $self = shift;
  my $ports = $self->net_switch->net_ports;
  while (my $port = $ports->next) {
    $self->update_port($port);
  }
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;

