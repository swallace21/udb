package BrownCS::udb::Console;
use Moose;

use Term::ReadKey;
use Term::ReadLine;
use File::Temp qw(tempfile);
use BrownCS::udb::Util qw(:all);

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

sub get_management_type {
  my $self = shift;
  my ($default) = @_;
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
  my $classes_str = $self->ask($classes_prompt,'');
  $classes_str =~ s/\s//g;
  my @classes = split(/,/, $classes_str);
  return \@classes;
}

sub get_ip_and_vlan {
  my $self = shift;
  my $ip_or_vlan_preamble = <<EOF;
What is the computer's IP address?
If you just want an arbitrary IP in a given VLAN (e.g. 31, 36),
enter the VLAN number, and an IP will be picked for you.
EOF
  my $ip_or_vlan_prompt = "\n${ip_or_vlan_preamble}IP or VLAN:";
  my ($ipaddr, $vlan) = $self->demand($ip_or_vlan_prompt, verify_ip_or_vlan($self->udb));
  return ($ipaddr, $vlan);
}

sub get_port {
  my $self = shift;
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
  return $self->get_updated_val("Primary user", $default, \&verify_nonempty);
}

sub get_owner {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val(
    "Who paid for this computer?\nOwner",
    $default,
    \&verify_nonempty,
  );
}

sub get_room {
  my $self = shift;
  my ($default) = @_;
  return $self->get_updated_val("Room number", $default);
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
