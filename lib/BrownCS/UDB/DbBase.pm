package BrownCS::UDB::DbBase;

use 5.010000;
use strict;
use warnings;

my $error;

sub new {
  my $class = shift;
  my $self = {};

  bless $self, $class;

  $self->{alist} = [];		# to be filled by a subclass
  $self->{attrs} = {};		# ditto
  $self->{timestamp} = undef;	# ditto
  $self->{db} = undef;		# ditto
  $self->{error} = undef;	# filled in when there is an error

  return $self;
}

sub clear {
  my $self = shift;

  %$self = ();
}

sub attributes {
  my $self = shift;

  return @{$self->{alist}};
}

sub set_attr {
  my $self = shift;
  my $attr = shift;
  my $type = shift;
  my $reqd = shift;
  my $full = shift;
  my @cmts = @_;

  push @{$self->{alist}}, $attr;	# builds alist as a side effect

  $self->{attrs}->{$attr} = {
    type => $type,
    reqd => $reqd,
    full => $full,
    comments => @cmts,
  };
}

sub get_attr {
  my $self = shift;
  my $attr = shift;

  return () unless ref($self->{attrs}->{$attr});

  return (
    $self->{attrs}->{$attr}->{type},
    $self->{attrs}->{$attr}->{reqd}, 
    $self->{attrs}->{$attr}->{full}
  );
}

sub attr_type {
  my $self = shift;
  my $attr = shift;

  return $self->{attrs}->{$attr}->{type};
}

sub attr_reqd {
  my $self = shift;
  my $attr = shift;

  return $self->{attrs}->{$attr}->{reqd};
}

sub attr_name {
  my $self = shift;
  my $attr = shift;

  return $self->{attrs}->{$attr}->{full};
}

sub attr_comments {
  my $self = shift;
  my $attr = shift;

  return @{$self->{attrs}->{$attr}->{comments}};
}

sub timestamp {
  my $self = shift;

  return $self->{timestamp};
}

#
# $obj->error
# $obj->error($msg)
# $class->error
# $class->error($msg)
#
#   Get or set error message.  If called as an object method, gets or
#   sets the object's error message field.  If called as a class method,
#   gets or sets a global error message (which is useful for
#   constructor errors).
#
sub error {
  my $self = shift;
  my $msg = shift;
  my $eref;

  $eref = ref($self) ?  \$self->{error} : \$error;

  if ($msg) {
    $$eref = $msg;
  }
  return $$eref;
}

#
# $string = hash2str($self, $name, \@attrs, \%comments);
# $string = hash2str($self, $ref, \@attrs, \%comments);
#
#	Convert a hash to a string, suitable for displaying or writing to a
#	file.  This routine avoids building lines longer than 72 chars, if
#	possible, by breaking them up on whitespace with backslash-escaped
#	newlines.
#
sub hash2str {
  my $self = shift;
  my $name = shift;
  my @attrs = @{$self->{alist}};
  my (@result, $attr, @val, @line, $line, $len);
  my $maxlen = 72;

  my $ref = ref($name) ? $name : $self->get($name);

  my $attref = \@attrs;

  foreach $attr (@$attref) {
    foreach my $cmt ($self->attr_comments($attr)) {
      push(@result, "# " . $cmt);
    }
    if (defined $ref->{$attr}) {
      @val = ref($ref->{$attr}) ? @{$ref->{$attr}} :
      split(/\s+/, $ref->{$attr});
    }
    else {
      @val = ();
    }
    @line = ( $self->attr_name($attr) . (scalar(@val) ? ':' : ': '));
    $len = length $line[0];
    while ($_ = shift @val) {
      if (scalar(@line) && $len + length() > $maxlen) {
        $line = join(' ', @line);
        $line .= '\\' if scalar(@val);
        push(@result, $line);
        $len = 0;
        @line = ();
      }
      push @line, $_;
      $len += length() + 1;
    }
    push(@result, join(' ', @line)) if scalar(@line);
  }
  return join("\n", @result);
}

#
# $target_ref = $obj->merge($source_ref, $target_ref);
#
#   Simply overwrites fields in $target_ref with the values
#   from $source_ref, if they exist.  Other fields in $target_ref
#   are unchanged.
#
sub merge {
  my $self = shift;
  my $sref = shift;	# source hash reference (possibly sparse)
  my $tref = shift;	# target hash reference
  my @attrs = @{$self->{alist}};
  my ($attr);

  for $attr (@attrs) {
    if (defined $sref->{$attr}) {
      if (ref($sref->{$attr})) {
        unless (ref($sref->{$attr}) eq 'ARRAY') {
          $self->error("source attribute '$attr' is non-array reference");
          return undef;
        }
        $tref->{$attr} = [ @{$sref->{$attr}} ];
      }
      else {
        $tref->{$attr} = $sref->{$attr};
      }
    }
  }
  return $tref;
}

#
# $ref = str2hash($self, $string);
#
#	Parse a string representation of a hash, and convert it to
#	a hash.  Extra lines should be escaped with a backslash, but
#	this routine will properly append to the previous attribute's
#	value lines that do not begin with an attribute name.
#
sub str2hash {
  my $self = shift;
  my $string = shift;
  my $ref = {};
  my %attrs = map {$_, []} $self->attributes;
  my %newattrs;
  my %name2attr = map {$self->attr_name($_), $_} keys %attrs;
  my ($attr, $name, $last, $type);

  $string =~ s/^\s*#.*//gm;		# remove comments
  $string =~ s/\\\n/ /g;		# reattach split lines

  for (split(/\n/, $string)) {
    next if /^\s*$/;			# skip blank lines

    #
    # map full to short attribute name
    #
    if (/^([^:]+):\s*(.*)\s*$/ && defined $name2attr{$1}) {
      $attr = $name2attr{$1};

      if (defined $attrs{$attr}) {
        $newattrs{$attr} = [] unless defined $newattrs{$attr};
        push @{$newattrs{$attr}}, split(/\s+/, $2);
        $last = $attr;
      }
      else {
        $last = undef;
      }
    }
    elsif ($last) {
      push @{$newattrs{$last}}, split;
    }
  }
  for $attr (keys %newattrs) {
    $type = $self->attr_type($attr);
    if ($type eq 'string') {
      $ref->{$attr} = join(' ', @{$newattrs{$attr}});
    }
    else {
      $ref->{$attr} = $newattrs{$attr};
    }
  }
  return $ref;
}

1;
