package BrownCS::UDB::DbBase::Comp;

use 5.010000;
use strict;
use warnings;

use base 'BrownCS::UDB::DbBase';

my $error;

my $attrs = [
  ["hostname", "string", "req", "Hostname", ["What is the DNS hostname of this computer?"]],
  ["managed_by", "choice", "req", "Manager", ["Who is the person or group who will manage this computer?"]],
  ["usage", "choice", "req", "Usage", ["How will this computer be used?"]],
  ["contact", "string", "req", "Contact", ["Who is the owner or primary user of this computer?"]],
  ["ethernet", "macaddr", "opt", "MAC address", ["What is the computer's MAC address?", "If you don't know (e.g. for a xen machine), leave this blank."]],
  ["ip_addr", "inet", "opt", "IP", ["What is the computer's primary IP address?", "If you would like a random address assigned, leave this blank."]],
  ["hw_arch", "choice", "req", "Arch", ["What is the computer's hardware architecture?"]],
  ["os_type", "choice", "req", "OS", ["What is the computer's primary OS?"]],
  ["aliases", "list", "opt", "Aliases", ["List any DNS aliases the computer should have."]],
  ["classes", "list", "opt", "Classes", ["List any classes the computer should have (i.e. for tweak)."]],
  ["pxelink", "string", "opt", "PXE link", ["If needed, specify this computer's pxelink file."]],
  ["status", "string", "opt", "Status", ["Is this computer deployed?"]]];

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;

  foreach my $attr (@{$attrs}) {
    $self->set_attr(@{$attr});
  }

  $self->{attrs} = $attrs;

  return $self;
}

1;
