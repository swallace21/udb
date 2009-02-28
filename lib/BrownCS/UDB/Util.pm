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
  confirm
  demand
  edit
  fix_width
  fmt_time
  get_date
  ipv4_n2x
  fix_date
);

our %EXPORT_TAGS = ("all" => [@EXPORT_OK]);

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
  return $answer;
}

# demand :: string -> string
# Gets a nonempty line from the user.
sub demand {
  my($prompt, $default) = @_;
  while (1) {
    my $answer = $term->readline("$prompt ");
    if ($answer ne '') {
      return $answer;
    } else {
      print "Invalid answer. Please enter a non-empty string.\n"
    }
  }
}

# choose :: string * [(string * string * string)] -> string
# Gets an answer from the user. The answer must belong to a specified
# list.
sub choose {
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

sub fix_date {
  my($orig) = shift;
  my($month, $day, $year);

  if ( $orig =~ m%^\d+/\d+$% ) {
    ($month, $year) = ($orig =~ m%^(\d+)/(\d+)$% );
    $year = &fix_year($year);
    return "$year-$month-01";
  }

  if ( $orig =~ m%\d+-\d+-\d+$% ) {
    ($month, $day, $year) = ( $orig =~ m%(\d+)-(\d+)-(\d+)$% );
    $year = &fix_year($year);
    return "$year-$month-$day";
  }

  if ( $orig =~ m%^\d+-[A-Za-z]+-\d+$% ) {
    ($day, $month, $year) = ( $orig =~ m%^(\d+)-([A-Za-z]+)-(\d+)$% );
    $year = &fix_year($year);
    $month = &fix_month($month);
    return "$year-$month-$day";
  }
  return undef;
}

sub fix_month {
  my($month) = shift;

  if ( $month =~ /Jun/ ) {
    6;
  }
  elsif ( $month =~ /May/) {
    5;
  }
  else {
    '';
  }
}

sub fix_year {
  my($year) = shift;

  if ( $year > 100 ) {
    return $year;
  }

  if ( $year =~ /^0/ ) {
    $year = '20' . $year;
  }
  else {
    $year = '19' . $year;
  }
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
