package BrownCS::UDB::Util;

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
  get_key
  edit
  fix_width
  fmt_time
  get_date
  ipv4_n2x
  get_new
  bool
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
    if (&$verify_sub($answer)) {
      return $answer;
    } else {
      print "Invalid answer. Please try again.\n"
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

# get_date :: ???
# Return current date using nice format
sub get_date {
  my(@elems);
  my($raw);

  chop($raw = localtime(time));
  @elems = split(/\s+/, $raw);
  return $elems[2] . $elems[1] . substr($elems[4], -2);
}

# fmt_time :: ???
# Return specified time using nice format
sub fmt_time {
  my($time) = @_;
  my($sec, $min, $hour, $mday, $mon, $year) = localtime($time);

  my(@moname) = ( 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' );

  return "${mday}${moname[$mon]}${year} ${hour}:${min}:${sec}";
}

sub bool {
  my ($bool) = @_;
  return $bool ? "yes" : "no";
}

sub ipv4_n2x {
  my ($ipaddr_n) = @_;
  $ipaddr_n =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
  my $ipaddr_x = sprintf("%0.2X%0.2X%0.2X%0.2X", $1, $2, $3, $4);
  return $ipaddr_x;
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

1;
__END__

=head1 NAME

BrownCS::UDB::Util - utility functions

=head1 SYNOPSIS

  use BrownCS::Util qw(:all);

=head1 DESCRIPTION

Utility functions which are useful for the UDB library and helper
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
