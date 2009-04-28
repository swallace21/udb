package BrownCS::UDB::Switch;
use Moose;

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);
use Expect;

use BrownCS::UDB::Util qw(:all);

has 'name' => ( is => 'ro', isa => 'Str', required => 1 );
has 'switch' => (
  is => 'ro',
  isa => 'HashRef',
  default => \&_build_switch,
  lazy => 1,
);

sub _build_switch {
  my $switch = $udb->query('select fqdn, num_ports, num_blades, \
    switch_type, port_prefix, connection, username, pass from net_switches \
    where name = ?')->hash;

  die "There is no switch named '$switch_name'.\n" if not $switch;
  return $switch;
}

#
# Internal functions
#

sub login_ssh {
  my $self = shift;

  my $con = $self->{connection};
  my $switch = $self->{switch_name};

  # Login
  # this is not a typo: missing letter can be either p or P
  $con->expect(30, "assword: ") || die "Never got a password prompt on $switch, " . $con->exp_error()."\n";

  print $con "$sp_switches->{$switch}{'login'}\r";

  # Enter enable mode  
  $con->expect(30, "$switch\#") || die "Never got switch prompt, " . $con->exp_error() . "\n";
}

sub login_telnet {
  my $self = shift;

  my $con = $self->{connection};
  my $switch = $self->{switch_name};

  # Login
  $con->expect(30, "Password: ") || die "Never got a password prompt on $switch, " . $con->exp_error()."\n";

  print $con "$sp_switches->{$switch}{'login'}\r";

  # Enter enable mode  
  $con->expect(30, "$switch\>") || die "Never got switch prompt, " . $con->exp_error() . "\n";
  print $con "enable\r";

  $con->expect(30, "Password: ") || die "Never got a password prompt on $switch, " . $con->exp_error()."\n";
  print $con "$sp_switches->{$switch}{'enable'}\r"; 

  $con->expect(30, "$switch\#") || die "Never got enabled switch prompt, " . $con->exp_error() . "\n";
}

sub config_term {
  my $self = shift;

  my $con = $self->{connection};
  my $switch = $self->{switch_name};

  # Enter configuration mode
  print $con "config term\r";
  $con->expect(30, "$switch\(config\)\#") || die "Never got config prompt, " . $con->exp_error() . "\n";
}

sub config_int {
  my $self = shift;
  my ($port) = @_;

  my $con = $self->{connection};
  my $switch = $self->{switch_name};

  # To accomodate multiblade switches (6500) or stacked switches (3750E) and 
  # avoid having to change all the prefixes in the switch_cfg file.  Ports 
  # for these types of switches need to be addressed as g<blade>/<port>, eg. 
  # g1/3 or g<switch>/<stack>/<port>, eg. g1/0/3
  if ( $sp_switches->{$switch}{'prefix'} eq 'g' ) {
    print $con "int $sp_switches->{$switch}{'prefix'}$port\r";
  }
  else {
    print $con "int $sp_switches->{$switch}{'prefix'}/$port\r";
  }

  $con->expect(30, "$switch\(config-if\)\#") || die "Never got config interface prompt, " . $con->exp_error() . "\n";
}

sub exit_int {
  my $self = shift;

  my $con = $self->{connection};
  my $switch = $self->{switch_name};

  printf $con "%c", 0x1A;
  $con->expect(30, "$switch#") || die "Never got next to enable prompt, " . $con->exp_error() . "\n";
}

sub write_mem {
  my $self = shift;

  my $con = $self->{connection};
  my $switch = $self->{switch_name};

  print $con "write mem\r";
  $con->expect(30, "\[OK\]") || die "Never got write confirmation, " .  $con->exp_error() . "\n";
  $con->expect(30, "$switch#") || die "Never got final enable prompt, " . $con->exp_error() . "\n";
}

#
# Interface
#

sub start {
  my $self = shift;

  if ($sp_switches->{$self->{'switch_name'}}{'mode'} eq "ssh") {
    my $username = $
    $self->{connection} = Expect->spawn("ssh -l $sp_switches->{$self->{'switch_name'}}{'user'} $sp_switches->{$self->{'switch_name'}}{'fqdn'}");
  } elsif ($sp_switches->{$self->{'switch_name'}}{'mode'} eq "telnet") {
    $self->{connection} = Expect->spawn("telnet $sp_switches->{$self->{'switch_name'}}{'fqdn'}");
  } else {
    print "Error: no connection mode specified in config file for switch
    $self->{'switch_name'}\n";
  }

  # Control logging
  # log output to the terminal
  if ($verbose) {
    $self->{connection}->log_stdout(1);
  } else {
    $self->{connection}->log_stdout(0);
  }

  if ($sp_switches->{$self->{'switch_name'}}{'mode'} eq "ssh") {
    &login_ssh($self->{'switch_name'});
  } elsif ($sp_switches->{$self->{'switch_name'}}{'mode'} eq "telnet") {
    &login_telnet($self->{'switch_name'});
  }
}

sub finish {
  my $self = shift;
  if ($self->{connection}) {
    if ($self->{modified}) {
      $self->write_mem;
    }
    print $self->{connection} "exit\r"; 
    $self->{connection}->hard_close();
  }
}

sub update_port {
  my $self = shift;
  my($host, $walljack, $switch, $port, $vlan) = @_;

  config_term($switch);
  config_int($switch, $port);

  # Enter hostname
  if ($host =~ /SWITCH/) {
    print $con "description $host\r";
  } else {
    print $con "description $host - $walljack\r";
  }
  $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response while setting hostname, " . $con->exp_error() . "\n";

  # Common configurations that all switch ports get

  # make sure the port is enabled
  print $con "no shut\r";
  $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response activating port, " . $con->exp_error() . "\n";

  # make sure it's a layer two port
  print $con "switchport\r";
  $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response making port layer 2, " . $con->exp_error() . "\n";

  # request full flowcontrol
  print $con "flowcontrol receive desired\r";
  $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response turning on flow control, " . $con->exp_error() . "\n";

  # Determine if this is a trunk or not...
  if ($#vlans > 0) {
    my $primary = $vlans[0];

    # Unset portfast
    print $con "no spanning-tree portfast\r";
    $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response turning off spanning tree portfast, " . $con->exp_error() . "\n";

    # Set encapsulation mode
    print $con "switchport trunk encapsulation dot1q\r";
    $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response while setting dot1q encapsulation, " . $con->exp_error() . "\n";

    # Set vlans
    print $con "switchport trunk allowed vlan none\r";
    $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response trying to unset vlans, " . $con->exp_error() . "\n";
    print $con "switchport trunk allowed vlan $vlan\r";
    $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response trying to set trunked vlans, " . $con->exp_error() . "\n";

    # Set native vlan
    print $con "switchport trunk native vlan 720\r";
    $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response trying to set native vlans, " . $con->exp_error() . "\n";

    # Set mode
    print $con "switchport mode trunk\r";
    $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response trying to set trunk mode, " . $con->exp_error() . "\n";

  } else {
    # Enter vlan
    print $con "switchport access vlan $vlan\r";
    $con->expect(30, "$switch\(config-if\)\#") || die "Never got third config interface prompt, " . $con->exp_error() . "\n";

    # Set mode access
    print $con "switchport mode access\r";
    $con->expect(30, "$switch\(config-if\)\#") || die "Never got fourth config interface prompt, " . $con->exp_error() . "\n";

    # Set encapsulation mode
    print $con "switchport trunk encapsulation negotiate\r";
    $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response while setting dot1q encapsulation, " . $con->exp_error() . "\n";

    # Set portfast
    print $con "spanning-tree portfast\r";
    $con->expect(30, "$switch\(config-if\)\#") || die "Wrong response setting spanning-tree portfast, " . $con->exp_error() . "\n";
  }

  # (un)set bpduguard - this only applies to 3550s (or newer?).  
  # enable bpduguard on everything except hosts with a hostname with "SWITCH"
  # in it's name
  if ($sp_switches->{$switch}{'type'} eq "3550") {
    if ($host =~ /SWITCH/) {
      print $con "spanning-tree bpduguard disable\r"; 
    } else {
      print $con "spanning-tree bpduguard enable\r";
    }
    $con->expect(30, "$switch\(config-if\)\#") || die "Never got sixth config interface prompt, " . $con->exp_error() . "\n";
  }

  exit_int($switch);

  $self->{modified} = 1;
}

sub program {
  my ($switch) = @_;
  my ($host);

  exit if (!&check_switch($switch));
  connect2sw($switch);

  foreach my $host (keys(%$sp_hosts)) {
    if ($sp_hosts->{$host}{'switch'} eq $switch) {
      &update_port($host, $sp_hosts->{$host}{'jack'}, $switch, $sp_hosts->{$host}{'port'}, $sp_hosts->{$host}{'vlan'});
    }
  }

  &write_mem($switch);
  logoff;
}

sub find_host {
  my($scope, @hosts) = @_;
  my($host, $switch);
  my(@macs, $output);

  foreach my $host (@hosts) {
    chomp $host;
    next if ! check_mac($host);
    push @macs, convert_mac($host);
  }

  foreach my $switch (keys(%$sp_switches)) {

    # Connect to switch
    connect2sw($switch);

    # grab stdout
    $con->log_file(&parse);

    # get a list of mac addresses known to the switch
    print $con "show mac-address-table\r";
    $con->expect(30, "$switch\#") || die "Never got switch prompt in find_host, " . $con->exp_error() . "\n";

    $con->log_file(undef);

    logoff($con, $switch);

  }
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
