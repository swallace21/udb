#!/usr/bin/perl -w

################################################################################
#
# Prologue
#
################################################################################

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);
use Data::Dumper;
use Getopt::Long;
use Fcntl;
use Term::ReadKey;
use Pod::Usage;

require 'ctime.pl';
require 'flush.pl';
require 'stat.pl';

$ENV{'PATH'} = '/usr/bin:/bin';
$ENV{'IFS'} = '' if(defined($ENV{'IFS'}) && $ENV{'IFS'} ne '');

my $PNAME = $0;
$PNAME =~ s:.*/::;

my $PVERS = '1.40';

my $VERSION  = "Copyright (c) 1996-2009, Brown University, Providence, RI\n";
$VERSION .= "$PNAME: version $PVERS by Mike Shapiro (mws\@cs.brown.edu)\n";

my $USAGE  = "Computer DataBase (CDB)\n\n";

# Default pathnames

my $PATH_CFFILE = '/tstaff/share/cdb/config.pl';
my $PATH_MKFILE = '/tstaff/share/cdb/.cdb_make.state';

my $SCP = '/usr/bin/scp';
my $SSH = '/usr/bin/ssh';

# Miscellaneous constants

my $DEF_DELIM = "\t";
my $MAXHOSTNAMELEN = 256;
my $MK_MODTIME = 0;
my $MK_BLDTIME = 1;
my $ADMINHOST = "adminhost";

# Declare hash of subcommands and the corresponding function

my %g_cdb_commands = (
  'addfield' => {
    'fn' => \&cdb_addfield,
    'desc' => ["add a new field to each record"],
    'usage' => "FIXME $PNAME addfield",
    'common' => 0,
  },
  'build' => {
    'fn' => \&cdb_build,
    'desc' => ["\tbuild one or all system maps"],
    'usage' => "$PNAME build [MAP]...",
    'common' => 0,
  },
  'verify' => {
    'fn' => \&cdb_verify,
    'desc' => ["verify that the database is consistent"],
    'usage' => "$PNAME verify",
    'common' => 0,
  },
  'insert' => {
    'fn' => \&cdb_insert,
    'desc' => ["insert a new host record"],
    'usage' => "$PNAME insert",
    'common' => 1,
  },
  'delete' => {
    'fn' => \&cdb_delete,
    'desc' => ["delete one or more host records"],
    'usage' => "$PNAME delete HOST...",
    'common' => 1,
  },
  'help' => {
    'fn' => \&cdb_help,
    'desc' => ["\tget extended usage info"],
    'usage' => "$PNAME help",
    'common' => 1,
  },
  'profile' => {
    'fn' => \&cdb_profile,
    'desc' => ["print a summary of a host"],
    'usage' => "$PNAME profile HOST",
    'common' => 1,
  },
  'make' => {
    'fn' => \&cdb_make,
    'desc' => ["\tbuild one or more system maps if needed"],
    'usage' => "$PNAME make [-P] [-n] [MAP]...",
    'common' => 1,
  },
  'print' => {
    'fn' => \&cdb_print,
    'desc' => ["\tprint one or more fields for all records"],
    'usage' => "$PNAME print FIELD...",
    'common' => 1,
  },
  'query' => {
    'fn' => \&cdb_query,
    'desc' => [
      "\tprint records which match the specified criteria",
      "Use \"$PNAME print\" for a list of fieldnames",
    ],
    'usage' => "$PNAME query FIELD=REGEXP...",
    'common' => 1,
  },
  'modify' => {
    'fn' => \&cdb_modify,
    'desc' => ["modify a host record"],
    'usage' => "$PNAME modify HOST [FIELD=VALUE]...",
    'common' => 1,
  },
  'classes' => {
    'fn' => \&cdb_classes,
    'desc' => ["list the classes to which the host belongs"],
    'usage' => "$PNAME classes HOST",
    'common' => 1,
  },
  'classlist' => {
    'fn' => \&cdb_classlist,
    'desc' => ["list the members of a class"],
    'usage' => "$PNAME classlist CLASS",
    'common' => 1,
  },
  'classadd' => {
    'fn' => \&cdb_classadd,
    'desc' => ["add one or more hosts to a class"],
    'usage' => "$PNAME classadd CLASS HOST...",
    'common' => 1,
  },
  'classdel' => {
    'fn' => \&cdb_classdel,
    'desc' => ["remove one or more hosts from a class"],
    'usage' => "$PNAME classdel CLASS HOST...",
    'common' => 1,
  },
  'contactlist' => {
    'fn' => \&cdb_contactlist,
    'desc' => ["print out a contact list for all hosts in a class"],
    'usage' => "$PNAME contactlist CLASS",
    'common' => 0,
  },
);

# Declare hash of active database fields and a corresponding description

my %g_cdb_fields = (
  'hostname' => 'Canonical host name',
  'aliases' => 'List of host aliases',
  'ip_addr' => 'IP address',
  'ethernet' => 'Ethernet address',
  'os_type' => 'Operating system type',
  'hw_arch' => 'Hardware architecture',
  'comment' => 'Comments',
  'contact' => 'Primary contact for this host',
  'mxhost' => 'Mail-exchanger for this host',
  'classes' => 'Classes for unattended installation',
  'status' => 'Machine status',
  'pxelink' => 'Image to use for net installs',
);

# Declare hash of active database fields and map dependency rules

my %g_cdb_map_dependencies = (
  'hostname' => [ 'hosts', 'hosts.equiv', 'ethers', 'netgroup', 'dns',
                  'bootparams', 'tftpboot', 'dhcp', 'wpkg-hosts' ],
  'aliases' => [ 'hosts', 'dns' ],
  'ip_addr' => [ 'hosts', 'dns', 'bootparams', 'tftpboot', 'dhcp' ],
  'ethernet' => [ 'ethers', 'dhcp' ],
  'dhcp' => [ 'ethers', 'dhcp' ],
  'os_type' => [ 'bootparams', 'tftpboot', 'wpkg-hosts' ],
  'hw_arch' => [ 'bootparams', 'tftpboot', 'wpkg-hosts' ],
  'comment' => [ ],
  'mxhost' => [ 'dns' ],
  'classes' => [ 'wpkg-hosts', 'netgroup' ],
  'status' => [ 'ethers', 'hosts', 'dns', 'dhcp' ],
);

# Declare hash of active database fields and corresponding help functions

my %g_cdb_help = (
  'hostname' => \&help_hostname,
  'aliases' => \&help_aliases,
  'ip_addr' => \&help_ip_addr,
  'ethernet' => \&help_ethernet,
  'os_type' => \&help_os_type,
  'hw_arch' => \&help_hw_arch,
  'comment' => \&help_comment,
  'mxhost' => \&help_mxhost,
  'status' => \&help_status,
);

# Declare hash of fields which require custom canonicalization subroutines

my %g_cdb_canons = (
  'hostname' => \&canon_hostname,       # Convert to lowercase
  'aliases' => \&canon_aliases,         # Convert each alias to lowercase
  'ip_addr' => \&canon_ip_addr,         # Strip leading zeroes
  'ethernet' => \&canon_ethernet,       # Strip leading zeroes
  'mxhost' => \&canon_hostname,         # Convert to lowercase
);

# Declare hash of fields which require custom verification subroutines

my %g_cdb_verifications = (
  'hostname' => \&verify_hostname,      # Verify hostname is not already taken
  'aliases' => \&verify_aliases,        # Verify aliases are not already taken
  'comment' => \&verify_comment,        # Verify some prim_grps have comments
  'ip_addr' => \&verify_ip_addr,        # Verify format, uniqueness
  'ethernet' => \&verify_ethernet,      # Verify format, uniqueness
  'os_type' => \&verify_os_type,        # Verify existence in os_specs file
  'status' => \&verify_status           # Verify some prim_grps have status
);

# Declare hash of fields which require custom sort comparison subroutines

my %g_cdb_comparisons = (
  'ip_addr' => \&compare_ip_addr,       # Compare IP addrs by subnet
  'ethernet' => \&compare_ethernet      # Compare ethernet addrs by nibble
);

# Declare hash of maps we build from the database and their subroutines

my %g_cdb_maps = (
  'ethers' => \&build_ethers,                   # Construct /etc/ethers NIS map
  'hosts' => \&build_hosts,                     # Construct /etc/hosts NIS map
  'hosts.equiv' => \&build_hosts_equiv,         # Construct /etc/hosts.equiv file
  'bootparams' => \&build_bootparams,           # Construct /etc/bootparams NIS map
  'netgroup' => \&build_netgroup,               # Construct /etc/netgroup NIS map
  'tftpboot' => \&build_tftpboot,               # Construct /tftpboot directory
  'dhcp' => \&build_dhcp,                       # Construct dhcpd.conf directory
  'dns' => \&build_dns,                         # Construct named data files
  'nagios-hosts' => \&build_nagios_hosts,       # Construct nagios hosts.cfg file
  'nagios-services' => \&build_nagios_services, # Construct nagios services.cfg file
  'wpkg-hosts' => \&build_wpkg_hosts,           # Construct wpkg hosts.xml file
);

# Declare hash tables of include keys for extra error checking

my %g_cdb_include_ethers = ();
my %g_cdb_include_ip_addrs = ();
my %g_cdb_include_hosts = ();

# Declare list of servers to which files should be propagated
# (NIS master should not be in this list).

# Declare array of temporary files, to be deleted upon exit
my @g_tmpfiles = ();

# Parse the command-line, load the database file, and execute a command

my $help = 0;
my $verbose = 0;
my $version = 0;
my $username = $ENV{'USER'};

GetOptions ('help|h|?' => \$help, 
            'v|verbose' => \$verbose,
            'version' => \$version,
            'u' => \$username) or usage(2);
usage(1) if $help;

if ($version) {
  print $VERSION;
  exit(0);
}

if (@ARGV == 0) {
  usage(0);
}

print "Password: ";
ReadMode 'noecho';
my $password = ReadLine 0;
chomp $password;
ReadMode 'normal';
print "\n";

my $dbname = "udb";
my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=db", $username, $password,
  {AutoCommit=>0, pg_errorlevel=>2}) or die "Couldn't connect to database: " . DBI->errstr;

my $sths = {};

# $dbh->trace('SQL');

# Print a simple help message.
sub usage {
  my ($exit_status) = @_;
  print $USAGE;
  print "basic commands:\n\n";
  foreach $k (sort(keys(%g_cdb_commands))) {
    next if $g_cdb_commands{$k}{'common'} == 0;
    print "  $k\t" . $g_cdb_commands{$k}{'desc'}[0] . "\n";
  }
  print "\nuse \"$PNAME help\" for details\n";
  exit($exit_status);
}

# Print a simple help message for a specific command.
sub command_help {
  my ($cmd) = @_;
  print "Usage: ";
  print $g_cdb_commands{$cmd}{"usage"} , "\n\n";
  my $lines = $g_cdb_commands{$cmd}{"desc"};
  foreach $line (@$lines) {
    $line =~ s/^\s+//;
    print "  \u$line.\n";
  }
  print "\n";
}

#
# FUNCTION: get_date
#    DESCR: Return current date using nice format
#

sub get_date {
  my(@elems);
  my($raw);

  chop($raw = ctime(time));
  @elems = split(/\s+/, $raw);
  return $elems[2] . $elems[1] . substr($elems[4], -2);
}

#
# FUNCTION: fmt_time
#    DESCR: Return specified time using nice format
#

sub fmt_time {
  my($time) = @_;
  my($sec, $min, $hour, $mday, $mon, $year) = localtime($time);

  my(@moname) = ( 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' );

  return "${mday}${moname[$mon]}${year} ${hour}:${min}:${sec}";
}

#
# FUNCTION: init_make_state
#    DESCR: Initialize a new make state hash and return a reference to it.
#           The hash consists of the names of maps, and a reference to an
#           array of two elements containing the last modification time of
#           the map's data, and the last build time of the map.
#

sub init_make_state {
  my($states) = {};
  warn "$PNAME: WARNING: All maps will be rebuilt at next make\n";
  foreach $map (keys(%g_cdb_maps)) { $states->{$map} = [ 0, 0 ]; }
  return $states;
}

#
# FUNCTION: load_make_state
#    DESCR: Load the cdb make state file, creating a new one if necessary.
#           You should only load the make state file once you have established
#           a write-lock on the database, since we don't do any locking here.
#

sub load_make_state {
  my($file) = @_;
  my($states) = {};
  my(@tokens);

  if(open(MKSTATE, "<$file")) {
    while(<MKSTATE>) {
      next if(/^\s*$/ || /^\s*#/);      # Skip blank lines and comments
      chop($_);                         # Remove newline
      @tokens = split(/:/, $_);         # Split line into tokens

      # Each line must contain exactly three tokens

      if(scalar(@tokens) != 3) {
        warn "$PNAME: WARNING: Invalid number of tokens on line $. of $file\n";
        $states = init_make_state();
        last;
      }

      # First token must be a valid map name

      if(!defined($g_cdb_maps{$tokens[0]})) {
        warn "$PNAME: WARNING: Bad map \"$tokens[0]\" on line $. of $file\n";
        $states = init_make_state();
        last;
      }

      # Each map may only have a single state line in the file

      if(defined($states->{$tokens[0]})) {
        warn "$PNAME: WARNING: \"$tokens[0]\" redefined on line $. of $file\n";
        $states = init_make_state();
        last;
      }

      # Remaining two tokens should be numbers

      if($tokens[1] !~ /^\d+$/ || $tokens[2] !~ /^\d+$/) {
        warn "$PNAME: WARNING: Invalid time on line $. of $file\n";
        $states = init_make_state();
        last;
      }

      $states->{$tokens[0]} = [ $tokens[1], $tokens[2] ];
    }

    close(MKSTATE);

    # Verify that all maps have been defined in the state file

    foreach $map (keys(%g_cdb_maps)) {
      unless(defined($states->{$map})) {
        warn "$PNAME: WARNING: Map \"$map\" not defined in $file\n";
        $states = init_make_state();
        last;
      }
    }
  
  } else {
    warn "$PNAME: WARNING: Cannot open $file: $!\n";
    $states = init_make_state();
  }

  return $states;
}

#
# FUNCTION: write_make_state
#    DESCR: Write out new make state file from states hash.  This function
#           should always be called _after_ write_db so that the state file
#           has a more recent modification time than the database file.
#

sub write_make_state {
  my($states, $file) = @_;

  open(MKSTATE, ">$file") || die "$PNAME: Failed to rewrite $file: $!\n";

  print MKSTATE "#\n#  FILE: $file\n";
  print MKSTATE "# DESCR: Cdb make state file -- DO NOT EDIT THIS FILE!\n#\n";

  foreach $map (keys(%$states)) {
    print MKSTATE $map, ':', $states->{$map}->[0], ':',
      $states->{$map}->[1], "\n";
  }

  close(MKSTATE);
  chmod($CDB_DBF_PERMS, $file);
  chown($>, (getgrnam($CDB_DBF_GROUP))[2], $file);
}

#
# FUNCTION: touch_make_state
#    DESCR: Update modification time on a make state hash entry.
#

sub touch_make_state {
  my($states, $map) = @_;
  $states->{$map}->[$MK_MODTIME] = time();
}

#
# FUNCTION: update_make_state
#    DESCR: Update the build time on a make state hash entry.
#

sub update_make_state {
  my($states, $map) = @_;
  $states->{$map}->[$MK_BLDTIME] = time();
}

sub cleanup {
  foreach $sth (values %sths) {
    $sth->finish;
  }

  if ($dbh) {
    $dbh->disconnect;
  }

  foreach (@g_tmpfiles) {
    unlink($_);
  }
}

#
# FUNCTION: sighandler
#    DESCR: Clean up and quit if we receive a signal
#

sub sighandler {
  print "\n*** Termination signal received\n";
  cleanup();
  exit(0);
}

#
# FUNCTION: END
#    DESCR: Exit handler to clean things up in case we die.
#

END {
  cleanup();
}

#
# FUNCTION: parse_ethernet_includes
#    DESCR: Build hash of ethernet address keys from include file for ethers
#           NIS map.
#

sub parse_ethernet_includes {
  my($include) = $cdb_map_includes{'ethers'};
  my($line);

  return if(!defined($cdb_map_includes{'ethers'}) || ! -f("$include"));

  open(ETHERS, "<$include") ||
    die "$PNAME: ERROR: Failed to open $include: $!\n";

  while(<ETHERS>) {
    ($line = $_) =~ s/#.*//;
    next if($line =~ /^\s*$/);
    
    if($line !~ /^\s*([a-fA-F0-9:]+)\s+(\w+)\s*$/) {
      warn "$PNAME: WARNING: \"$include\", line ${.}: Invalid ethers syntax\n";
      next;
    }

    $g_cdb_include_ethers{$1} = $2;
  }

  close(ETHERS);
}

#
# FUNCTION: parse_host_includes
#    DESCR: Build hash of host names, aliases, and IP addresses from include
#           file for NIS hosts map.
#

sub parse_host_includes {
  my($include) = $cdb_map_includes{'hosts'};
  my($line);

  return if(!defined($cdb_map_includes{'hosts'}) || ! -f ("$include"));

  open(HOSTS, "<$include") ||
    die "$PNAME: ERROR: Failed to open $include: $!\n";

  while(<HOSTS>) {
    ($line = $_) =~ s/#.*//;
    next if($line =~ /^\s*$/);

    if($line !~ /^\s*([0-9\.]+)\s+(\S.+)$/) {
      warn "$PNAME: WARNING: \"$include\", line ${.}: Invalid hosts syntax\n";
      next;
    }

    foreach $name (split(/\s+/, $2)) {
      $g_cdb_include_ip_addrs{$1} = $2
        if(!defined($g_cdb_include_ip_addrs{$1}));
      $g_cdb_include_hosts{$name} = $1;
    }
  }

  close(HOSTS);
}

#
# FUNCTION: sort_fieldnames
#    DESCR: Sort field names alphabetically, except put hostname, prim_grp
#           first.
#

sub sort_fieldnames {
  return -1 if($a eq 'hostname');
  return 1 if($b eq 'hostname');
  return $a cmp $b;
}

#
# FUNCTION: sort_hostnames
#    DESCR: Sort comparison function for list of hostnames using
#           user-defined sort fields
#

sub sort_hostnames {
  my($a_value, $b_value);

  foreach $field (@g_sort_order) {
    $a_value = $cdb_by_hostname->{$a}{$field};
    $b_value = $cdb_by_hostname->{$b}{$field};
    
    if(defined($g_cdb_comparisons{$field})) {
      return &{ $g_cdb_comparisons{$field} }($a_value, $b_value);
    } else {
      return $a_value cmp $b_value if($a_value ne $b_value);
    }
  }

  return 0;
}

#
# FUNCTION: compare_ip_addr
#    DESCR: Compare IP addresses for sorting
#

sub compare_ip_addr {
  my($lval, $rval) = @_;
  my(@lnibbles) = split(/\./, $lval);
  my(@rnibbles) = split(/\./, $rval);

  foreach $i (0 .. $#lnibbles) {
    return $lnibbles[$i] <=> $rnibbles[$i] if($lnibbles[$i] != $rnibbles[$i]);
  }

  return 0;
}

#
# FUNCTION: compare_ethernet
#    DESCR: Compare ethernet addresses for sorting
#

sub compare_ethernet {
  my($lval, $rval) = @_;
  my(@lnibbles) = split(/:/, $lval);
  my(@rnibbles) = split(/:/, $rval);
  my($lnibble, $rnibble);

  foreach $i (0 .. $#lnibbles) {
    $lnibble = hex($lnibbles[$i]);
    $rnibble = hex($rnibbles[$i]);
    return $lnibble <=> $rnibble if($lnibble != $rnibble);
  }

  return 0;
}

#
# FUNCTION: verify_hostname
#    DESCR: Verify hostname field modifications.  Since we don't want anyone
#           doing the forbidden hostname change, disallow any value different
#           from the key.  Also, make sure hostname doesn't contain certain
#           banned characters
#

sub verify_hostname {
  my($key, $value) = @_;

  if($value eq '') {
    warn "$PNAME: Hostname may not be empty\n";
    return 0;
  }

  if($key ne $value) {
    warn "$PNAME: Hostname \"$value\" does not match database record key\n";
    return 0;
  }

  if($value !~ /^[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9]$/) {
    warn "$PNAME: Hostname must start with a letter, contain any number of letters, digits, and hyphens, and end with a letter or a digit.\n";
    return 0;
  }

  if(defined($g_cdb_include_hosts{$key})) {
    warn "$PNAME: Hostname \"$key\" is already defined as a name or alias in ",
      $cdb_map_includes{'hosts'}, "\n";
    return 0;
  }

  return 1;
}

#
# FUNCTION: verify_prim_grp
#    DESCR: Verify that the primary group is defined in the config file.
#

sub verify_prim_grp {
  my($key, $value) = @_;

  if(!defined($cdb_primary_groups{$value})) {
    warn "$PNAME: Host ${key}'s prim_grp \"$value\" not defined in config\n";
    return 0;
  }

  return 1;
}

#
# FUNCTION: verify_aliases
#    DESCR: Verify alias field modifications.  For each alias, we make sure
#           that it is of appropriate length, contents, and matches no other
#           alias or hostname we know about.
#

sub verify_aliases {
  my($key, $value) = @_;
  my(@newaliases) = sort split(/,/, $value);
  my(@aliases);

  foreach $i (0 .. $#newaliases) {
    if($newaliases[$i] eq $key) {
      warn "$PNAME: Alias \"$newaliases[$i]\" matches hostname\n";
      return 0;
    }

    if(length($newaliases[$i]) > $MAXHOSTNAMELEN) {
      warn "$PNAME: Alias \"$newaliases[$i]\" exceeds maximum name length\n";
      return 0;
    }

    if($newaliases[$i] !~ /[a-z][a-z0-9_\-]*/) {
      warn "$PNAME: Alias \"", $newaliases[$i],
        "\" does not match \"[a-z][a-z0-9_\-]*\" format\n";
      return 0;
    }

    if($newaliases[$i] eq $newaliases[$i + 1]) {
      warn "$PNAME: Duplicate alias \"", $newaliases[$i],
        "\" detected in alias list\n";
      return 0;
    }

    if(defined($g_cdb_include_hosts{$newaliases[$i]})) {
      warn "$PNAME: Alias \"", $newaliases[$i],
        "\" is already defined as a name or alias in ",
        $cdb_map_includes{'hosts'}, "\n";
      return 0;
    }
  }

  foreach $host (keys(%$cdb_by_hostname)) {
    next if($host eq $key);
    @aliases = split(/,/, $cdb_by_hostname->{$host}{'aliases'});   

    foreach $alias (@newaliases) {
      if($alias eq $host) {
        warn "$PNAME: Host alias \"$alias\" is already an existing hostname\n";
        return 0;
      }

      foreach $oldalias (@aliases) {
        if($alias eq $oldalias) {
          warn "$PNAME: Host alias \"$alias\" is already an alias for host ",
            "\"$host\"\n";
          return 0;
        }
      }
    }
  }

  return 1;
}

#
# FUNCTION: verify_comment
#    DESCR: Verify that any host with a prim_grp of "dynamic" has a comment
#           field
#

sub verify_comment {
  my($key, $value) = @_;
  my($prim_grp) = $cdb_by_hostname->{$key}{'prim_grp'};

  if("$prim_grp" eq "dynamic") {
    if($value eq "") {
      warn "$PNAME: Comments are required for hosts with dynamic addresses.\n";
      warn "        Be sure to include the username of person responsible \n";
      warn "        for managing the machine \"$key\".  If the machine will\n";
      warn "        only be used temporarily, please include an expiration\n";
      warn "        date.\n";
      return 0;
    }
  }

  return 1;
}

#
# FUNCTION: verify_ip_addr
#    DESCR: Verify IP address field is valid.  It must take one of two forms:
#           1) dotted-decimal format that contains the proper values or 
#           range for each nibble, and does not match any other host's address.
#
#           2) a vlan or subnet entry that must be one of those contained in
#           @cdb_dynamic_subnets
#

sub verify_ip_addr {
  my($key, $value) = @_;
  my(@nibbles);
  my($prim_grp) = $cdb_by_hostname->{$key}{'prim_grp'};

  if("$prim_grp" eq "dynamic") {
    if ($value ne "") {
      warn "$PNAME: hosts with a dynamic primary group should have a blank IP address\n";
      return 0;
    }
  }
  
  if($value =~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/) {

    @nibbles = split(/\./, $value);

    foreach $i (0 .. $#nibbles) {
      if($nibbles[$i] =~ /^0[1-9]+/) {
        warn "$PNAME: IP address for $key should not contain leading zeroes\n";
        return 0;
      }
    }

    if ("$prim_grp" ne "ilab") {
      foreach $nibble (@nibbles) {
        if($nibble < 1 || $nibble > 254) {
          warn "$PNAME: IP address nibbles for $key must be in range 1-254\n";
          return 0;
        }
      }
    } 

    if ("$prim_grp" eq "private" || "$prim_grp" eq "switch") {
      foreach $i (0 .. $#private_ip_nibbles) {
        if ($private_ip_nibbles[$i] != $nibbles[$i]) {
           warn "$PNAME: IP address component ", $i + 1,
             " for $key must be ", $private_ip_nibbles[$i], "\n";
           return 0;
        }
      }
    } elsif ("$prim_grp" eq "cis") {
      foreach $i (0 .. $#cis_ip_nibbles) {
        if($cis_ip_nibbles[$i] != $nibbles[$i]) {
          warn "$PNAME: IP address component ", $i + 1,
            " for $key must be ", $cis_ip_nibbles[$i], "\n";
          return 0;
        }
      }
    } elsif ("$prim_grp" eq "ilab") {
      foreach $i (0 .. $#ilab_ip_nibbles) {
        if($ilab_ip_nibbles[$i] != $nibbles[$i]) {
          warn "$PNAME: IP address component ", $i + 1,
            " for $key must be ", $ilab_ip_nibbles[$i], "\n";
          return 0;
        }
      }
                } elsif ("$prim_grp" eq "vpn") {
      foreach $i (0 .. $#vpn_ip_nibbles) {
        if($vpn_ip_nibbles[$i] != $nibbles[$i]) {
          warn "$PNAME: IP address component ", $i + 1,
            " for $key must be ", $vpn_ip_nibbles[$i], "\n";
          return 0;
        }
      }
    } else {
      foreach $i (0 .. $#cdb_ip_nibbles) {
        if($cdb_ip_nibbles[$i] != $nibbles[$i]) {
          warn "$PNAME: IP address component ", $i + 1,
            " for $key must be ", $cdb_ip_nibbles[$i], "\n";
          return 0;
        }
      }
    }

    if(defined($g_cdb_include_ip_addrs{$value})) {
      warn "$PNAME: IP address $value for $key is already assigned to ",
        $g_cdb_include_ip_addrs{$value}, " in ",
        $cdb_map_includes{'hosts'}, "\n";
      return 0;
    }

    foreach $host (keys(%$cdb_by_hostname)) {
      next if($host eq $key);
  
      if($cdb_by_hostname->{$host}{'ip_addr'} eq $value) {
        warn "$PNAME: IP address $value for $key is already assigned to $host\n";
        return 0;
      }
    }
  } elsif("$prim_grp" eq "dynamic") {
      # if we are in the dynamic group, we don't need to specify an IP
      return 1;
  } else {
    warn "$PNAME: IP address \"$value\" does not match dotted-decimal format\n";
    warn "        nor is \"$value\" a subnet supporting dynamic addresses\n";
    return 0;
  }

  return 1;
}

#
# FUNCTION: verify_ethernet
#    DESCR: Verify ethernet address by making sure it is in the proper format.
#

sub verify_ethernet {
  my($key, $value) = @_;
  my($prim_grp) = $cdb_by_hostname->{$key}{'prim_grp'};
  my(@nibbles);
  
  # Allow empty ethernet field if this host's primary netgroup does have
  # the $NG_ETHERS attribute set in the cdb configuration file

  if($value eq '') {
    if(($cdb_primary_groups{$prim_grp} & $NG_ETHERS) == 0) {
      return 1;
    } else {
      warn "$PNAME: You must specify an ethernet address\n";
      return 0;
    }
  } 

  if($value !~ /^([0-9a-f]{1,2}:){5}[0-9a-f]{1,2}$/) {
    warn "$PNAME: Ethernet address for $key should be 48-bit address using ",
      "only [0-9a-f:] chars\n";
    return 0;
  }

  @nibbles = split(/:/, $value);

  foreach $i (0 .. $#nibbles) {
    if($nibbles[$i] =~ /^0[1-9a-f]+/) {
      warn "$PNAME: Ethernet address for $key may not contain leading zero\n";
      return 0;
    }
  }

  return 1;
}

#
# FUNCTION: verify_os_type
#    DESCR: Verify that OS type specifier exists in os specs hash.
#

sub verify_os_type {
  my($key, $value) = @_;
  my($prim_grp) = $cdb_by_hostname->{$key}{'prim_grp'};
  
  if (($value eq '') || (!defined($cdb_os_types->{$value}))) {
    warn "$PNAME: You must specify a valid os_type for this host\n";
    warn "$PNAME: os_type must be one of:\n";
    foreach $os (keys %$cdb_os_types) {
      warn "\t$os\n";
    }
    return 0;
  } 

  return 1;
}

#
# FUNCTION: verify_status
#    DESCR: Verify that status is one of those listed in cdb_status_strings
#           Verify that any host with a prim_grp of "dynamic" has either
#           active or disabled status
#

sub verify_status {
  my($key, $value) = @_;
  my($prim_grp) = $cdb_by_hostname->{$key}{'prim_grp'};

  # check to make sure we have a valid status
  if (! ((grep /^$value$/, @cdb_status_strings) && $value)) {
    warn "$PNAME: status must be one of:\n";
    foreach $status (@cdb_status_strings) {
      warn "\t$status\n";
    }
    return 0;
  }
  
  if("$prim_grp" eq "dynamic") {
    if(! ($value eq "active" | $value eq "disabled")) {
      warn "$PNAME: hosts with dynamic addresses require either an \n";
      warn "        \"active\" or \"disabled\" status.\n";
      return 0;
    }
  }

  return 1;
}


#
# FUNCTION: canon_hostname
#    DESCR: Convert hostname to lowercase and remove whitespace
#

sub canon_hostname {
  my($hostname) = @_;
  $hostname =~ tr/A-Z/a-z/;
  $hostname =~ s/\s+//g;
  return $hostname;
}

#
# FUNCTION: canon_aliases
#    DESCR: Convert aliases to lowercase and remove whitespace
#

sub canon_aliases {
  my($aliases) = @_;
  my(@alist) = split(/,/, $aliases);
  foreach $i (0 .. $#alist) {
    $alist[$i] =~ tr/A-Z/a-z/;
    $alist[$i] =~ s/\s+//g;
  }
  return join(',', @alist);
}

#
# FUNCTION: canon_ip_addr
#    DESCR: Strip leading zeroes and whitespace from IP address string
#

sub canon_ip_addr {
  my($ip_addr) = @_;
  my(%ip_addrs) = ();
  my(@nibbles, $addr);

  $ip_addr =~ s/\s+//g;
  @nibbles = split(/\./, $ip_addr);
  foreach $i (0 .. $#nibbles) { $nibbles[$i] =~ s/^0(.+)$/$1/; }
  return join('.', @nibbles) if($nibbles[3] ne '*');

  # Build hash of used IP addresses to avoid for '*' replacement

  foreach $host (keys(%$cdb_by_hostname)) {
    $addr = $cdb_by_hostname->{$host}{'ip_addr'};
    $ip_addrs{$addr} = 1;
  }

  # Strip trailing nibble, which is '*'

  pop(@nibbles);

  # Try all values for $nibbles[3] in ascending order from 2 to 254.
  # 255 is the broadcast address, 0 is the network address, and 1 we reserve
  # so it can be manually assigned by sysadmins to routers.

  for($i = 2; $i < 255; $i++) {
    $addr = join('.', @nibbles) . ".$i";
    print "Trying $addr ...\n" if($opt_v);
    next if(defined($ip_addrs{$addr}));
    next if(defined($g_cdb_include_ip_addrs{$addr}));
    return $addr;
  }

  die "$PNAME ERROR: No addresses are available for the $nibbles[2] subnet\n";
}

#
# FUNCTION: canon_ethernet
#    DESCR: Strip leading zeroes from Ethernet address string and convert
#           uppercase hex characters to lowercase and remove whitespace
#

sub canon_ethernet {
  my($ether) = @_;
  my(@nibbles);

  $ether =~ s/\s+//g;
  @nibbles = split(/:/, $ether);
  foreach $i (0 .. $#nibbles) {
    $nibbles[$i] =~ s/^0(.+)$/$1/;
    $nibbles[$i] =~ tr/A-F/a-f/;
  }
  return join(':', @nibbles);
}


#
# FUNCTION: search_dir
#    DESCR: given a parent directory and a list of names, recursively
#    descend the directory tree looking for filenames that match those
#    in the namelist.  Two arrays determine special behavior: the
#    g_prune_list and the g_grep_list.  The g_prune_list contains
#    directory names which should not be descended into.  Instead, the
#    name of the directory should be compared to the namelist.  The
#    g_grep_list contains all files which are expected to have a name
#    IN them, rather than be named host.xxx or netgroup.xxx.  The
#    host. or netgroup. is stripped from namelist entries and those
#    entries are searched for in g_grep_list files.
#

$g_parents_open = 0;

sub search_dir {
  my($root, $parent, @namelist) = @_;
  my($dirent, @dirents, $found, $name);
  my($dirname) = "PD_$g_parents_open";
  my(@retlist);
  $g_parents_open++;

  if (!(opendir($dirname, "$parent"))) {
    warn "Could not open $parent directory\n";
    return;
  }

  @dirents = grep(!/^\.\.?$/, readdir($dirname));

  undef $found;
  $_ = 0;
  for ($[ .. $#g_prune_list) {
    $found = $_, last if ("$root/$g_prune_list[$_]" eq "$parent");
  }
  if (defined($found)) {
    foreach $dirent (@dirents) {
      foreach $name (@namelist) {
        if ("$name" eq "$dirent") {
          push(@retlist, "$parent/$dirent\n");
        }
      }
    }
  } else {
    foreach $dirent (@dirents) {
      if ( -d "$parent/$dirent" && !( -l "$parent/$dirent")) {
        # descend recursively
        push(@retlist, search_dir($root, "$parent/$dirent", @namelist));

      } elsif ( -f "$parent/$dirent" ) {
        undef $found;
        for ($[ .. $#g_grep_list) {
          $found = $_, last if ("$root/$g_grep_list[$_]" eq "$parent/$dirent");
        }
        if (defined($found)) {
          if (!(open(GREPFILE, "$parent/$dirent"))) {
            warn "Could not open $dirent file\n";
            return;
          }
          while (<GREPFILE>) {
            chop;
            foreach $name (@namelist) {
              if ("$name" eq "host.$_") {
                push(@retlist, "$parent/$dirent\n");
              }
            }
          }
          close(GREPFILE);

        } else {
          foreach $name (@namelist) {
            if ("$name" eq "$dirent") {
              push(@retlist, "$parent/$dirent\n");
            }
          }
        }
      }
    }
  }
  close($dirname);
  $g_parents_open--;

  return @retlist;
}
    


#
# FUNCTION: print_tree
#    DESCR: given the root of a file tree, print the subdirectories
#    and their files in a pretty picture.
#

sub print_tree {
  my($g_root, $root, $indent) = @_;
  my($dirent, @dirents, $found);
  my($dirname) = "DIR_$g_parents_open";
  my($base) = rindex($root, "/");

  if ($indent == 0) {
    printflush('STDOUT', "$root/:\n");
  }
  
  
  printflush('STDOUT', ' 'x$indent, substr($root,($base+1)), "/:\n");
  if (!(opendir($dirname, "$root"))) {
    warn "can't open $root\n";
    return 1;
  }

  @dirents = grep(!/^\.\.?$/, readdir($dirname));
  foreach $dirent (@dirents) {
    if (-l "$root/$dirent") {
      printflush('STDOUT', ' 'x($indent+2), "$dirent", '@', "\n");
    } elsif (-d "$root/$dirent") {
      undef $found;
      for ($[ .. $#g_ignore_dirs) {
        $found = $_, last if ("$g_root/$g_ignore_dirs[$_]" eq "$root/$dirent");
      }
      if (!defined($found)) {
        print_tree($g_root, "$root/$dirent", ($indent+2));
      }
    } else {
      printflush('STDOUT', ' 'x($indent+2), "$dirent\n");
    }
  }
  close($dirname);
}
  

#
# FUNCTION: help_hostname
#    DESCR: Print out some information about the hostname field
#

sub help_hostname {
  print "The hostname field determines the canonical name for the host.\n",
        "The name should consist of letters, digits, and underscores and\n",
        "must not begin with a digit.  cdb will automatically verify that\n",
        "the name you have chosen is unique, and will remove whitespace and\n",
        "convert uppercase characters to their lowercase equivalents.  The\n",
        "name should not be longer than $MAXHOSTNAMELEN characters.\n";
}

#
# FUNCTION: help_prim_grp
#    DESCR: Print out some information about the primary netgroup field
#

sub help_prim_grp {
  my($attrs);

  print "The prim_grp field determines the primary netgroup for the host.\n",
        "The name should consist of letters, digits, and underscores.  This\n",
        "table shows the valid primary groups and their attributes:\n\n";

  foreach $grp (sort(keys(%cdb_primary_groups))) {
    $attrs = $cdb_primary_groups{$grp};
    print "  $grp\n";
    print "    Add host to NIS ethers map\n" if($attrs & $NG_ETHERS);
    print "    Add host to NIS hosts map\n" if($attrs & $NG_HOSTS);
    print "    Add host to /etc/hosts.equiv\n" if($attrs & $NG_EQUIV);
    print "    Add host to NIS bootparams map\n" if($attrs & $NG_BOOTP);
    print "    Add host to NIS netgroup map\n" if($attrs & $NG_NETGR);
    print "    Add network boot image to /tftpboot\n" if($attrs & $NG_TFTP);
    print "    Allow host to get a dynamic IP address\n" if($attrs & $NG_DHCP);
    print "    Add DNS record for host\n" if ($attrs & $NG_DNS);
  }

  print "\n";
}

#
# FUNCTION: help_aliases
#    DESCR: Print out some information about the host aliases field
#

sub help_aliases {
  print "The aliases field is a comma-separated list of NIS and DNS host\n",
        "aliases.  Each name should consist of letters, digits, and\n",
        "underscores and must not begin with a digit.  cdb will verify that\n",
        "each name you enter is unique, and will remove whitespace and\n",
        "convert uppercase characters to their lowercase equivalents.  Each\n",
        "alias should not be longer than $MAXHOSTNAMELEN characters.\n";
}

#
# FUNCTION: help_comment
#    DESCR: Print out some information about the comment field
#

sub help_comment {
  print "The comment field contains a single line of text allowing the\n",
        "administrator to record comments or notes about each host.\n";
}

#
# FUNCTION: help_os_type
#    DESCR: Print out some information about the OS type field
#

sub help_os_type {
  print "The OS specifier field matches an entry in the cdb os specifier\n",
        "database, which is currently: $PATH_CFFILE\n",
        "You may leave this field blank if no appropriate value exists.\n",
        "Valid os_types are:";

  foreach $os (sort(keys(%$cdb_os_types))) { print ' ', $os; }
  print "\n";
}

#
# FUNCTION: help_hw_arch
#    DESCR: Print out some information about the hardware architecture field
#

sub help_hw_arch {
  print "The hw_arch field contains a hardware architecture description\n",
        "string.  This is typically obtained using the 'uname -n' or\n",
        "'arch' command on the given host.\n  Leave this field blank for\n",
        "unsupported machines or non-workstation hardware.";
}

#
# FUNCTION: help_ip_addr
#    DESCR: Print out some information about the IP address field
#

sub help_ip_addr {
  my($tmp) = $";
  $" = '.';

  print "The IP address field contains the Internet address for the host\n",
        "in dotted-decimal format.  cdb will automatically strip leading\n",
        "zeroes from each address component.  If the final address\n",
        "component is specified as '*', cdb will automatically select an\n",
        "unused IP address in the given subnetwork for you.  If you specify\n",
        "the complete address, cdb will verify that this address is unique.\n",
        "cdb is configured to require an address starting: @cdb_ip_nibbles\n";

  $" = $tmp;
}

#
# FUNCTION: help_ethernet
#    DESCR: Print out some information about the Ethernet address field
#

sub help_ethernet {
  print "The Ethernet address field contains the 48-bit Ethernet address\n",
        "for the host in colon-separated format.  cdb will automatically\n",
        "strip leading zeroes and convert uppercase hexadecimal characters\n",
        "to their lowercase equivalents, as well as verify that the address\n",
        "is unique within the database.  If this host's primary netgroup is\n",
        "not one which is meant for installation via JumpStart, you may opt\n",
        "to leave the ethernet field blank.\n";
}

#
# FUNCTION: help_mxhost
#    DESCR: Print out some information about the mxhost field
#

sub help_mxhost {
  print "The mxhost is the host who exchanges email for this host.\n",
        "The name should consist of letters, digits, and underscores and\n",
        "must not begin with a digit.  cdb will automatically remove\n",
        "whitespace and convert uppercase characters to lowercase ones.\n",
        "The name should not be longer than $MAXHOSTNAMELEN characters.\n";
}

#
# FUNCTION: help_status
#    DESCR: Print out info about the status field.
#

sub help_status {
  print "The status is the current machine status of this host.\n",
        "For example, some machines appear in the database but \n",
        "are not active for some reason (posterity, saving the name\n",
        "for future use, machine is being repaired, or is a home\n",
        "machine not usually connected to the network).  Current\n",
        "status flags are: ";

  for ($[ .. $#cdb_status_strings) {
    print "$cdb_status_strings[$_]", " ";
  }

  print "\n";
}


#
# FUNCTION: ynquery
#    DESCR: Prompt the user for yes or no and return appropriate value.
#

sub ynquery {
  my($prompt) = @_;
  my($answer);

  printflush('STDOUT', $prompt);
  chop($answer = <STDIN>);
  return ($answer eq '') || ($answer eq 'Y') || ($answer eq 'y');
}

#
# FUNCTION: modify_record
#    DESCR: Interactively modify a record
#

sub modify_record {
  my($key, $mkstate) = @_;
  my(@fields) = sort keys(%g_cdb_fields);
  my($record) = $cdb_by_hostname->{$key};
  my($mod, $value);
  my($modified) = 0;

  for(;;) {
    print "\nModifying record for host \"$key\":\n\n";

    foreach $i (0 .. $#fields) {
      printf(" [%d] %10s = %s\n", $i, $fields[$i], $record->{$fields[$i]});
    }

    for(;;) {
      printflush('STDOUT', "\nEnter the field number to modify or 'q' to quit ",
                 "[0-", $#fields, "q]: ");
      chop($mod = <STDIN>);
      last if(($mod eq 'q') ||
              (($mod =~ /^[0-9]+$/) && ($mod >= 0) && ($mod <= $#fields)));
    }

    last if($mod eq 'q');

    printflush('STDOUT', "Enter the new value for $fields[$mod]: ");
    chop($value = <STDIN>);

    if(defined($g_cdb_canons{$fields[$mod]})) {
      $value = &{ $g_cdb_canons{$fields[$mod]} }($value);
    }

    if(defined($g_cdb_verifications{$fields[$mod]})) {
      next unless(&{ $g_cdb_verifications{$fields[$mod]} }($key, $value));
    }

    # Make the actual modification to the database hash

    $record->{$fields[$mod]} = $value;
    $modified = 1;

    # Touch each map in the make state file which depends on this field

    foreach $map (@{ $g_cdb_map_dependencies{$fields[$mod]} }) {
      touch_make_state($mkstate, $map);
    }
  }

  $modified = ynquery("Save modifications (y/n)[y]? ") if($modified);
  return $modified;
}

#
# FUNCTION: cdb_print
#    DESCR: Print out a list of the specified fields for all host records
#

sub cdb_print {
  my(@args) = @_;
  my(@fields) = keys(%g_cdb_fields);
  my(@hosts);

  my($maxlen) = 0;
  my($line);

  # If no fieldnames are specified, list out the fields

  if(@args == 0) {
    foreach $i (0 .. $#fields) {
      $maxlen = length($fields[$i]) if(length($fields[$i]) > $maxlen);
    }
    warn "Usage: cdb print [fieldname ...]\n\n  Valid database fields:\n";
    foreach $i (0 .. $#fields) {
      printf("  %${maxlen}s ~ %s\n", $fields[$i], $g_cdb_fields{$fields[$i]});
    }
    return 2;
  }

  # Make sure all the fieldnames are valid

  foreach $i (0 .. $#args) {
    die "$PNAME: Unknown field \"$args[$i]\"\n",
      "Usage: cdb print [fieldname ...]\n"
        if(!defined($g_cdb_fields{$args[$i]}));
  }

  # Build up a string containing the fields for each record and print it

  @hosts = keys(%$cdb_by_hostname);

  foreach $host (@hosts) {
    $line = '';

    foreach $i (0 .. $#args) {
      $line .= $cdb_by_hostname->{$host}{$args[$i]};
      $line .= "$DEF_DELIM" if($i < $#args);
    }

    print $line . "\n";
  }

  return 0;
}

#
# FUNCTION: cdb_query
#    DESCR: Print out specified fields for records matching query pattern
#

sub cdb_query {
  my(@args) = @_;
  my(@fields) = keys(%g_cdb_fields);

  my(@hosts);
  my($idx, $line);

  my(@matches) = ();
  my(@matchfields) = ();
  my(@matchexps) = ();
  my(@printfields) = ();

  # If no arguments are specified, print a usage message

  if(@args == 0) {
    command_help("query");
    return 2;
  }

  # Build lists of fields to match and print

  foreach $arg (@args) {
    if(($idx = index($arg, '=')) > 0) {
      push(@matchfields, substr($arg, 0, $idx));
      push(@matchexps, substr($arg, ++$idx));
    } else {
      push(@printfields, $arg);
    }
  }

  # Verify list of fields to print

  push(@printfields, 'hostname') if(scalar(@printfields) == 0);

  foreach $field (@printfields) {
    die "$PNAME: Unknown field \"$field\"\n"
      if(!defined($g_cdb_fields{$field}));
  }

  @hosts = keys(%$cdb_by_hostname);

  # Remove all hosts from list which do not match criteria

host_loop:
  foreach $host (@hosts) {
    foreach $i (0 .. $#matchfields) {
      next host_loop
        if($cdb_by_hostname->{$host}{$matchfields[$i]} !~ /$matchexps[$i]/);
    }

    push(@matches, $host);
  }

  # Build up a string containing fields for each remaining record and print it

  foreach $host (@matches) {
    $line = '';

    foreach $i (0 .. $#printfields) {
      $line .= $cdb_by_hostname->{$host}{$printfields[$i]};
      $line .= "$DEF_DELIM" if($i < $#printfields);
    }

    print $line . "\n";
  }

  return 0;
}

#
# FUNCTION: cdb_delete
#    DESCR: Delete the specified records from the database.
#

sub cdb_delete {
  my(@args) = @_;
  my($mkstate);

  if(@args == 0) {
    warn "Usage: cdb delete [hostname ...]\n";
    return 2;
  }

  foreach $host (@args) {
    if(defined($cdb_by_hostname->{$host})) {
      delete $cdb_by_hostname->{$host};
      $g_modified = 1;
    } else {
      warn "$PNAME: No record exists for host \"$host\"\n";
    }
  }

  if($g_modified) {
    printflush('STDOUT', "Writing database file ... ") if($opt_v);
    write_db($cdb_by_hostname);
    printflush('STDOUT', "done\n") if($opt_v);

    $mkstate = load_make_state($PATH_MKFILE);
    foreach $map (keys(%g_cdb_maps)) { touch_make_state($mkstate, $map); }
    write_make_state($mkstate, $PATH_MKFILE);
  }

  return 0;
}

# 
# FUNCTION: build_hosts
#    DESCR: Generate the /var/yp/src/hosts NIS src map
#

sub build_hosts {
  my($file, $include) = @_;
  my(@hosts) = keys(%$cdb_by_hostname);
  my(@inctext, $primgrp, $aliases, $tabs, $hostref);

  @g_sort_order = ( 'ip_addr' ); 
  @hosts = sort sort_hostnames @hosts;

  $PATH_TMPFILE = $file . '.tmp';

  open(HOSTS, ">$PATH_TMPFILE") ||
    die "$PNAME: ERROR: Failed to open $PATH_TMPFILE: $!\n";

  print HOSTS "#\n#  FILE: $file\n",
    "# DESCR: NIS hosts map generated by $PNAME version $PVERS\n",
    "#  DATE: ", get_date(), "\n#\n";

  if(-s ("$include")) {
    open(INCLUDE, "<$include") ||
      die "$PNAME: ERROR: Failed to open include $include: $!\n";

    @inctext = <INCLUDE>;
    print HOSTS @inctext;
    close(INCLUDE);
  }

  foreach $host (@hosts) {
    $hostref = $cdb_by_hostname->{$host};
    $prim_grp = $hostref->{'prim_grp'};

    next unless($cdb_primary_groups{$prim_grp} & $NG_HOSTS);

    ($aliases = $hostref->{'aliases'}) =~ s/,/ /g;
    print HOSTS $hostref->{'ip_addr'}, "\t",
      $hostref->{'hostname'}, " ${aliases}", "\n";
  }

  print HOSTS "# EOF\n";
  close(HOSTS);

  die "$PNAME: ERROR: Failed to rename $file: $!\n"
    if(!rename("$PATH_TMPFILE", "$file"));
}

#
# FUNCTION: build_tftpboot
#    DESCR: Rebuild the tftp network boot directory
#

sub build_tftpboot {
  foreach $host (sort(keys(%$cdb_by_hostname))) {

    my $primgrp = $cdb_by_hostname->{$host}{'prim_grp'};
    next unless($cdb_primary_groups{$primgrp} & $NG_TFTP);

    my @ipaddr = split(/\./, $cdb_by_hostname->{$host}{'ip_addr'});

    my $ostype = $cdb_by_hostname->{$host}{'os_type'};

    my $arch = $cdb_by_hostname->{$host}{'hw_arch'};

    # Do not generate tftpboot information if your os_type does not define
    # all required fields.  Can be used for placeholders.

    my $tftpboot_path = $cdb_os_types->{$ostype}{'tftpboot_path'};
    if(!defined($tftpboot_path)) {
      next;
    }

    my $bootimage = $cdb_by_hostname->{$host}{'pxelink'} || $cdb_os_types->{$ostype}{'images'}{$arch};
    if(!defined($bootimage)) {
      next;
    }

    my $hex_ip = sprintf("$tftpboot_path/%0.2X%0.2X%0.2X%0.2X",
      $ipaddr[0], $ipaddr[1], $ipaddr[2], $ipaddr[3]);

    if(!$opt_X) {
      unlink("$tftpboot_path/$hex_ip");
      symlink("$bootimage", "$tftpboot_path/$hex_ip") ||
        warn "$PNAME: ERROR: Failed to create link $hex_ip: $!\n";
    } else {
      print "DEBUG: $host $hex_ip\n";
    }
  }
}

#
# FUNCTION: build_bootparams
#    DESCR: Build a new /var/yp/src/bootparams NIS src map.
#

sub build_bootparams {
  my($file, $include) = @_;
  my($ostype, $subnet, $arch, $primgrp);
  my($boot_server, $netboot_path, $boot_path, $js_server, $js_path);
  my(@inctext);

  $PATH_TMPFILE = $file . '.tmp';

  open(BOOTP, ">$PATH_TMPFILE") ||
    die "$PNAME: ERROR: Failed to open $PATH_TMPFILE: $!\n";

  print BOOTP "#\n#  FILE: $file\n",
    "# DESCR: NIS bootparams map generated by $PNAME version $PVERS\n",
    "#  DATE: ", get_date(), "\n#\n\n";

  if(-s ("$include")) {
    open(INCLUDE, "<$include") ||
      die "$PNAME: ERROR: Failed to open include $include: $!\n";

    @inctext = <INCLUDE>;
    print BOOTP @inctext;
    close(INCLUDE);
  }

  foreach $host (sort(keys(%$cdb_by_hostname))) {
    $primgrp = $cdb_by_hostname->{$host}{'prim_grp'};
    next unless($cdb_primary_groups{$primgrp} & $NG_BOOTP);

    $subnet = (split(/\./, $cdb_by_hostname->{$host}{'ip_addr'}))[2];
    $ostype = $cdb_by_hostname->{$host}{'os_type'};
    $arch = $cdb_by_hostname->{$host}{'hw_arch'};

    if(!defined($cdb_os_types->{$ostype})) {
      warn "$PNAME: WARNING: No OS type specifier for $host, $ostype\n";
      next;
    }

    # Do not generate bootparams information if your os_type does not define
    # all required JumpStart fields.  Can be used for placeholders.

    if(!defined($cdb_os_types->{$ostype}{'netboot_path'}) ||
       !defined($cdb_os_types->{$ostype}{'install_path'}) ||
       !defined($cdb_os_types->{$ostype}{'jumpstart_path'}) ||
       !defined($cdb_os_types->{$ostype}{'cache_path'})) {
      next;
    }

    $netboot_path = $cdb_os_types->{$ostype}{'netboot_path'};

    ($boot_server, $boot_path) =
      split(/:/, $cdb_os_types->{$ostype}{'install_path'});

    ($js_server, $js_path) =
      split(/:/, $cdb_os_types->{$ostype}{'jumpstart_path'});

    print BOOTP $host,
      ' root=', $boot_server, $subnet, ':', $boot_path, '/', $netboot_path,
      ' install=', $boot_server, $subnet, ':', $boot_path,
      ' boottype=', $CDB_BOOT_TYPE,
      ' install_config=', $js_server, ':', $js_path,
      ' sysid_config=', $js_server, ':', $js_path, "\n\n";
  }

  print BOOTP "# EOF\n";
  close(BOOTP);

  die "$PNAME: ERROR: Failed to rename $file: $!\n"
    if(!rename("$PATH_TMPFILE", "$file"));
}

#
# FUNCTION: build_hosts_equiv
#    DESCR: Generate a new /etc/hosts.equiv file from the database
#       and copy it to the update trees
#

sub build_hosts_equiv {
  my($file, $include) = @_;
  my(@inctext, $jspath, $primgrp, $fqdn_file);

  $PATH_TMPFILE = $file . '.tmp';

  open(EQUIV, ">$PATH_TMPFILE") ||
    die "$PNAME: ERROR: Failed to open $PATH_TMPFILE: $!\n";

  push(@g_tmpfiles, $fqdn_file);

  if(-s ("$include")) {
    open(INCLUDE, "<$include") ||
      die "$PNAME: ERROR: Failed to open include $include: $!\n";

    @inctext = <INCLUDE>;
    print EQUIV @inctext;
    close(INCLUDE);
  }

  foreach $host (sort(keys(%$cdb_by_hostname))) {
    $primgrp = $cdb_by_hostname->{$host}{'prim_grp'};
    
    if($cdb_primary_groups{$primgrp} & $NG_EQUIV) {
      print EQUIV "${host}\n";
      print EQUIV "${host}";
			if ($cdb_by_hostname->{$host}{'prim_grp'} eq "ilab") {
				print EQUIV ".ilab";
			}
			print EQUIV ".${CDB_DNS_DOMAIN}\n";
    }
  }

  close(EQUIV);

  die "$PNAME: ERROR: Failed to rename $file: $!\n"
    if(!rename("$PATH_TMPFILE", "$file"));

  if(!$opt_X) {
    chmod($CDB_DBF_PERMS, $fqdn_file);
    chmod($CDB_DBF_PERMS, $file);

    foreach $ostype (keys(%$cdb_os_types)) {
      next unless(defined($cdb_os_types->{$ostype}{'jumpstart_path'}));
      $jspath = '/' . $cdb_os_types->{$ostype}{'jumpstart_path'} .
        '/data/files/add/all' . $file;
      $jspath =~ s/:\/vol//;
      #print "cp -p $file $jspath\n";
      system("cp -p $file $jspath");
      warn "$PNAME: ERROR: Failed to propagate $file to $jspath\n"
        if($? != 0);
    }
  }
}

sub add_to_group {
  my ($netgroups, $grp, $host) = @_;

  if(defined($netgroups->{$grp})) {
    $netgroups->{$grp} .= " (${host},,)";
  } else {
    $netgroups->{$grp} = "(${host},,)";
  }

}

#
# FUNCTION: build_netgroup
#    DESCR: Generate a new /var/yp/src/netgroup file from the database
#

sub build_netgroup {
  my($file, $include) = @_;
  my(%netgroups) = ();
  my($primgrp, $line, $length, $gridx, $grsubname, $grsubidx);
  my(@grmem, @grsub, @inctext);

  $PATH_TMPFILE = $file . '.tmp';

  open(NETGROUP, ">$PATH_TMPFILE") ||
    die "$PNAME: ERROR: Failed to open $PATH_TMPFILE: $!\n";

  print NETGROUP "#\n#  FILE: $file\n",
    "# DESCR: NIS netgroup map generated by $PNAME version $PVERS\n",
    "#  DATE: ", get_date(), "\n#\n\n";

  if(-s ("$include")) {
    open(INCLUDE, "<$include") ||
      die "$PNAME: ERROR: Failed to open include $include: $!\n";

    @inctext = <INCLUDE>;
    print NETGROUP @inctext;
    close(INCLUDE);
  }

  foreach $host (keys(%$cdb_by_hostname)) {
    $primgrp = $cdb_by_hostname->{$host}{'prim_grp'};
    next unless($cdb_primary_groups{$primgrp} & $NG_NETGR);

    add_to_group(\%netgroups, $primgrp, $host);

    foreach $class (split(/,/, $cdb_by_hostname->{$host}{'classes'})) {
      if ($class =~ /^camera$/) {
        add_to_group(\%netgroups, "camera", $host);
      } elsif ($class =~ /^cgc$/) {
        add_to_group(\%netgroups, "cgc", $host);
      } elsif ($class =~ /^graphics$/) {
        add_to_group(\%netgroups, "graphics", $host);
      } elsif ($class =~ /^fun$/) {
        add_to_group(\%netgroups, "ugrad", $host);
      } elsif ($class =~ /^ssh\.forward$/) {
        add_to_group(\%netgroups, "sunlab", $host);
      } elsif ($class =~ /^tstaff-netgroup$/) {
        add_to_group(\%netgroups, "tstaff", $host);
      } elsif ($class =~ /^thermo$/) {
        add_to_group(\%netgroups, "thermo", $host);
      } elsif ($class =~ /^liebert$/) {
        add_to_group(\%netgroups, "liebert", $host);
      } elsif ($class =~ /^server$/) {
        add_to_group(\%netgroups, "server", $host);
      }
    }
  }

  # Annoying hack: ndbm limits us to 1024-byte datum.  Decompose groups
  # of greater than 32 elements into subgroups as a workaround.
  
  $gridx = 0;

  foreach $grp (keys(%netgroups)) {
    @grmem = split(/ /, $netgroups{$grp});

    if(scalar(@grmem) > 32) {
      delete $netgroups{$grp};
      $netgroups{$grp} = '';
      $grsubidx = 0;

      while(scalar(@grmem) > 0) {
        @grsub = splice(@grmem, 0, (scalar(@grmem)>32) ? 32 : scalar(@grmem));
        $grsubname = "0-" . $gridx . "-" . $grsubidx++;
        $netgroups{$grsubname} = join(' ', @grsub);

        if($netgroups{$grp} ne '') {
          $netgroups{$grp} .= " $grsubname";
        } else {
          $netgroups{$grp} = $grsubname;
        }
      }

      $gridx++;
    }
  }

  # End of ndbm hack

  foreach $grp (sort(keys(%netgroups))) {
    print NETGROUP "# Netgroup $grp\n\n";
    $line = "$grp\t";

    @grmem = split(/ /, $netgroups{$grp});
    foreach $i (0 .. $#grmem) {
      if((length($line) + length($grmem[$i]) + 11) < 80) {
        $line .= $grmem[$i] . ' ';
      } else {
        print NETGROUP $line, ($i < $#grmem) ? "\\\n" : '';
        $line = $grmem[$i] . ' ';
      }
    }

    print NETGROUP $line, "\n\n";
  }

  print NETGROUP "\n# EOF\n";
  close(NETGROUP);

  die "$PNAME: ERROR: Failed to rename $file: $!\n" if(!rename("$PATH_TMPFILE", "$file"));
  foreach $dir (@CDB_NETGROUP_DIRS) {
    system("cp -p $file $dir/netgroup");
    if ( $? != 0 ) {
      warn "$PNAME: ERROR: Failed to copy netgroup file to $dir\n";
    }
  }

}

#
# FUNCTION: build_ethers
#    DESCR: Generate a new /var/yp/src/ethers file from the database
#

sub build_ethers {
  my($file, $include) = @_;
  my(@hosts) = keys(%$cdb_by_hostname);
  my(@inctext, $primgrp, $ethernet);

  @g_sort_order = ( 'ethernet' ); 
  @hosts = sort sort_hostnames @hosts;

  $PATH_TMPFILE = $file . '.tmp';

  open(ETHERS, ">$PATH_TMPFILE") ||
    die "$PNAME: ERROR: Failed to open $PATH_TMPFILE: $!\n";

  print ETHERS "#\n#  FILE: $file\n",
    "# DESCR: NIS ethers map generated by $PNAME version $PVERS\n",
    "#  DATE: ", get_date(), "\n#\n\n";

  if(-s ("$include")) {
    open(INCLUDE, "<$include") ||
      die "$PNAME: ERROR: Failed to open include $include: $!\n";

    @inctext = <INCLUDE>;
    print ETHERS @inctext;
    close(INCLUDE);
  }

  foreach $host (@hosts) {
    $primgrp = $cdb_by_hostname->{$host}{'prim_grp'};
    $ethernet = $cdb_by_hostname->{$host}{'ethernet'};
    next unless $ethernet;
    $tabs = (length($ethernet) > 15) ? "\t" : "\t\t";
    print ETHERS "${ethernet}${tabs}${host}\n"
      if($cdb_primary_groups{$primgrp} & $NG_ETHERS);
  }

  print ETHERS "\n# EOF\n";
  close(ETHERS);

  die "$PNAME: ERROR: Failed to rename $file: $!\n"
    if(!rename("$PATH_TMPFILE", "$file"));
}

#
# FUNCTION: build_dhcp
#    DESCR: Generate a new dhcpd file from the database
#

sub build_dhcp {
    my($file, $include) = @_;
    my(@all_hosts) = keys(%$cdb_by_hostname);
    my(@inctext, @pxe_hosts, @ppc_pxe_hosts, @dynamic_hosts, @other_hosts);
    my($primgrp, $ethernet, $status);

    @g_sort_order = ( 'ethernet' ); 
    @all_hosts = sort sort_hostnames @all_hosts;

    foreach $host (@all_hosts) {
      # make sure only hosts with ethernet address are entered into the
      # DHCP tables
      next unless ($cdb_by_hostname->{$host}{'ethernet'});

      $prim_grp = $cdb_by_hostname->{$host}{'prim_grp'};
      $arch = $cdb_by_hostname->{$host}{'hw_arch'};
      if($prim_grp eq "linux" || $prim_grp eq "ilab" || \
         $prim_grp eq "private" || $prim_grp eq "standalone" ) {
        if ($arch eq "ppc") {
          push @ppc_pxe_hosts, $host;
        } else {
          push @pxe_hosts, $host;
        }
      } elsif($prim_grp eq "dynamic") {
        push @dynamic_hosts, $host;
      } else {
        push @other_hosts, $host;
      }
    }
    
    $PATH_TMPFILE = $file . '.tmp';

    open(DHCP, ">$PATH_TMPFILE") ||
      die "$PNAME: ERROR: Failed to open $PATH_TMPFILE: $!\n";

    print DHCP "#\n#  FILE: $file\n",
    "# DESCR: DHCP config generated by $PNAME version $PVERS\n",
    "#  DATE: ", get_date(), "\n#\n\n";

    if(-s ("$include")) {
        open(INCLUDE, "<$include") ||
          die "$PNAME: ERROR: Failed to open include $include: $!\n";

        @inctext = <INCLUDE>;
        print DHCP @inctext;
        close(INCLUDE);
    }

    print DHCP "#\n";
    print DHCP "# PXElinux Clients\n";
    print DHCP "#\n";

    print DHCP "group {\n";
    print DHCP "    use-host-decl-names on;\n";
    print DHCP "    next-server pxe.cs.brown.edu;\n";
    print DHCP "    filename \"pxelinux.0\"\;\n\n";
    foreach $host (@pxe_hosts) {
        $ethernet = $cdb_by_hostname->{$host}{'ethernet'};
        next unless ( $ethernet );

        # only include hosts that are listed as active or monitored
        $status = $cdb_by_hostname->{$host}{'status'};
        next unless ( $status eq "active" || $status eq "monitored" || $status eq "ugrad-monitored" );

        print DHCP "    host $host {\n";
        print DHCP "        hardware ethernet $ethernet;\n";
        print DHCP "        fixed-address $host;\n";
        print DHCP "    }\n";
    }
    print DHCP "}\n\n";

    print DHCP "#\n";
    print DHCP "# PPC yaboot Clients\n";
    print DHCP "#\n";

    print DHCP "group {\n";
    print DHCP "    use-host-decl-names on;\n";
    print DHCP "    next-server pxe.cs.brown.edu;\n";
    print DHCP "    filename \"yaboot\"\;\n\n";
    foreach $host (@ppc_pxe_hosts) {
        $ethernet = $cdb_by_hostname->{$host}{'ethernet'};
        next unless ( $ethernet );

        # only include hosts that are listed as active or monitored
        $status = $cdb_by_hostname->{$host}{'status'};
        next unless ( $status eq "active" || $status eq "monitored" || $status eq "ugrad-monitored" );

        print DHCP "    host $host {\n";
        print DHCP "        hardware ethernet $ethernet;\n";
        print DHCP "        fixed-address $host;\n";
        print DHCP "    }\n";
    }
    print DHCP "}\n\n";

    print DHCP "#\n";
    print DHCP "# Other Static DHCP Clients\n";
    print DHCP "#\n";

    print DHCP "group {\n";
    print DHCP "    use-host-decl-names on;\n";
    foreach $host (@other_hosts) {
        $ethernet = $cdb_by_hostname->{$host}{'ethernet'};
        next unless ( $ethernet );

        # only include hosts that are listed as active or monitored
        $status = $cdb_by_hostname->{$host}{'status'};
        next unless ( $status eq "active" || $status eq "monitored" || $status eq "ugrad-monitored" );

        print DHCP "    host $host {\n";
        print DHCP "        hardware ethernet $ethernet;\n";
        print DHCP "        fixed-address $host;\n";
        print DHCP "    }\n";
    }
    print DHCP "}\n\n";

    print DHCP "#\n";
    print DHCP "# DHCP Clients\n";
    print DHCP "#\n";

    print DHCP "group {\n";
    print DHCP "    use-host-decl-names on;\n";
    foreach $host (@dynamic_hosts) {
        $ethernet = $cdb_by_hostname->{$host}{'ethernet'};
        next unless ( $ethernet );

        # only include hosts that are listed as active
        $status = $cdb_by_hostname->{$host}{'status'};
        next unless ( $status eq "active" );

        print DHCP "    # $cdb_by_hostname->{$host}{'comment'}\n";
        print DHCP "    host $host {\n";
        print DHCP "        hardware ethernet $ethernet;\n";
        print DHCP "    }\n";
    }
    print DHCP "}\n";

    print DHCP "\n# EOF\n";
    close(DHCP);
    
    die "$PNAME: ERROR: Failed to rename $file: $!\n"
      if(!rename("$PATH_TMPFILE", "$file"));

    # send new config file to each server
    foreach $host (@CDB_DHCP_SERVERS) {
      system($SCP, '-pq', $file, "$host:/etc");
      if ( $? != 0 ) {
        warn "$PNAME: ERROR: Failed to copy DNS files to $host\n";
      }
    }

    system($SSH, '-x', 'dhcp', '/etc/init.d/dhcp restart');
}

# 
# FUNCTION: build_nagios_hosts
#    DESCR: Generate the nagios hosts.cfg file
#

sub build_nagios_hosts {
  my($file, $include) = @_;
  my(@hosts) = keys(%$cdb_by_hostname);
  my(@inctext, $primgrp, $aliases, $tabs, $hostref);

  @g_sort_order = ( 'ip_addr' ); 
  @hosts = sort sort_hostnames @hosts;

  $PATH_TMPFILE = $file . '.tmp';

  open(OUT, ">$PATH_TMPFILE") ||
    die "$PNAME: ERROR: Failed to open $PATH_TMPFILE: $!\n";

  print OUT "#\n#  FILE: $file\n",
    "# DESCR: nagios hosts.cfg generated by $PNAME version $PVERS\n",
    "#  DATE: ", get_date(), "\n#\n";

  if(-s ("$include")) {
    open(INCLUDE, "<$include") ||
      die "$PNAME: ERROR: Failed to open include $include: $!\n";

    @inctext = <INCLUDE>;
    print OUT @inctext;
    close(INCLUDE);
  }

  foreach $host (@hosts) {
    $hostref = $cdb_by_hostname->{$host};
    $prim_grp = $hostref->{'prim_grp'};
    $ip_addr = $hostref->{'ip_addr'};

    next unless($cdb_primary_groups{$prim_grp} & $NG_NAGIOS);

    if ( $hostref->{'status'} eq "monitored" ) {
      print OUT "define host{\n";
      print OUT "\tuse\t\t\thost_template\n";
      print OUT "\thost_name\t\t$host\n";
      print OUT "\taddress\t\t\t$ip_addr\n";
      print OUT "}\n\n";
    } elsif ( $hostref->{'status'} eq "ugrad-monitored" ) {
      print OUT "define host{\n";
      print OUT "\tuse\t\t\tugrad_template\n";
      print OUT "\thost_name\t\t$host\n";
      print OUT "\taddress\t\t\t$ip_addr\n";
      print OUT "}\n\n";    
    }

  }

  print OUT "# EOF\n";
  close(OUT);

  die "$PNAME: ERROR: Failed to rename $file: $!\n"
    if(!rename("$PATH_TMPFILE", "$file"));

  # send new config file to each server
  system($SCP, '-pq', $file, "storm:/etc/nagios3/conf.d/");
  if ( $? != 0 ) {
    warn "$PNAME: ERROR: Failed to copy nagios files to $host\n";
  }

  system($SSH, '-x', 'storm', '/etc/init.d/nagios3 restart');

}

# 
# FUNCTION: build_nagios_services
#    DESCR: Generate the nagios services.cfg file
#

sub build_nagios_services {
  my($file, $include) = @_;
  my(@hosts) = keys(%$cdb_by_hostname);
  my(@inctext, $primgrp, $aliases, $tabs, $hostref);

  @g_sort_order = ( 'ip_addr' ); 
  @hosts = sort sort_hostnames @hosts;

  $PATH_TMPFILE = $file . '.tmp';

  open(OUT, ">$PATH_TMPFILE") ||
    die "$PNAME: ERROR: Failed to open $PATH_TMPFILE: $!\n";

  print OUT "#\n#  FILE: $file\n",
    "# DESCR: nagios services.cfg generated by $PNAME version $PVERS\n",
    "#  DATE: ", get_date(), "\n#\n";

  if(-s ("$include")) {
    open(INCLUDE, "<$include") ||
      die "$PNAME: ERROR: Failed to open include $include: $!\n";

    @inctext = <INCLUDE>;
    print OUT @inctext;
    close(INCLUDE);
  }

  foreach $host (@hosts) {
    $hostref = $cdb_by_hostname->{$host};
    $prim_grp = $hostref->{'prim_grp'};
    $ip_addr = $hostref->{'ip_addr'};

    next unless($cdb_primary_groups{$prim_grp} & $NG_NAGIOS);

    next unless ( $hostref->{'status'} eq "monitored" );

    print OUT "define service{\n";
    print OUT "\tuse\t\t\tping_template\n";
    print OUT "\thost_name\t\t$host\n";
    print OUT "}\n\n";    

    my @classes = split(/,/, $hostref->{'classes'});

    for (@classes) {

      if (/printer/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tprinter_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";    

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tqueuing_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "\tcheck_command\t\tcheck-queuing!$host\n";
        print OUT "}\n\n";

      } elsif (/smtp/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tsmtp_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";    

      } elsif (/ftp/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tftp_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";    

      } elsif (/http/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\thttp_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";    

      } elsif (/imap/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\timap_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";    

      } elsif (/pop/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tpop_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";    

      } elsif (/dns/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tdns_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tdns_internal_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";    

      } elsif (/dhcp/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tdhcp_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/telnet/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\ttelnet_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/liebert/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tliebert_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "\tcontact_groups\t\tspoc_group,tstaff_group\n";
        print OUT "}\n\n";

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tliebert_alarms_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "\tcontact_groups\t\tspoc_group,tstaff_group\n";
        print OUT "}\n\n";

      } elsif (/thermo/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tthermo_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "\tcontact_groups\t\temergency_group,spoc_group,tstaff_group\n";
        print OUT "}\n\n";

      } elsif (/pgsql/|/postgresql\.db/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tpgsql_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/netapp/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tnetapp_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/ntp/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tntp_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/ssh/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tssh_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/mailman/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tmailman_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/spamassassin/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tspamd_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

        print OUT "define service{\n";
        print OUT "\tuse\t\t\typbind_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";   

      } elsif (/sge/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tsge_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/flexlm/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tflexlm_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/tierfs/) {

        @disks = split(/:/, $hostref->{'classes'});
        foreach $disk (@disks) {
          if($disk =~ /.*disk.*/) {
            @fields = split(/ /, $disk);
            $fields[0] =~ s/disk\=//;
            print OUT "define service{\n";
            print OUT "\tuse\t\t\tdiskusage_template\n";
            print OUT "\thost_name\t\t$host\n";
            print OUT "\tcheck_command\t\tssh-check-disk!$fields[0]!$fields[1]!$fields[2]\n";
            print OUT "\tservice_description\t$fields[0] usage\n";
            print OUT "}\n\n";
          }
        }

      } elsif (/ldap\.server\.db/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tldap_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/drbd/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tdrbd_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      } elsif (/krb/) {

        print OUT "define service{\n";
        print OUT "\tuse\t\t\tkrb_template\n";
        print OUT "\thost_name\t\t$host\n";
        print OUT "}\n\n";

      }

    }

  }

  print OUT "# EOF\n";
  close(OUT);

  die "$PNAME: ERROR: Failed to rename $file: $!\n"
    if(!rename("$PATH_TMPFILE", "$file"));

  # send new config file to each server
  system($SCP, '-pq', $file, "storm:/etc/nagios3/conf.d/");
  if ( $? != 0 ) {
    warn "$PNAME: ERROR: Failed to copy nagios files to $host\n";
  }

  system($SSH, '-x', 'storm', '/etc/init.d/nagios3 restart');

}

# 
# FUNCTION: build_wpkg_hosts
#    DESCR: Generate the wpkg hosts.xml file
#

sub build_wpkg_hosts {
  my($file, $include) = @_;
  my(@hosts) = keys(%$cdb_by_hostname);
  my(@inctext, $primgrp, $aliases, $tabs, $hostref);

  @g_sort_order = ( 'ip_addr' ); 
  @hosts = sort sort_hostnames @hosts;

  $PATH_TMPFILE = $file . '.tmp';

  open(OUT, ">$PATH_TMPFILE") ||
    die "$PNAME: ERROR: Failed to open $PATH_TMPFILE: $!\n";

  print OUT '<?xml version="1.0" encoding="UTF-8"?>', "\n";

  print OUT "<!--\n",
    "FILE: $file\n",
    "DESCR: wpkg hosts.xml generated by $PNAME version $PVERS\n",
    "DATE: ", get_date(), "\n",
    "-->\n\n";

  print OUT '<wpkg>', "\n";

  if(-s ("$include")) {
    open(INCLUDE, "<$include") ||
      die "$PNAME: ERROR: Failed to open include $include: $!\n";

    @inctext = <INCLUDE>;
    print OUT @inctext;
    close(INCLUDE);
  }

  foreach $host (@hosts) {

    $hostref = $cdb_by_hostname->{$host};
    $prim_grp = $hostref->{'prim_grp'};
    $os = $hostref->{'os_type'};

    next unless($cdb_primary_groups{$prim_grp} & $NG_WPKG);
    next unless(($os eq 'winxp') or ($os eq 'vista'));

    # generate profile list

    @wpkg_profiles = ();

    my @classes = split(/,/, $hostref->{'classes'});

    if ($os eq 'winxp') {
      push @wpkg_profiles, "winxp";
    } elsif ($os eq 'vista') {
      push @wpkg_profiles, "vista";
    }

    for (@classes) {

      if (/^desktop$/) {
        push @wpkg_profiles, "desktop";
        push @wpkg_profiles, "$os-dept";
      }

      if (/^classroom$/) {
        push @wpkg_profiles, "classroom";
      }

      if (/^maya$/) {
        push @wpkg_profiles, "maya";
      }

      if (/^tstaff$/) {
        push @wpkg_profiles, "tstaff";
      }

      if (/^afs$/) {
        push @wpkg_profiles, "afs";
      }

      if (/^fun$/) {
        push @wpkg_profiles, "fun";
      }

      if (/^research$/) {
        push @wpkg_profiles, "research";
        push @wpkg_profiles, "$os-research";
      }

      if (/^server$/) {
        push @wpkg_profiles, "server";
      }

      if (/^remote$/) {
        push @wpkg_profiles, "desktop";
        push @wpkg_profiles, "remote";
        push @wpkg_profiles, "$os-remote";
      }

      if (/^laptop$/) {
        push @wpkg_profiles, "$os-laptop";
      }

      if (/^laptop.loaner$/) {
        push @wpkg_profiles, "$os-laptop";
        push @wpkg_profiles, "loaner-laptop";
      }

      if (/^laptop.x61$/) {
        push @wpkg_profiles, "$os-laptop";
        push @wpkg_profiles, "x61";
      }

      # licensed software

      if (/^adobe-ae-pp$/) {
        push @wpkg_profiles, "adobe-ae-pp";
      }

      if (/^framemaker$/) {
        push @wpkg_profiles, "framemaker";
      }

      if (/^powerdvd$/) {
        push @wpkg_profiles, "powerdvd";
      }

    }

    next unless @wpkg_profiles;

    $first_profile = shift(@wpkg_profiles);

    print OUT "  <host name=\"$host\" profile-id=\"$first_profile\">\n";
    foreach $profile (@wpkg_profiles) {
      print OUT "    <profile id=\"$profile\" />\n";
    }
    print OUT "  </host>\n";
  }

  print OUT '</wpkg>', "\n";
  close(OUT);

  die "$PNAME: ERROR: Failed to rename $file: $!\n"
    if(!rename("$PATH_TMPFILE", "$file"));

}


#
# FUNCTION: setup_dns_db
#    DESCR: Setup the temporary db file in which all other DNS entries are
#           added.  Write the header information and any include entries.
#
sub setup_dns_db {
  my($file, $include, $fh) = @_;
  # Create temporary file for db - if opt_X, create in current directory

  $db = $CDB_DNS_DIR . '/' . $file unless $opt_X;

  $dbinc = $CDB_INCLUDE_DIR . "/" . $include;

  # Set up headers of the db file

  build_dns_headers($db, $include, $fh) ||
    die "$PNAME: aborting\n";

  # add the include file 

  if(-f("$dbinc")) {
    open(DBINC, "<$dbinc") || die "$PNAME: ERROR: Failed to open $dbinc: $!\n";
    while(<DBINC>) { print $fh $_; }
    close(DBINC);
  }
}

#
# FUNCTION: build_dns_headers
#    DESCR: Creates the specified file, and adds the first specified header 
#           lines from the old file to the new file.
#

sub build_dns_headers {
  my($file, $include, $handle) = @_;
  my($line, $head, $tail, @nums, @inctext);

  print "building headers from: $file, $include\n" if ($opt_v);

  # Open existing database file for reading.  If file doesn't exist, we
  # assume this is an error.

  if (!open(FILE, $file)) {
    warn "$PNAME: ERROR: Failed to open $file: $!\n";
    return 0;
  }

  # Print existing comments and blank lines to new file

  if (eof(FILE)) {
    warn "$PNAME: ERROR: File $file is empty.\n";
    return 0;
  }
 
#  $line = <FILE>; 
#  while ((($line =~ /^\s*$/) || ($line =~ /^;/)) && !eof(FILE)) {
#    print $handle $line;
#    $line = <FILE>;
#  }

  # first line should be ttl line
  $line = <FILE>; 
  if (!($line =~ /ttl/)) {
    warn "$PNAME: ERROR: $file does not being with ttl entry\n";
    return 0;
  }

  print $handle $line;


#  close(FILE);

  # next line should be SOA entry
  $line = <FILE>;
  if (!($line =~ /SOA/)) {
    warn "$PNAME: ERROR: $file does not begin with SOA entry\n";
    return 0;
  }

  # Retrieve serial number from SOA line

  ($head, $tail) = split(/\(/, $line);
  @nums = split(/\s+/, $tail);
  shift(@nums);

  # Recreate line and print it to file  
           
  $line = $head . '( ' . (shift(@nums) + 1);
  while ($_ = shift(@nums)) {
    $line .= " $_";
  }
  print $handle "$line\n";

  # retrieve the remainder of the header information, up to the ; EOH comment
  while(<FILE>) {
    print $handle $_;
    last if /^\; EOH$/;
  }
  
  # print out extra line
  print $handle "\n";

  close(FILE);

  if(-s ("$include")) {
    if (!open(INCLUDE, "<$include")) { 
      warn "$PNAME: ERROR: Failed to open include $include: $!\n";
      return 0;
    }

    @inctext = <INCLUDE>;
    print $handle @inctext;
    close(INCLUDE);
  }
  
  return 1;
}

#
# FUNCTION: build_dns
#    DESCR: Creates the necessary dns-related files and reloads named
#

sub build_dns {
  my($db_header, $i, @dbfiles, $tmpfile, $handle, @handles, %indices, @aliases, 
     $line, $spaces, $host, $cname, @nibbles, $subnet, $dbinc);

  my(%handles, $file, @files);

  # build headers for all the forward lookup maps
  foreach $db (@CDB_DNS_FWD_DBS) {
    # specify the current source files
    if ($opt_X) {
      $db_header = 'db.';
    } else {
      $db_header = $CDB_DNS_DIR . '/db.';
    }
    $srcfile = $db_header . $db;
    $srcinc = $CDB_INCLUDE_DIR . '/cdb_dns_' . $db . '.in';

    # open up a temporary file to house the new db info
    $file = $db_header . $db;

    $handle = $db;
    open($handle, ">$file.tmp") ||
      die "$PNAME: ERROR: Failed to open $file: $!\n";

    push @files, $file;
    $handles{$db} = $handle;

    build_dns_headers($srcfile, $srcinc, $handle);
  }

  # build headers for all the reverse lookup maps
  
  # class C subnets first
  foreach $subnet (@cdb_classC_subnets) {
    # specify the current source files
    if ($opt_X) {
      $db_header = "db.128.148.";
    } else {
      $db_header = $CDB_DNS_DIR . '/db.128.148.';
    }
    $srcfile = $db_header . $subnet;
    $srcinc = $CDB_INCLUDE_DIR . '/cdb_dns_128.148.' . $subnet . '.in';

    # open up a temporary file to house the new db info
    $file = $db_header . $subnet;

    $handle = $subnet;
    open($handle, ">$file.tmp") ||
      die "$PNAME: ERROR: Failed to open $file: $!\n";

    push @files, $file;
    $handles{$subnet} = $handle;

    build_dns_headers($srcfile, $srcinc, $handle);
  }

  # class B subnets next
  foreach $subnet (@cdb_classB_subnets) {
    # specify the current source files
    if ($opt_X) {
      $db_header = "db.10.";
    } else {
      $db_header = $CDB_DNS_DIR . '/db.10.';
    }
    $srcfile = $db_header . $subnet;
    $srcinc = $CDB_INCLUDE_DIR . '/cdb_dns_128.148.' . $subnet . '.in';

    # open up a temporary file to house the new db info
    $file = $db_header . $subnet;

    $handle = $subnet;
    open($handle, ">$file.tmp") ||
      die "$PNAME: ERROR: Failed to open $file: $!\n";

    push @files, $file;
    $handles{$subnet} = $handle;

    build_dns_headers($srcfile, $srcinc, $handle);
  }

  foreach $host (keys(%$cdb_by_hostname)) {
    my($prim_grp) = $cdb_by_hostname->{$host}{'prim_grp'};

    # Don't add DNS entries for dynamic hosts
    next unless ($cdb_primary_groups{$prim_grp} & $NG_DNS);

    # only include hosts that are listed as active or monitored
    $status = $cdb_by_hostname->{$host}{'status'};
    next unless ( $status eq "active" || $status eq "monitored" || $status eq "ugrad-monitored" );

    # first write out to forward tables
    if ("$prim_grp" eq "ilab") {
      $handle = $handles{$prim_grp};
    } else {
      $handle = $handles{'cs'};
    }

    $spaces = ' ' x (21 - length($host));
    $line = $host . $spaces . "IN  A     " .  
      $cdb_by_hostname->{$host}{'ip_addr'};
    print $handle "$line\n";

    if ($cdb_by_hostname->{$host}{'aliases'} ne '') {
      @aliases = split(/,/, $cdb_by_hostname->{$host}{'aliases'});
      while ($cname = pop(@aliases)) {
        $spaces = ' ' x (21 - length($cname));
        if ("$prim_grp" eq "ilab") {
          $line = $cname . $spaces . "IN  CNAME " . "${host}.ilab.${CDB_DNS_DOMAIN}.";
        } else {
          $line = $cname . $spaces . "IN  CNAME " . "${host}.${CDB_DNS_DOMAIN}.";
        }
        print $handle "$line\n";
      }
    }

    if ($cdb_by_hostname->{$host}{'mxhost'} ne '') {
      $spaces = ' ' x (21 - length($host));
      $line = $host . $spaces . "IN  MX    $CDB_DNS_MXPREF " . 
        $cdb_by_hostname->{$host}{'mxhost'} . ".";
      print $handle "$line\n";
    }

    # Then the appropriate subnet database

    @nibbles = split(/\./, $cdb_by_hostname->{$host}{'ip_addr'});
    if (grep /$nibbles[1]/, @cdb_classB_subnets) {
      $subnet = $nibbles[1];
    } elsif (grep /$nibbles[2]/, @cdb_classC_subnets) {
      $subnet = $nibbles[2];
    }

    $line = "";
    foreach (reverse(@nibbles)) {
      $line .= "${_}.";
    }

    $spaces = ' ' x (18 - length($cdb_by_hostname->{$host}{'ip_addr'}));
    if ("$prim_grp" eq "ilab") {
      $line .= "IN-ADDR.ARPA." . $spaces . "IN  PTR   " .
             "${host}.ilab.${CDB_DNS_DOMAIN}.";
    } else {
      $line .= "IN-ADDR.ARPA." . $spaces . "IN  PTR   " .
             "${host}.${CDB_DNS_DOMAIN}.";
    }

    if (defined($handles{$subnet})) {  
      $handle = $handles{$subnet};
      print $handle "$line\n";
    }
  }

  foreach $handle (keys %handles) {
    close($handle);
  }

  foreach $file (@files) {
    die "$PNAME: ERROR: Failed to rename $file.tmp: $!\n"
      if (!rename("$file.tmp", $file));

    # fix permissions the file
    chown((getpwnam($CDB_MAP_OWNER))[2],
          (getgrnam($CDB_MAP_GROUP))[2], $file) ||
             warn "$PNAME: WARNING: Failed to chown $file: $!\n";

    chmod($CDB_MAP_PERMS, $file) ||
      warn "$PNAME: WARNING: Failed to chmod $file: $!\n";
  }

  foreach $host (@CDB_DNS_SERVERS) {
    system($SCP, '-pq', @files, "$host:/var/cache/bind");
    if ( $? != 0 ) {
      warn "$PNAME: ERROR: Failed to copy DNS files to $host\n";
    }

    system($SSH, '-x', $host, '/usr/sbin/rndc reload');
    if ( $? != 0 ) {
        warn "$PNAME: ERROR: Failed to send DNS reload command to on $host\n";
    }
  }

}

#
# FUNCTION: cdb_build
#    DESCR: Build system maps from database.
#

sub cdb_build {
  my(@args) = @_;
  my(@maps) = (@args > 0) ? @args : keys(%g_cdb_maps);
  my($hostname, $file, $include, $mkstate);

  if(@args > 0) {
    foreach $map (@maps) {
      die "$PNAME: Unknown map \"$map\"\n" if(!defined($g_cdb_maps{$map}));
    }
  }

  chop($hostname = `uname -n | awk -F. '{print $1}' 2>/dev/null`);
  $hostname =~ s/\..*$//;

  if($hostname ne $ADMINHOST) {
    die "$PNAME: ERROR: You may only build from \"$ADMINHOST\"\n"
      unless($opt_X);
  }

  die "$PNAME: ERROR: You must be root to run a make\n"
    if($> != 0 && !$opt_X);

  # Even though we're only reading the database, write-lock it so we make
  # sure simultaneous builds don't occur, which might screw up NIS maps, etc.

  $mkstate = load_make_state($PATH_MKFILE);

  foreach $map (@maps) {

    if(defined($cdb_map_files{$map})) {
      $file = $cdb_map_files{$map};
      $file =~ s/^\/etc\/// if($opt_X);
      $include = $cdb_map_includes{$map};
    } else {
      $file = 0;
      $include = 0;
    }

    printflush('STDOUT', "Building $map ... ");
    &{ $g_cdb_maps{$map} }($file, $include);
    update_make_state($mkstate, $map);
    printflush('STDOUT', "done\n");

    if($file && $map ne 'dns') {
      chown((getpwnam($CDB_MAP_OWNER))[2],
            (getgrnam($CDB_MAP_GROUP))[2], $file) ||
              warn "$PNAME: WARNING: Failed to chown $file: $!\n";

      chmod($CDB_MAP_PERMS, $file) ||
        warn "$PNAME: WARNING: Failed to chmod $file: $!\n";
    }
  }

  printflush('STDOUT', "Pushing NIS maps ... ");

  if($opt_v) {
    system("/u/system/bin/ypmake");
  } else {
    system("/u/system/bin/ypmake >/dev/null");
  }

  die "$PNAME: ERROR: Failed to propagate NIS maps\n" if($? != 0);
  printflush('STDOUT', "done\n");

  write_make_state($mkstate, $PATH_MKFILE);
  return 0;
}

#
# FUNCTION: cdb_classadd
#    DESCR: Add specified hosts to a class.
#

sub cdb_classadd {
  my(@args) = @_;
  my(@classlist);
  my($mods) = 0;
  my($class, $mkstate);

  if(@args < 2) {
    warn "Usage: cdb classadd classname hostname ...\n";
    return 2;
  }

  $class = shift(@args);

 host_loop:
  foreach $host (@args) {
    if(defined($cdb_by_hostname->{$host})) {
      @classlist = split(/,/, $cdb_by_hostname->{$host}{'classes'});
      
      foreach $inclass (@classlist) {
        if($inclass eq $class) {
          warn "$PNAME: Host \"$host\" is already a member of class $class\n";
          next host_loop;
        }
      }

      push(@classlist, $class);
      $cdb_by_hostname->{$host}{'classes'} = join(',', @classlist);
      $mods++;

    } else {
      warn "$PNAME: No database record for host \"$host\"\n";
    }
  }

  print $mods, ($mods != 1) ? ' records ' : ' record ', "modified.\n";

  if($mods > 0) {
    printflush('STDOUT', "Writing database file ... ");
    write_db($cdb_by_hostname);
    printflush('STDOUT', "done\n");

    $mkstate = load_make_state($PATH_MKFILE);
    touch_make_state($mkstate, 'netgroup');
    write_make_state($mkstate, $PATH_MKFILE);
  }

  return 0;
}

#
# FUNCTION: cdb_classdel
#    DESCR: Remove a class from the database or from specified records.
#

sub cdb_classdel {
  my(@args) = @_;
  my($matches) = 0;
  my(@classlist, @hostlist);
  my($classname, $mkstate);

  if(@args == 0) {
    warn "Usage: cdb classdel classname [hostname ...]\n";
    return 2;
  }

  $classname = shift(@args);
  @hostlist = (scalar(@args) == 0) ? keys(%$cdb_by_hostname) : @args;

  foreach $host (@hostlist) {
    if(!defined($cdb_by_hostname->{$host})) {
      warn "$PNAME: WARNING: No host record found for \"$host\"\n";
      next;
    }

    @classlist = split(/,/, $cdb_by_hostname->{$host}{'classes'});

    foreach $i (0 .. $#classlist) {
      if($classlist[$i] eq $classname) {
        splice(@classlist, $i, 1);
        $matches++;
      }
    }

    $cdb_by_hostname->{$host}{'classes'} = join(',', @classlist);
  }

  print $matches, ($matches != 1) ? ' matches ' : ' match ', "found.\n";

  if($matches > 0) {
    printflush('STDOUT', "Writing database file ... ");
    write_db($cdb_by_hostname);
    printflush('STDOUT', "done\n");

    $mkstate = load_make_state($PATH_MKFILE);
    touch_make_state($mkstate, 'netgroup');
    write_make_state($mkstate, $PATH_MKFILE);
  }

  return 0;
}

#
# FUNCTION: cdb_modify
#    DESCR: Modify a client record interactively or via the command-line.
#

sub cdb_modify {
  my(@args) = @_;
  my(@modfields) = ();
  my(@modvalues) = ();
  my($host, $idx, $mkstate);

  # Get the hostname interactively or from the command-line

  if(@args > 0) {
    $host = shift(@args);
  } else {
    printflush('STDOUT', "Enter the name of the host to modify: ");
    chop($host = <STDIN>);
  }
    
  # Build lists of fields to modify if there are arguments remaining

  foreach $arg (@args) {
    if(($idx = index($arg, '=')) > 0) {
      push(@modfields, substr($arg, 0, $idx));
      push(@modvalues, substr($arg, ++$idx));
    } else {
      warn "Usage: cdb modify [ hostname [ fieldname=value ... ]]\n";
      return 2;
    }
  }

  # Verify list of fields to modify

  foreach $field (@modfields) {
    die "Unknown fieldname: $field\n" if(!defined($g_cdb_fields{$field}));
  }

  # Lock the database and verify the hostname

  $mkstate = load_make_state($PATH_MKFILE);

  die "No record for \"$host\" found in database\n"
    if(!defined($cdb_by_hostname->{$host}));

  parse_ethernet_includes();
  parse_host_includes();

  # Verify command-line values or obtain values interactively

  if(@modfields > 0) {
    foreach $i (0 .. $#modfields) {

      # Canonicalize input value

      if(defined($g_cdb_canons{$modfields[$i]})) {
        $modvalues[$i] = &{ $g_cdb_canons{$modfields[$i]} }($modvalues[$i]);
      }

      # Verify input value and perform modification

      if(defined($g_cdb_verifications{$modfields[$i]})) {
        $status =
          &{ $g_cdb_verifications{$modfields[$i]} }($host, $modvalues[$i]);
        die "$PNAME: No modications saved\n" unless($status);
      }

      # Make the actual modification to the database hash

      $cdb_by_hostname->{$host}{$modfields[$i]} = "$modvalues[$i]";

      # Touch each map in the make state file which depends on this field

      foreach $map (@{ $g_cdb_map_dependencies{$modfields[$i]} }) {
        touch_make_state($mkstate, $map);
      }
    }

  } else {
    die "$PNAME: No modifications saved\n"
      unless(modify_record($host, $mkstate));
  }     

  # Write out the changes

  printflush('STDOUT', "Writing database file ... ");
  write_db($cdb_by_hostname);
  write_make_state($mkstate, $PATH_MKFILE);
  printflush('STDOUT', "done\n");
  return 0;
}

#
# FUNCTION: cdb_classes
#    DESCR: List all classes to which a specified host belongs, or
#           list all classes in the database.
#

sub cdb_classes {
  my(@args) = @_;
  my(%classes) = ();
  my(@classes) = ();
  my($delim, $data);

  if(@args > 1) {
    command_help("classes");
    return 2;
  }

  if(@args == 1) {
    die "$PNAME: No record found for host $args[0]\n"
      unless(defined($cdb_by_hostname->{$args[0]}));

    $delim = $opt_d ? $DEF_DELIM : ' ';
    $data = $cdb_by_hostname->{$args[0]};

    print join($delim,(split(/,/, $data->{'classes'})));

    print "\n";

  } else {
    $delim = $";
    $" = $opt_d ? $DEF_DELIM : "\n";

    foreach $host (keys(%$cdb_by_hostname)) {
      $data = $cdb_by_hostname->{$host};
      foreach $class (split(/,/, $data->{'classes'})) {
        $classes{$class} = 1;
      }
    }

    @classes = sort(keys(%classes));
    print "@classes\n";
    $" = $delim;
  }

  return 0;
}

#
# FUNCTION: cdb_classlist
#    DESCR: List all hosts which belong to the specified class.
#

sub cdb_classlist {
  my(@args) = @_;
  my($delim) = $opt_d ? $DEF_DELIM : "\n";
  my($matches) = 0;
  my($first) = 1;
  my($data);

  if(@args != 1) {
    command_help("classlist");
    return 2;
  }

  foreach $host (sort(keys(%$cdb_by_hostname))) {
    if(scalar(grep(($_ eq $args[0]),split(/,/,$cdb_by_hostname->{$host}{'classes'}))) > 0){

      if($first) {
        $first = 0;
      } else {
        print $delim;
      }

      print $host;
      $matches++;
    }
  }

  if($matches) {
    print "\n";
    return 0;
  }

  warn "$PNAME: class $args[0] does not appear in database\n";
  return 1;
}

#
# FUNCTION: cdb_insert
#    DESCR: Interactively insert a new client record into the database.
#

sub cdb_insert {
  my(@args) = @_;
  my($value, $key, $mkstate);

  if(@args != 0) {
    command_help("insert");
    return 2;
  }
  
  parse_ethernet_includes();
  parse_host_includes();

  print "Create New Host Record [Type Ctrl-D or Ctrl-C to Abort]\n";
  print "Enter '?' at any time for help\n\n";

  foreach $field (sort sort_fieldnames keys(%g_cdb_fields)) {
    for(;;) {
      printflush('STDOUT', "Enter value for $field: ");
      die "\n*** Insert cancelled\n" if(eof(STDIN));
      chop($value = <STDIN>);

      if($value eq '?') {
        print "\n>>> Help for $field (", $g_cdb_fields{$field}, ") <<<\n\n";
        if(defined($g_cdb_help{$field})) {
          &{ $g_cdb_help{$field} }();
        } else {
          print "No help available for '$field'.\n";
        }
        print "\n";
        next;
      }

      if(defined($g_cdb_canons{$field})) {
        $value = &{ $g_cdb_canons{$field} }($value);
      }

      if($field eq 'hostname') {
        if(defined($cdb_by_hostname->{$value})) {
          warn "$PNAME: There is already a host record for $value\n";
          next;
        }

        $cdb_by_hostname->{$value}{'hostname'} = $value;
        $key = $value;
      }

      if(defined($g_cdb_verifications{$field})) {
        last if(&{ $g_cdb_verifications{$field} }($key, $value));
      } else {
        last;
      }
    }

    $cdb_by_hostname->{$key}{$field} = $value;
  }

  if(ynquery("Insert new record (y/n)[y]? ")) {
    printflush('STDOUT', "Writing database file ... ");
    write_db($cdb_by_hostname);
    printflush('STDOUT', "done\n");

    $mkstate = load_make_state($PATH_MKFILE);
    foreach $map (keys(%g_cdb_maps)) { touch_make_state($mkstate, $map); }
    write_make_state($mkstate, $PATH_MKFILE);

  } else {
    print "Insert cancelled.\n";
  }

  return 0;
}

#
# FUNCTION: cdb_verify
#    DESCR: Verify database consistency.  Check out the hostname, aliases,
#           ip_addr, ethernet, and os_type fields for conflicts or invalid
#           values or formats.
#

sub cdb_verify {
  my(@args) = @_;
  my($errs) = 0;
  my($data, $field);

  if(@args != 0) {
    command_help("verify");
    return 2;
  }

  print "Scanning database ...\n";

  foreach $host (sort(keys(%$cdb_by_hostname))) {
    $data = $cdb_by_hostname->{$host};

    if($host ne $data->{'hostname'}) {
      warn "$PNAME: Hostname \"", $data->{'hostname'},
        "\" does not match key $host\n";
      $errs++;
    }

    foreach $field (keys(%g_cdb_verifications)) {
      $errs++
        unless(&{ $g_cdb_verifications{$field} }($host, $data->{$field}));
    }
  }

  print "Checking IP addresses against NIS ...\n";

  foreach $host (sort(keys(%$cdb_by_hostname))) {
    chop($addr = `ypmatch $host hosts 2>/dev/null`);
    if($addr eq '') {
      warn "$PNAME: Host $host not found in NIS hosts map\n";
      $errs++;
    } else {
      $addr = (split(/\s+/, $addr))[0];
      if($addr ne $cdb_by_hostname->{$host}{'ip_addr'}) {
        warn "$PNAME: Hostname $host IP address does not match NIS map\n";
        $errs++;
      }
    }
  }

  if($errs) {
    warn "$PNAME: $errs problems detected.\n";
    return 1;
  }

  print "No problems detected.\n";
  return 0;
}

#
# FUNCTION: cdb_addfield
#    DESCR: Convenience function for database developer to add fields.
#           Don't use this unless you know how to edit this script afterward.
#

sub cdb_addfield {
  my(@args) = @_;
  my($field, $value);

  if(@args < 1 || @args > 2) {
    command_help("addfield");
    return 2;
  }

  $field = $args[0];
  $value = (@args == 2) ? $args[1] : '';

  if(defined($g_cdb_fields{$args[0]})) {
    warn "$PNAME ERROR: $args[0] is already a valid database field\n";
    return 2;
  }

  foreach $host (sort(keys(%$cdb_by_hostname))) {
    $cdb_by_hostname->{$host}{$field} = $value;
  }

  if(ynquery("Write back new database (y/n)[y]? ")) {
    printflush('STDOUT', "Writing database file ... ");
    write_db($cdb_by_hostname);
    printflush('STDOUT', "done\n");
    printflush('STDOUT', "Please edit \%g_cdb_fields appropriately.\n");
  } else {
    print "Modification aborted.\n";
  }

  return 0;
}

#
# FUNCTION: cdb_profile
#    DESCR: Print out a summary of all data for a given record.
#

$sths{'equip_select'} = $dbh->prepare("select e.comments, e.contact, e.equip_status from equipment e where e.equip_name = ?");

$sths{'comp_select'} = $dbh->prepare("select c.hw_arch, c.os, c.pxelink from equipment e, computers c where e.equip_name = ? and c.equipment_id = e.id");

$sths{'ethernet_select'} = $dbh->prepare("select ni.ethernet from equipment e, net_interfaces ni where e.equip_name = ? and e.id = ni.equipment_id");

$sths{'ip_addr_select'} = $dbh->prepare("select na.ipaddr from equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.equip_name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id");

$sths{'aliases_select'} = $dbh->prepare("select nde.name from net_dns_entries nde, equipment e, net_addresses_net_interfaces nani, net_interfaces ni, net_addresses na where e.equip_name = ? and e.id = ni.equipment_id and nani.net_interfaces_id = ni.id and nani.net_addresses_id = na.id and na.id = nde.net_address_id");

$sths{'classes_select'} = $dbh->prepare("select cc.class from comp_classes cc, computers c, comp_classes_computers ccc, equipment e where e.equip_name = ? and e.id = c.equipment_id and ccc.comp_classes_id = cc.id and ccc.computers_id = c.id");

sub cdb_profile {
  my(@args) = @_;

  if(@args != 1) {
    command_help("profile");
    return 2;
  }

  my $hostname = $args[0];
  my $host = {};

  $host{'hostname'} = $hostname;
  $host{'mxhost'} = "mx.cs.brown.edu";

  $sths{'equip_select'}->execute($hostname);
  die "$PNAME: No record for host $hostname\n" if ($sths{'equip_select'}->rows == 0);
  $sths{'equip_select'}->bind_columns(\$host{'comment'}, \$host{'contact'}, \$host{'status'});
  $sths{'equip_select'}->fetch;

  $sths{'comp_select'}->execute($hostname);
  $sths{'comp_select'}->bind_columns(\$host{'hw_arch'}, \$host{'os_type'}, \$host{'pxelink'});
  $sths{'comp_select'}->fetch;

  $sths{'ethernet_select'}->execute($hostname);
  $sths{'ethernet_select'}->bind_columns(\$host{'ethernet'});
  $sths{'ethernet_select'}->fetch;

  $sths{'ip_addr_select'}->execute($hostname);
  $sths{'ip_addr_select'}->bind_columns(\$host{'ip_addr'});
  $sths{'ip_addr_select'}->fetch;

  my @aliases = ();
  my $alias;
  $sths{'aliases_select'}->execute($hostname);
  $sths{'aliases_select'}->bind_columns(\$alias);
  while ($sths{'aliases_select'}->fetch) {
    if ($alias ne $hostname) {
      push @aliases, $alias;
    }
  }

  $host{'aliases'} = join(',',@aliases);

#  'aliases' => 'List of host aliases',
#  'classes' => 'Classes for unattended installation',


  foreach $field (sort sort_fieldnames keys(%g_cdb_fields)) {
    if (not $host{$field}) {
      $host{$field} = '';
    }
    print $field, ' = ', $host{$field}, "\n";
  }

  return 0;
}

#
# FUNCTION: cdb_make
#    DESCR: Dynamically rebuild maps based on changes.
#

sub cdb_make {
  my(@args) = @_;

  my($opt_n) = 0; # Print commands to be executed, but don't execute them
  my($opt_P) = 0; # Report dependency information, but don't build anything

  my($mkstate, $modtime, $bldtime, $arg);
  my($hostname, $str, $file, $include, $mkall);
  my(@stbuf1, @stbuf2);
  my($tcnt) = 0;
  my(@targets) = ();
  my(@files) = ( $PATH_CFFILE, $PATH_DBFILE );

  # Parse the remaining command-line arguments

  while(scalar(@args) > 0) {
    $arg = shift(@args);
    if(substr($arg, 0, 1) eq '-') {
      if($arg eq '-P') {
        $opt_P = 1;
      } elsif($arg eq '-n') {
        $opt_n = 1;
      } else {
        die "$PNAME: illegal make option -- $arg\n";
      }
    } elsif(defined($g_cdb_maps{$arg})) {
      push(@targets, $arg);
    } else {
      die "$PNAME: Unknown map \"$arg\"\n";
    }
  }

  # Check all targets if no targets were specified explicitly

  @targets = keys(%g_cdb_maps) if(scalar(@targets) == 0);

  # If -P is specified, just report latest dependency information and return

  if($opt_P) {
    $mkstate = load_make_state($PATH_MKFILE);

    # Print out which files we're using

    print "Configuration file $PATH_CFFILE\n";
    print "Database file $PATH_DBFILE\n\n";

    # If special files are more recent than make state file itself,
    # then all maps will be rebuilt since they depend on these special files

    @stbuf1 = stat($PATH_MKFILE);
    push(@files, values(%cdb_map_includes));

    foreach $file (@files) {
      @stbuf2 = stat($file);
      next if(scalar(@stbuf2) == 0);

      if($stbuf2[$ST_MTIME] > $stbuf1[$ST_MTIME]) {
        foreach $map (keys(%$mkstate)) {
          $str  = defined($cdb_map_files{$map}) ? $cdb_map_files{$map} : $map;
          $str .= ":\t$file\n";
          print $str;
        }
        return 0;
      }
    }

    # Otherwise pull dependencies from make state file

    foreach $map (keys(%$mkstate)) {
      $modtime = $mkstate->{$map}->[$MK_MODTIME];
      $bldtime = $mkstate->{$map}->[$MK_BLDTIME];

      if($bldtime <= $modtime) {
        $modtime = $modtime == 0 ? 'unknown' : fmt_time($modtime);
        $bldtime = $bldtime == 0 ? 'unknown' : fmt_time($bldtime);

        $str  = defined($cdb_map_files{$map}) ? $cdb_map_files{$map} : $map;
        $str .= ":\tlast build $bldtime, modified $modtime\n";
        
        print $str;
        $tcnt++;
      }
    }
 
    print "All targets are up to date.\n" if($tcnt == 0);
    return 0;
  }

  # Otherwise iterate through targets building whatever has been modified

  chop($hostname = `uname -n 2>/dev/null`);
  $hostname =~ s/\..*$//;

  if($hostname ne $ADMINHOST) {
    die "$PNAME: ERROR: You may only build from \"$ADMINHOST\"\n"
      unless($opt_X);
  }

  die "$PNAME: ERROR: You must be root to build NIS maps\n"
    if($> != 0 && !$opt_X && !$opt_n);

  # Even though we're only reading the database, write-lock it so we make
  # sure simultaneous builds don't occur, which might screw up NIS maps, etc.

  $mkstate = load_make_state($PATH_MKFILE);

  # If special files are more recent than make state file itself,
  # then all maps will be rebuilt since they depend on these special files

  @stbuf1 = stat($PATH_MKFILE);
  push(@files, values(%cdb_map_includes));
  $mkall = 0;

  foreach $file (@files) {
    @stbuf2 = stat($file);
    next if(scalar(@stbuf2) == 0);
    if($stbuf2[$ST_MTIME] > $stbuf1[$ST_MTIME]) {
      $mkall = 1;
      last;
    }
  }

  # Examine targets list and rebuild map if necessary

  foreach $map (@targets) {
    next if(!$mkall &&
            $mkstate->{$map}->[$MK_BLDTIME] > $mkstate->{$map}->[$MK_MODTIME]);

    $tcnt++;

    if($opt_n) {
      print "cdb build $map\n";
      next;
    }

    if(defined($cdb_map_files{$map})) {
      $file = $cdb_map_files{$map};
      $file =~ s/^\/etc\/// if($opt_X);
      $include = $cdb_map_includes{$map};
    } else {
      $file = 0;
      $include = 0;
    }

    printflush('STDOUT', "Building $map ... ");
    &{ $g_cdb_maps{$map} }($file, $include);
    update_make_state($mkstate, $map);
    printflush('STDOUT', "done\n");

    if($file && $map ne 'dns') {

      chown((getpwnam($CDB_MAP_OWNER))[2],
            (getgrnam($CDB_MAP_GROUP))[2], $file) ||
              warn "$PNAME: WARNING: Failed to chown $file: $!\n";

      chmod($CDB_MAP_PERMS, $file) ||
        warn "$PNAME: WARNING: Failed to chmod $file: $!\n";
    }
  }

  # Push out NIS maps, unless -n was specified

  unless($opt_n) {
    printflush('STDOUT', "Pushing NIS maps ... ");
    if($opt_v) {
      system("/u/system/bin/ypmake");
    } else {
      system("/u/system/bin/ypmake >/dev/null");
    }
    die "$PNAME: ERROR: Failed to propagate NIS maps\n" if($? != 0);
    printflush('STDOUT', "done\n");
    write_make_state($mkstate, $PATH_MKFILE);
  }

  print "All targets are up to date.\n" if($tcnt == 0);
  return 0;
}

# print out extended help

sub cdb_help {

  if (@_ == 1) {
    command_help($ARGV[0]);
  } else {
    print $USAGE;
    print "options:\n\n";
    print "  -V Display version info\n";
    print "  -v Set verbose mode\n\n";
    print "  -u Specify username (default is current user)\n\n";
    print "all commands:\n\n";
    foreach $k (sort(keys(%g_cdb_commands))) {
      print "  $k\t" , $g_cdb_commands{$k}{'desc'}[0] , "\n";
    }
    print "\n";
  }
  return 0;
}

sub cdb_contactlist {
  my(@args) = @_;
  my($delim) = $opt_d ? $DEF_DELIM : "\n";
  my($matches) = 0;
  my($first) = 1;
  my($data);

  if(@args != 1) {
    command_help("contactlist");
    return 2;
  }

  printf "%-15s%-40s%-10s%-10s\n\n", "MACHINE", "SERVICES", "CONTACTS";

  foreach $host (sort(keys(%$cdb_by_hostname))) {
    if (scalar(grep(($_ eq $args[0]), split(/,/, $cdb_by_hostname->{$host}{'classes'}))) > 0) {

      $services = $cdb_by_hostname->{$host}{'comment'};
      $contact = $cdb_by_hostname->{$host}{'contact'};
      printf "%-15s%-40s%-10s\n", $host, $services, $contact;
    }
  }

}

# Load the configuration file and perform some checking on it

die "$PNAME: $PATH_CFFILE: $!\n" unless(-f("$PATH_CFFILE"));
eval('require("$PATH_CFFILE");');
die "$PNAME: Failed to load $PATH_CFFILE: $@\n" if($@);

die "$PNAME: $PATH_CFFILE must define CDB_BOOT_TYPE\n"     unless(defined($CDB_BOOT_TYPE));
die "$PNAME: $PATH_CFFILE must define CDB_DBF_GROUP\n"     unless(defined($CDB_DBF_GROUP));
die "$PNAME: $PATH_CFFILE must define CDB_DBF_PERMS\n"     unless(defined($CDB_DBF_PERMS));
die "$PNAME: $PATH_CFFILE must define CDB_DHCP_SERVERS\n"  unless(defined(@CDB_DHCP_SERVERS));
die "$PNAME: $PATH_CFFILE must define CDB_DNS_MXPREF\n"    unless(defined($CDB_DNS_MXPREF));
die "$PNAME: $PATH_CFFILE must define CDB_DNS_FWD_DBS\n"   unless(defined(@CDB_DNS_FWD_DBS));
die "$PNAME: $PATH_CFFILE must define CDB_DNS_SERVERS\n"   unless(defined(@CDB_DNS_SERVERS));
die "$PNAME: $PATH_CFFILE must define CDB_MAP_GROUP\n"     unless(defined($CDB_MAP_GROUP));
die "$PNAME: $PATH_CFFILE must define CDB_MAP_GROUP\n"     unless(defined($CDB_MAP_OWNER));
die "$PNAME: $PATH_CFFILE must define CDB_MAP_PERMS\n"     unless(defined($CDB_MAP_PERMS));
die "$PNAME: $PATH_CFFILE must define CDB_NETGROUP_DIRS\n" unless(defined(@CDB_NETGROUP_DIRS));
die "$PNAME: $PATH_CFFILE must define NG_DHCP\n"           unless(defined($NG_DHCP));
die "$PNAME: $PATH_CFFILE must define NG_WPKG\n"           unless(defined($NG_WPKG));

# Install signal handlers

$SIG{'INT'} = \&sighandler;
$SIG{'HUP'} = \&sighandler;
$SIG{'TERM'} = \&sighandler;

# Execute the appropriate subcommand

if(defined($g_cdb_commands{$ARGV[0]})) {
  $g_cmdname = shift(@ARGV);
  $g_status = &{ $g_cdb_commands{$g_cmdname}{'fn'} }(@ARGV);
  exit($g_status);
}

die "$PNAME: Invalid command -- $ARGV[0]\n$USAGE";

__END__

=head1 NAME

cdb - Client database front-end

=head1 SYNOPSIS

cdb [-hv] command [args ...]

=head1 DESCRIPTION

The client database is a simple database of network clients which can be used
to automatically generate system-wide configuration files, such as NIS maps,
DNS zone files, and network boot information.  Each record in the database
corresponds to a network connection, i.e. a unique IP address.  In most cases,
each record also corresponds to a single machine connected to the network, but
this is not always the case.  A single logical machine may have multiple
network interfaces, and will therefore have multiple database entries.
Additionally, some network devices with names and IP addresses may not
correspond to a workstation; there may be entries for networked printers,
dialup multiplexors, and other devices.

The B<cdb> database front-end program reads in the latest copy of the database
and a configuration file describing various parameters for the domain, and then
allows the user to add, remove, or modify records, or to perform simple
queries.  Using the front-end also reduces errors: all names and addresses are
automatically converted to standard formats, and the database automatically
checks for conflicts, preventing duplicate hostnames or addresses from being
entered into the database.  If changes have been made, the B<cdb make> command
is used to rebuilt all system configuration files which will be affected by the
changes.  The database modifications may be performed safely by any user with
appropriate privileges from any machine.  The rebuild command must be issued as
root from the NIS master machine.

Each client stored in the database must belong to a designated primary
netgroup, which must be described in the database configuration file, and may
also belong to one or more supplementary netgroups.  Based on the client's
primary group, the information for a record will be output to one or more
system-wide maps when they are generated from the database.  This allows the
administrator to configure, for example, a primary group for which
B<hosts.equiv(4)> entries will be generated, and another primary group for
which they will not.  All primary groups and the maps they will produce are
defined in the database configuration file.

Each database record consists of a set of fields which are stored as ASCII
text strings.  Certain fields are mandatory and must contain legal values.
Other fields are optional, and may be left blank.  The front-end software
enforces these policies so that the user cannot insert an invalid record.
The fields associated with each record are:

.SS "hostname"
The client's unqualified Internet hostname.  This field is guaranteed to be
unique in the database.
.SS "aliases"
A comma-separated list of Internet host aliases.  Each alias is guaranteed to
be unique to both the aliases and hostname fields across all database records.
.SS "prim_grp"
The client's primary netgroup.  This field is verified to be a valid primary
group in the database configuration file.
.SS "supp_grps"
A comma-separated list of supplementary netgroups.  This field may be left
blank, or set to a list of arbitrary netgroup names, which must not be the
names of any known primary group.  When the
.BR netgroup(4)
map is generated, entries for all known supplementary netgroup names will be
created.
.SS "ip_addr"
The client's IP address in dotted-decimal format.  This field is always required
and it guaranteed to be unique across all database records.
.SS "ethernet"
The client's 48-bit ethernet address.  This field is guaranteed to be unique
across all database records.  The field may be left blank, unless the record's
primary group is used to generate the
.BR ethers(4)
map, in which case it is required.
.SS "hw_arch"
The client's hardware architecture.  This field is typically set to the output
of the
.BR uname(1) \-m
command run on the client machine.  This field may be left blank, unless the
record's primary group is used to generate a
.BR tftp(1)
network boot image, in which case it is required.
.SS "os_type"
The client's operating system type string.  This field may be left blank, unless
the client's primary group is used to generate the
.BR bootparams(4)
map, it which case it is required and must be set to one of the valid operating
system types defined in the database configuration file.
.SS "mxhost"
The fully-qualified Internet name of another host which exchanges electronic
mail for the client.  If not blank, this field is used to generate MX records
in the DNS zone files created by the front-end.
.SS "port"
The client's network port.  This field is entirely optional, and is meant to
be used to record the network jack number to which the client is connected.
.SS "comment"
An arbitrary comment describing the host.  This field may be left blank.
.SS "status"
The current machine status, selected from the legal status strings set
in the configuration file.

=head1 OPTIONS

=over

.TP
.BI "\-h"
Display a list of commands and options.
.TP
.BI "\-V"
Display version information.
.TP
.BI "\-v"
Set verbose mode.
.TP
.BI "\-f"
Force creation of a new empty database if specified database is not found.
.TP
.BI "\-s field"
Sort output by specified field name.  Use ``cdb print'' for a list of fields.
Output is unsorted if no -s option is specified.
.TP
.BI "\-d delim"
Specify output delimeter.  Fields are delimited by tabs or newlines where
appropriate if no -d option is specified.
.TP
.BI "\-b dbfile"
Specify pathname of an alternate database file.  The database
/u/system/lib/cdb_data.pl is used if no -b option is specified.
.TP
.BI "\-c configfile"
Specify pathname of an alternate configuration file.  The configuration file
/u/system/lib/cdb_config.pl is used if no -c option is specified.
.TP
.BI "cdb print [field ...]"
Print specified fields of all records.
.TP
.BI "cdb query [field[=regexp] ...]"
Print records matching criteria.
.TP
.BI "cdb insert"
Interactively insert a new client record.
.TP
.BI "cdb modify [hostname [field=value ...]]"
Modify specified client record.
.TP
.BI "cdb delete [hostname ...]"
Delete specified records.
.TP
.BI "cdb joingrp grpname hostname ..."
Add hosts to supplementary netgroup.
.TP
.BI "cdb rmgrp grpname [hostname ...]"
Remove some or all hosts from specified supplementary netgroup.
.TP
.BI "cdb groups [hostname]"
List netgroups to which a given host belongs, or list all netgroups.
.TP
.BI "cdb grplist grpname"
List members of specified netgroup.
.TP
.BI "cdb profile hostname"
Print summary of specified client record.
.TP
.BI "cdb build [map ...]"
Force rebuild of one or all system maps.
.TP
.BI "cdb make [-P] [-n] [map ...]"
Rebuild maps which need to be updated based on changes since last build.
.TP
.BI "cdb verify"
Verify internal database consistency.
.TP
.BI "cdb addfield fieldname [value]"
Add new field to all database records (for developers only).
.TP
.BI "cdb search hostname [dir1...]"
Search jumpstart tree for host.xxx and netgroup.xxx files.
.TP
.BI "cdb find hostname pathname"
Search a host's jumpstart tree for a specific pathname.
=item B<-h>, B<--help>

Print a help message and exit.

=item B<-n>

Do nothing.  Runs rsync in dry-run mode - does not actually update
anything, but reports which files would be updated.

=item B<-v>

Verbose.  The normal webupdate output shows only files updated.  This
option shows links and directories updated, and deletions, too.  The
format differs, as this turns on rsync's verbose option.

=item B<-x>

Print the exclude file that would be given to rsync.

=back

=head1 COMMANDS

.SS "cdb print [field ...]"
.TP
.B "DESCRIPTION"
Print the specified fields from each database record.  Field names are printed
in order and separated by tabs, or the delimiter specified with the
.B \-d
option.  The output is unsorted unless a sort order is specified with the
.B \-s
option.  If no options are specified, a list of the valid field names is
printed.
.TP
.B "OPTIONS"
.TP 5
.I "field"
The name of a field whose value should be printed.
.SS "cdb query [field[=regexp] ...]"
.TP
.B "DESCRIPTION"
Query the database for fields whose values match the specified regular
expressions, and then print the specified fields corresponding to each record.
Each argument to this command is interpreted as either matching criteria or
the name of a field to print in the output.  Field names are printed in order
and separated by tabs, or the delimiter specified with the
.B \-d
option.  The output is unsorted unless a sort order is specified with the
.B \-s
option.
.TP
.B "OPTIONS"
.TP 5
.I "field"
The name of a field whose value should be printed in the output.
.TP 5
.I "field=regexp"
The name of a field which should be used as matching criteria.  The field will
not be printed in the output unless it is also specified alone without the
.I =regexp
suffix on the command line.  The
.I regexp
argument is expected to be in Perl regular expression format (see
.BR perlre(l)
for the complete syntax), and may require quoting to prevent regular expression
meta-characters from being interpreted as shell meta-characters.  Records are
matched if they match the logical 
.B and
of the selection criteria.
.SS "cdb insert"
.TP
.B "DESCRIPTION"
Interactively insert a new database record.  The user will be prompted for the
value of each field, which will be converted to an appropriate canonical format
if possible, and verified to be valid and unique where appropriate.  At any
time, the user may type a question-mark (``?'') and press return to view help
information on the current field.  The administrator should execute
.B cdb make
after inserting a new database record.
.SS "cdb modify [hostname [field=value ...]]"
.TP
.B "DESCRIPTION"
Modify one or more fields of an existing database record.  If no hostname
is specified, the user is interactively prompted for the hostname of the record
to modify.  If only a hostname is specified, the user is interactively prompted
for which fields to modify and their new values.  If a hostname and one or more
.I "field=value"
arguments are specified, the specified values are set to the given values and
the front-end immediately exits and saves the modifications.  In all cases,
each new field value is converted to a canonical format if appropriate and
validated using the previously described requirements for each field.  The
front-end will not save invalid modifications to the database.  In interactive
mode, the user will be prompted to save changes at the end of the modifications.
The administrator should execute
.B cdb make
after modifying a database record.
.TP
.B "OPTIONS"
.TP 5
.I "hostname"
The value of the hostname field identifying the record to be modified.
.TP 5
.I "field=value"
Set the specified field to the specified value.  Any number of these arguments
may be present on the command line.  If the new value contains whitespace or
shell meta-characters, it may be necessary to use appropriate shell quoting
syntax to surround the argument on the command line.
.SS "cdb delete [hostname ...]"
.TP
.B "DESCRIPTION"
Delete one or more client records, identified by their hostnames, from the
database.  The administrator should execute
.B cdb make
after deleting database records.
.TP
.B "OPTIONS"
.TP 5
.I "hostname"
The value of the hostname field identifying the record to be deleted.  One or
more hostnames may be specified on the command line.
.SS "cdb joingrp grpname hostname ..."
.TP
.B "DESCRIPTION"
Add one or more hosts to a supplementary netgroup.  If the group does not exist,
it will be automatically created the next time the netgroup map is rebuilt.
The administrator should execute
.B cdb make
after machines join new groups.
.TP
.B "OPTIONS"
.TP 5
.I "grpname"
The name of the supplementary group to join.  This must be a string of
alphanumeric characters which is not the name of an existing primary netgroup.
.TP 5
.I "hostname"
The value of the hostname field identifying a record whose
.B supp_grps
field should be modified to include the specified
.I grpname
.
.SS "cdb rmgrp grpname [hostname ...]"
.TP
.B "DESCRIPTION"
Remove one or more or all hosts from a supplementary netgroup.  If one or more
hostnames are specified on the command line, the specified netgroup is removed
from the
.B supp_grps
field of each record.  If only a netgroup name is given on the command line,
the specified netgroup is removed from all client records, effectively removing
the netgroup.  The administrator should execute
.B cdb make
after removing a supplementary netgroup from client records.
.TP
.B "OPTIONS"
.TP 5
.I "grpname"
The name of the supplementary group to remove.  This must be a string of
alphanumeric characters which is not the name of an existing primary netgroup.
.TP 5
.I "hostname"
The value of the hostname field identifying a record whose
.B supp_grps
field should be modified to not include the specified
.I grpname
.
.SS "cdb groups [hostname]"
.TP
.B "DESCRIPTION"
Print the list of netgroups (including both primary and supplementary groups)
to which the specified host belongs, or print the complete list of netgroups
in the database (if no hostname argument is specified on the command line).
The names are delimited by tabs or newlines, or by the delimiter specified by
the
.B \-d
option.
.TP
.B "OPTIONS"
.TP 5
.I "hostname"
The value of the hostname field identifying a record whose
.B prim_grp
and
.B supp_grps
fields should be printed.
.SS "cdb grplist grpname"
.TP
.B "DESCRIPTION"
List the members of the specified netgroup, which may be either a primary
netgroup name or supplementary netgroup name.  The
.B hostname
field of each matched record is printed, separated by newlines, or by the
delimiter specified by the
.B \-d
option.
.TP
.B "OPTIONS"
.TP 5
.I "grpname"
The name of the primary or supplementary netgroup whose members will be
printed.
.SS "cdb profile hostname"
.TP
.B "DESCRIPTION"
Print a formatted listing of the values of each field of the client record for
the specified hostname.
.TP
.B "OPTIONS"
.TP 5
.I "hostname"
The value of the hostname field identifying a record whose fields should be
printed.
.SS "cdb build [map ...]"
.TP
.B "DESCRIPTION"
Force the rebuild of one or more or all system maps.  In our terminology, a
map is a file or set of files providing some system-wide information which is
automatically built by the front-end from the current contents of the database,
and an optional set of include files.  Typically the administrator does not
need to use this command; instead the
.B cdb make
command is used, which automatically rebuilds on those maps which need to be
built based on the changes made to the database since the last build or make.
However, this command is provided for completeness, and because there may be
some extenuating circumstances where a manual rebuild is necessary.  If no
arguments are given on the command line, all maps are built; otherwise only
those maps whose names are specified are built.
.TP
.B "OPTIONS"
.TP 5
.B "ethers"
The
.B /etc/ethers
file on the NIS master will be rebuilt and pushed out to the clients.  If an
include file is defined for this map in the
.I %cdb_map_includes
hash in the configuration file, it will be included in the output file.
.TP 5
.B "hosts"
The
.B /etc/hosts
file on the NIS master will be rebuilt and pushed out to the clients.  If an
include file is defined for this map in the
.I %cdb_map_includes
hash in the configuration file, it will be included in the output file.
.TP 5
.B "hosts.equiv"
The 
.B /etc/hosts.equiv
file on the NIS master will be rebuilt.  This file will then be copied to each
host listed in the
.I %cdb_equiv_slaves
hash in the configuration file using the
.BR rcp(1)
command.  Finally, the file is copied to the
.B data/files/add/all/etc/hosts.equiv
file located within each Custom JumpStart directory listed in the
.I $cdb_os_types
hash in the configuration file.  The JumpStart cron job on each machine will
then pick up these changes at the time of the next client update.
.TP 5
.B "bootparams"
The
.B /etc/bootparams
file on the NIS master will be rebuilt and pushed out to the clients.  If an
include file is defined for this map in the
.I %cdb_map_includes
hash in the configuration file, it will be included in the output file.
.TP 5
.B "netgroup"
The
.B /etc/netgroup
file on the NIS master will be rebuilt and pushed out to the clients.  If an
include file is defined for this map in the
.I %cdb_map_includes
hash in the configuration file, it will be included in the output file.
.TP 5
.B "tftpboot"
The network boot images for client machines, stored in the directory
.B /tftpboot
on the boot server (assumed to be the same machine as the NIS master), will be
recreated.  Using the location of the network boot images specified in the
.I $cdb_os_types
hash in the configuration file, the front-end copies the boot images for each
active operating system type and hardware architecture to files named
.B inetboot.hw_arch.os_type
, where
.I hw_arch
and
.I os_type
correspond to the values of these fields in the corresponding client records.
For each client record of a given hardware architecture and operating system
type, two symbolic links are then created in the
.B /tftpboot
directory to the appropriate inetboot binary.  The first symbolic link is
named by converting each byte of the client record's 4-byte IP address to two
hexadecimal digits (e.g. IP address 128.148.33.114 is converted to link name
80942172).  The second link has the same name as the first, except that a
.I .hw_arch
suffix is added, where the suffix is formed by converting the value of the
client record's
.B hw_arch
field to uppercase letters.  This is needed for compatibility with older
revisions of the OpenBoot PROM software.
.TP 5
.B "dns"
The DNS zone files stored in the
.B /var/named
directory on the primary DNS server for the zone (assumed to be the same machine
as the NIS master) are rebuilt, and the name service daemon is signaled to
re-read the new zone files.  The location of the DNS zone files may be
configured using the
.I $CDB_DNS_DIR
tunable.  The DNS domain name for the site may be configured using the
.I $CDB_DNS_DOMAIN
tunable.  The preference value for DNS MX records generated from the value
of the
.B mxhost
field associated with client records may be configured using the
.I $CDB_DNS_MXPREF
tunable.  Each of these options is stored in the database configuration file.
The DNS serial number is read from the existing files, and is incremented in
the new output files.
.SS "cdb make [-P] [-n] [map ...]"
.TP
.B "DESCRIPTION"
Rebuild system maps exactly as with the
.B cdb build
command described previously, but only rebuild a map if modifications to the
database since the previous
.B cdb build
or
.B cdb make
require that the map be regenerated.  If no map names are specified on the
command line, all maps are checked and rebuilt if necessary.  If one or more
map names are specified, only those maps are checked and rebuilt.
.TP
.B "OPTIONS"
.TP 5
.B \-P
Print detailed dependency information regarding which maps need to be rebuilt
and why, but do not actually rebuild them.  This option is used primarily for
debugging purposes.
.TP 5
.B \-n
Print the names of the maps which need to be rebuilt, but do not actually
rebuild them.  Useful for determining what the result of a
.B cdb make
would be without actually changing the current state of the system.
.TP 5
.I map
Specify the name of a map to be checked and rebuilt if necessary.  The valid
map names are described in the previous section on options to the
.B cdb build
command.
.SS "cdb verify"
.TP
.B "DESCRIPTION"
Verify the internal consistency of the database.  Several internal checks are
performed, including examining the values of the
.B hostname, aliases, ip_addr, ethernet,
and
.B os_type
fields for invalid values, formats, or conflicts.  Finally, the 
.B ip_addr
field of each record is compared to the current IP address for the host
reported by an NIS lookup.
.SS "cdb addfield fieldname [value]"
.TP
.B "DESCRIPTION"
This command is designed to be used by database developers as a convenient
mechanism for extending the database.  This command should not be used unless
the administrator is prepared to subsequently modify the code for the front-end
itself.  The command reads in the entire database, adds a new empty field or
field with the given value to each record, and then rewrites the database file.
Following this command, the front-end itself should be modified to provide
support for the new field.  Specifically, the
.I %g_cdb_fields
hash should be extended to define the field name and a corresponding textual
description.  The
.I %g_cdb_map_dependencies
hash should be extended to define which maps need to be rebuilt if this field's
value is modified in any record.  The
.I %g_cdb_help
hash should be extended to define a reference to a function which prints help
information for this field.  The
.I %g_cdb_canons
hash may be optionally extended to define a reference to a function which
converts an input string to a canonical format for this data type.  The
.I %g_cdb_verifications
hash may be optionally extended to define a reference to a function which
verifies a canonical input string to confirm its uniqueness or validity.  The
.I %g_cdb_comparisons
hash may be optionally extended to define a reference to a function which
provides a custom sorting comparison algorithm for this data type.
.TP
.B "OPTIONS"
.TP 5
.I fieldname
Specifies the name of the new field.
.TP 5
.I value
Specifies an initial starting value for this field in all client records.
.SS "cdb search hostname [dir1 dir2 .. dirn]"
.TP
.B "DESCRIPTION"
This command searches the jumpstart tree associated with the host.  It
looks for special configuration files such as host.xxx files,
netgroup.xxx files and override files and prints the paths of the
existing files.
.TP
.B "OPTIONS"
.TP 5
.I hostname
Specifies the host name to search for.
.TP 5
.I dir1 dir2 ... dirn
optional list of directories to ignore when printing the files/add
tree for a host or netgroup (helpful when printing trees of servers
that have a bazillion entries).
.SS "cdb find hostname pathname"
.TP
.B "DESCRIPTION"
This command searches a host's jumpstart tree for a pathname matching
that specified in the command line.  The pathname must start with a /.
The command returns an error if the invoker doesn't have permission to
search one or more directories in the specified path.
.TP
.B "OPTIONS"
.TP 5
.I hostname
Specifies the host whose jumpstart tree will be searched.
.TP 5
.I pathname
Specifies the pathname to search for in the host's jumpstart tree.

=head1 FILES

.TP
.B /etc/bootparams
.TP
.B /etc/ethers
.TP
.B /etc/hosts
.TP
.B /etc/hosts.equiv
.TP
.B /etc/named.pid
.TP
.B /etc/netgroup
.TP
.B /u/system/lib/.cdb_make.state
.TP
.B /u/system/lib/cdb_config.pl
.TP
.B /u/system/lib/cdb_data.pl
.TP
.B /var/yp/Makefile

=head1 AUTHORS

Mike Shapiro. DNS database build routines written by Stephanie Schaaf. UDB port
written by Aleks Bromfield.

=head1 SEE ALSO

B<rsync>(1), B<ssh>(1)

.PP
Application programs:
.BR rcp (1)
.BR uname (1)
.BR ypcat (1)
.BR ypmatch (1)
.BR ypwhich (1)
.PP
Maintenance commands:
.BR in.named (1m)
.BR in.rarpd (1m)
.BR in.tftpd (1m)
.BR ypserv (1m)
.PP
File formats:
.BR bootparams (4)
.BR ethers (4)
.BR hosts (4)
.BR hosts.equiv (4)
.BR netgroup (4)
.BR ypfiles (4)
.PP
Local reference:
.BR perl (l)
.BR perlre (l)
.PP

=head1 NOTES

Access to read and write the cdb database file and configuration file is
determined by the UNIX file permissions on these files.  UNIX file locking,
across NFS if necessary, is used to read or write-lock the database file
depending on the type of operation being performed.

The B<cdb> system assumes that all master maps are kept on a single Sun NIS
server, which also serves as the boot server for Solaris network installation.
No provisions have been made for NIS+ at this time.

=head1 BUGS

Doesn't report the removal of files and directories except those
excluded by a .private file.  This is a feature of rsync.

=cut

