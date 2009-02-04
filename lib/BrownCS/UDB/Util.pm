package BrownCS::UDB::Util;

use 5.010000;
use strict;
use warnings;

use Term::ReadKey;
use Term::ReadLine;
use File::Temp qw(tempfile);

use Exporter qw(import);

our @EXPORT_OK = qw(edit ask_password confirm ask);

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

  my ($fh, $filename) = tempfile();
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
  my($prompt, $default) = @_;
  while (1) {
    my $answer = $term->readline($prompt);
    if (($answer eq '') and (defined $default)) {
      return $default;
    } elsif ($answer ne '') {
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
  my($prompt, @choices) = @_;
  while (1) {
    my $answer = $term->readline($prompt);
    if ( grep { "$_" eq "$answer" } @choices ) {
      return $answer;
    } else {
      print "Invalid answer. You must enter one of the following: \n";
      foreach my $choice (@choices) {
        print "  $choice\n";
      }
    }
  }
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
