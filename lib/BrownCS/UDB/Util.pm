package BrownCS::UDB::Util;

use 5.010000;
use strict;
use warnings;

use Term::ReadKey;
use Term::ReadLine;
use File::Temp qw(tempfile);

use Exporter qw(import);

our @EXPORT_OK = qw(edit ask_password confirm ask choose demand get_date fmt_time);

my $term = new Term::ReadLine 'udb';
$term->ornaments(0);

#
# static methods
#

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
  print "Password: ";
  ReadMode 'noecho';
  my $password = ReadLine 0;
  chomp $password;
  ReadMode 'normal';
  print "\n";

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
  my($title, $prompt) = @_;

  my ($fh, $filename) = tempfile(UNLINK => 1);
  system("whiptail --backtitle \"UDB\" --title \"$title\" --inputbox \"$prompt\" 0 0 ");
  my $answer = <$fh>;
  close($fh);

  return $answer;
}

# demand :: string -> string
# Gets a nonempty line from the user.
sub demand {
  my($title, $prompt) = @_;
  while (1) {

    my ($fh, $filename) = tempfile(UNLINK => 1);
    system("whiptail --backtitle \"UDB\" --title \"$title\" --input \"$prompt\" 0 0 ");
    my $answer = <$fh>;
    close($fh);

    if ($answer ne '') {
      return $answer;
    } else {
      print "Invalid answer. Please enter a non-empty string.\n"
    }
  }
}

# choose :: string * [string] -> string
# Gets an answer from the user. The answer must belong to a specified
# list.
sub choose {
  my($title, $prompt, $choices) = @_;

  my $menu_items = [];

  foreach my $choice (@{$choices}) {
    push @{$menu_items}, $choice;
    push @{$menu_items}, "";
  }

  my ($fh, $filename) = tempfile(UNLINK => 1);
  system("whiptail --backtitle \"UDB\" --title \"$title\" --menu \"$prompt\" 0 0 0 " .  join(" ", @{$menu_items}) . " 2>$filename");
  my $answer = <$fh>;
  close($fh);

  return $answer;
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

1;
__END__

=head1 NAME

BrownCS::UDB::Util - utility functions

=head1 SYNOPSIS

  use BrownCS::Util qw(ask_password confirm ask);

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
