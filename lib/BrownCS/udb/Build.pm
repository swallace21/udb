package BrownCS::udb::Build;
use Moose;

use Template;
use Template::Stash;
use FindBin qw($RealBin);
use BrownCS::udb::Util qw(:all);
use NetAddr::IP qw(Coalesce);
use List::MoreUtils qw(uniq);

has 'udb' => ( is => 'ro', isa => 'BrownCS::udb::Schema', required => 1 );
has 'verbose' => ( is => 'ro', isa => 'Bool', required => 1 );
has 'dryrun' => ( is => 'ro', isa => 'Bool', required => 1 );
has 'tt' => ( is => 'ro', isa => 'Template', required => 0 );

sub BUILD {
  my $self = shift;
  $self->{tt} = Template->new({INCLUDE_PATH => "$RealBin/../templates"}) || die "$Template::ERROR\n";
  my $TMPDIR = tempdir("/tmp/udb-build.XXXX");
}


sub maybe_system {
  my $self = shift;
  my $udb = $self->udb;
  if ($self->verbose) {
    print "@_\n";
  }
  if (not $self->dryrun) {
    system(@_);
  }
}

sub maybe_rename {
  if($dryrun) return;
  my $self = shift;
  my $udb = $self->udb;
  my ($old, $new) = @_;
  if ($self->verbose) {
    print "rename $old to $new\n";
  }
  if (not $self->dryrun) {
    die "$0: ERROR: Failed to rename $new: $!\n" if(!rename("$old", "$new"));
  }
}

sub commit_local {
  my $self = shift;
  my $udb = $self->udb;
  my $dst = $_[-1];
  if ($self->verbose) {
    print "Committing $dst on local\n";
  }
  if (not $self->dryrun) {
    # The following line works. Think about it. 
    if (!system("cp @_") == 0){
      die "$0: ERROR: Failed committing $dst: $!\n" ;
    }
  }
}

sub commit_scp {
  my $self = shift;
  my $udb = $self->udb;
  my $dst = $_[-1];
  if ($self->verbose) {
    print "Committing $dst via scp\n";
  }
  if (not $self->dryrun) {
    # The following line works. Think about it. 
    if (!system("sudo scp -pq @_") == 0){
      die "$0: ERROR: Failed committing $dst: $!\n" ;
    }
  }
}

sub build_tftpboot {
  my $self = shift;
  my $udb = $self->udb;

  system("sudo -v");

  print "Building tftpboot... ";

  my $tftpboot_path = "/maytag/sys0/tftpboot/pxelinux.cfg";

  my $addrs = $udb->resultset('NetAddresses')->search({},
    {
      prefetch => {
        'primary_interface' => {
          'device' => {
            'computer' => 'os_type'
          }
        }
      },
      order_by => [qw(ipaddr)],
    });

  my $host_classes = get_host_class_map($udb);

  while (my $addr = $addrs->next) {
    my $iface = $addr->primary_interface;
    next if not defined $iface;

    my $comp = $iface->device->computer;
    next if not defined $comp;

    my $os = ($comp->os_type);
    next if not defined $os;

    my $bootimage;

    if (defined $comp->pxelink) {
      $bootimage = $comp->pxelink;
    } elsif ($os->os_type eq 'debian') {
      $bootimage = "fai-workstation-i386";
    } elsif ($os->os_type eq 'debian64') {
      $bootimage = "fai-workstation-amd64";
    }

    next if not defined($bootimage);

    if (grep /^server$/, @{$host_classes->{$comp->device_name}}) {
      $bootimage =~ s/workstation/server/g;
    }

    next if not defined $addr->ipaddr;
    my $hex_ip = ipv4_n2x($addr->ipaddr);

    if ($self->verbose) {
      printf "link %s (%s) -> %s\n", $comp->device_name, $hex_ip, $bootimage;
    }
    if (not $self->dryrun) {
      maybe_system("sudo rm $tftpboot_path/$hex_ip");
      maybe_system("sudo ln -s $bootimage $tftpboot_path/$hex_ip");
    }
  }

  print "done.\n";
}

sub add_to_group {
  my $self = shift;
  my $udb = $self->udb;
  my ($netgroups, $grp, $host) = @_;

  if(defined($netgroups->{$grp})) {
    $netgroups->{$grp} .= ":(${host},,)";
  } else {
    $netgroups->{$grp} = "(${host},,)";
  }

}

sub build_netgroup {
  my $self = shift;
  my $udb = $self->udb;

  BrownCS::udb::Util::okay_kerberos;

  print "Building netgroups... ";

  my $hosts = $udb->resultset('Computers')->search(
    {
      'net_dns_entries.authoritative' => 1,
      'net_dns_entries.dns_region' => 'internal',
    },
    {
      prefetch => [
      'os_type',
      {
        'device' => [
        'manager',
        {
          'net_interfaces' => {
            'net_addresses_net_interfaces' => {
              'net_address' => 'net_dns_entries',
            },
          },
        },
        ]
      },
      ],
      '+select' => [ 'net_dns_entries.domain' ],
      '+as'     => [ 'Domain' ],
      order_by => [qw(me.device_name)],
    });

  my $host_classes = get_host_class_map($udb);

  my $netgroups = {};

  while (my $host = $hosts->next) {

    my $hostname = $host->device_name;
    my $fqdn = ($host->device_name . "." . $host->get_column('Domain'));
    my $manager = $host->device->manager->management_type;

    my $os = $host->os_type;
    next if not defined $os;

    if (($manager eq 'tstaff') and ($os->trusted_nfs)) {
      $self->add_to_group($netgroups, "trusted", $fqdn);
    }

    my $classes_ref = $host_classes->{$hostname};
    next if not $classes_ref;
    my @classes = @{$classes_ref};

    for (@classes) {

      if (/^camera$/) {
        $self->add_to_group($netgroups, "camera", $fqdn);
      } elsif (/^cgc$/) {
        $self->add_to_group($netgroups, "cgc", $fqdn);
      } elsif (/^graphics$/) {
        $self->add_to_group($netgroups, "graphics", $fqdn);
      } elsif (/^fun$/) {
        $self->add_to_group($netgroups, "ugrad", $fqdn);
      } elsif (/^ssh\.forward$/) {
        $self->add_to_group($netgroups, "sunlab", $fqdn);
      } elsif (/^tstaff-netgroup$/) {
        $self->add_to_group($netgroups, "tstaff", $fqdn);
      } elsif (/^thermo$/) {
        $self->add_to_group($netgroups, "thermo", $fqdn);
      } elsif (/^liebert$/) {
        $self->add_to_group($netgroups, "liebert", $fqdn);
      } elsif (/^server$/) {
        $self->add_to_group($netgroups, "server", $fqdn);
      } elsif (/^sge\.dedicated$/) {
        $self->add_to_group($netgroups, "sge", $fqdn);
      }
    }
  }

  while (my ($grp, $val) = each(%{$netgroups})) {
    $self->maybe_system("/tstaff/bin/ldap-netgroup -e '$val' set $grp 2>/dev/null >/dev/null");
  }

  print "done.\n";

}

sub build_dhcp {
  my $self = shift;
  my $udb = $self->udb;

  system("sudo -v");

  print "Building dhcp... ";

  my $file = '/maytag/sys0/dhcp/dhcpd.conf';
  my $PATH_TMPFILE = $TMPDIR . basename($file);
  my $vars = {filename => $file, date => get_date(), dbh => $udb->storage->dbh};
  $self->tt->process('dhcpd.conf.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  # send new config file to each server
  $self->commit_local($PATH_TMPFILE, $file);
  my @CDB_DHCP_SERVERS = qw(payday snickers);
  foreach my $host (@CDB_DHCP_SERVERS) {
    $self->commit_scp($file, "$host:/etc");
    if ( $? != 0 ) {
      warn "$0: ERROR: Failed to copy DNS files to $host\n";
    }
  }
  $self->maybe_system('sudo', 'ssh', '-x', 'dhcp', '/etc/init.d/dhcp restart');

  print "done.\n";

}

sub build_nagios {
  my $self = shift;
  my $udb = $self->udb;
  system("sudo -v");
  print "Building nagios files... ";
  $self->build_nagios_hosts;
  $self->build_nagios_services;
  $self->maybe_system('sudo', 'ssh', '-x', 'storm', '/etc/init.d/nagios3 restart');
  print "done.\n";
}

sub build_nagios_hosts {
  my $self = shift;
  my $udb = $self->udb;

  my $file = '/maytag/sys0/Linux/files/add/group.debian.server.nagios3/etc/nagios3/conf.d/hosts.cfg';
  my $PATH_TMPFILE = $TMPDIR . basename($file);
  my $vars = {filename => $file, date => get_date(), dbh => $udb->storage->dbh};
  $self->tt->process('hosts.cfg.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  # send new config file to each server
  $self->commit_local($PATH_TMPFILE, $file);
  $self->commit_scp($file, "storm:/etc/nagios3/conf.d/");
  if ( $? != 0 ) {
    warn "$0: ERROR: Failed to copy nagios files to storm\n";
  }
}

sub build_nagios_services {
  my $self = shift;
  my $udb = $self->udb;

  my $file = '/maytag/sys0/Linux/files/add/group.debian.server.nagios3/etc/nagios3/conf.d/services.cfg';
  my $PATH_TMPFILE = $TMPDIR . basename($file);
  my $vars = {filename => $file, date => get_date(), dbh => $udb->storage->dbh};
  $self->tt->process('services.cfg.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  # send new config file to each server
  $self->commit_local($PATH_TMPFILE, $file);
  $self->commit_scp($file, "storm:/etc/nagios3/conf.d/");
  if ( $? != 0 ) {
    warn "$0: ERROR: Failed to copy nagios files to storm\n";
  }
}

sub build_wpkg_hosts {
  my $self = shift;
  my $udb = $self->udb;

  system("sudo -v");

  print "Building wpkg hosts file... ";

  my $file = '/u/system/win32/WPKG/hosts/cdb.xml';
  my $PATH_TMPFILE = $TMPDIR . basename($file);

  my $vars = {
    filename => $file,
    date => get_date(),
    hosts => [],
  };

  my $host_classes = get_host_class_map($udb);

  my $hosts = $udb->resultset('Computers')->search(
    {
    },
    {
      prefetch => [
      'os_type',
      {
        'device' => 'manager',
      },
      ],
      order_by => [qw(me.device_name)],
    });


  while (my $host = $hosts->next) {

    my $os = ($host->os_type);
    next unless((defined $os) and ($os->wpkg));
    my $os_type = $os->os_type;

    # generate profile list

    my @wpkg_profiles = ();

    my $classes_ref = $host_classes->{$host->device_name};
    next unless defined $classes_ref;
    my @classes = @{$classes_ref};

    push @wpkg_profiles, $os_type;

    for (@classes) {

      if (/^desktop$/) {
        push @wpkg_profiles, "desktop";
        push @wpkg_profiles, "$os_type-dept";
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
        push @wpkg_profiles, "ugrad";
      }

      if (/^research$/) {
        push @wpkg_profiles, "research";
        push @wpkg_profiles, "$os_type-research";
      }

      if (/^server$/) {
        push @wpkg_profiles, "server";
      }

      if (/^remote$/) {
        push @wpkg_profiles, "desktop";
        push @wpkg_profiles, "remote";
        push @wpkg_profiles, "$os_type-remote";
      }

      if (/^laptop$/) {
        push @wpkg_profiles, "$os_type-laptop";
      }

      if (/^laptop.loaner$/) {
        push @wpkg_profiles, "$os_type-laptop";
        push @wpkg_profiles, "loaner-laptop";
      }

      if (/^laptop.x61$/) {
        push @wpkg_profiles, "$os_type-laptop";
        push @wpkg_profiles, "x61";
      }

      if (/^acrobat9$/) {
        push @wpkg_profiles, "acrobat9";
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

    my $first_profile = shift(@wpkg_profiles);

    my $host_var = {
      hostname => $host->device_name,
      first_profile => $first_profile,
      other_profiles => \@wpkg_profiles,
    };

    push @{$vars->{hosts}}, $host_var;
  }

  $self->tt->process('wpkg-hosts.xml.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";
  $self->commit_local($PATH_TMPFILE, $file);

  print "done.\n";

}

sub build_dns_map_forward {
  my $self = shift;
  my $udb = $self->udb;
  my ($serial_num, $domain) = @_;

  my @domain_parts = split(/\./, $domain);
  my $zone = $domain_parts[0];

  my $file = "/maytag/sys0/DNS/db.$zone";
  my $PATH_TMPFILE = $TMPDIR . basename($file);
  my $vars = {
    filename => $file,
    date => get_date(),
    dbh => $udb->storage->dbh,
    zone => $zone,
    serial_num => $serial_num,
    domain => $domain,
  };
  $self->tt->process('dns.db.forward.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  return $file;
}

sub build_dns_map_reverse {
  my $self = shift;
  my $udb = $self->udb;
  my ($serial_num, $subnet) = @_;
  my $zone = $subnet->prefix;

  my $file = "/maytag/sys0/DNS/db.$zone";
  chop($file);

  my $PATH_TMPFILE = $TMPDIR . basename($file);
  my $vars = {
    filename => $file,
    date => get_date(),
    dbh => $udb->storage->dbh,
    zone => $zone,
    serial_num => $serial_num,
    cidr => $subnet->cidr,
  };
  $self->tt->process('dns.db.reverse.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  return $file;
}

sub build_dns {
  my $self = shift;
  my $udb = $self->udb;

  system("sudo -v");

  print "Building dns... ";

  $Template::Stash::SCALAR_OPS->{fix_width} = \&fix_width;

  $Template::Stash::SCALAR_OPS->{to_dns_ptr_record} = sub {
    my ($ip) = @_;
    my $formatted_ip = join(".",reverse(split(/\./, $ip)));
    return "$formatted_ip.IN-ADDR.ARPA.";
  };

  # TODO increment the SOA line
  my ($serial_num) = $udb->storage->dbh->selectrow_array("select nextval('dns_serial_num_seq')");

  my $subnets = $udb->resultset("NetVlans")->search(
    {
      'zone.zone_manager' => 'tstaff',
    },
    {
      join => 'zone',
    }
  );

  my @spread_subnets = ();

  while (my $subnet = $subnets->next) {
    push @spread_subnets, (new NetAddr::IP($subnet->network));
  }

  my $classC = Coalesce(24, 1, @spread_subnets);
  my $classB = Coalesce(16, 1, grep {$_->masklen < 24} @spread_subnets);
  my @subnets = uniq( @{$classC}, @{$classB} );

  my @files = ();

  foreach my $subnet (@subnets) {
    my $file = $self->build_dns_map_reverse($serial_num, $subnet);
    push @files, $file;
  }

  my @domains = qw(cs.brown.edu ilab.cs.brown.edu);
  foreach my $domain (@domains) {
    my $file = $self->build_dns_map_forward($serial_num, $domain);
    push @files, $file;
  }

  # fix permissions
  foreach my $file (@files) {
    $self->commit_local($TMPDIR . basename($file), $file);
    if ($self->verbose) {
      print "DEBUG: fix permissions\n";
    }
    if (not $self->dryrun) {
      # fix permissions the file
      my $group = (getgrnam('sys'))[2];
      maybe_system("sudo chown 0:$group $file") || warn "$0: WARNING: Failed to chown $file: $!\n";
      maybe_system("sudo chmod 0444 $file") || warn "$0: WARNING: Failed to chmod $file: $!\n";
    }
  }

  # send new config file to each server
  my @dns_servers = qw(payday snickers);
  foreach my $host (@dns_servers) {
    #Be careful, note @files != $file
    $self->commit_scp(@files, "$host:/var/cache/bind");
    if ( $? != 0 ) {
      warn "$0: ERROR: Failed to copy DNS files to $host\n";
    }

    $self->maybe_system('sudo', 'ssh', '-x', $host, '/usr/sbin/rndc reload');
    if ( $? != 0 ) {
        warn "$0: ERROR: Failed to send DNS reload command to on $host\n";
    }
  }

  print "done.\n";

}

sub build_finger_data {
  my $self = shift;
  my $udb = $self->udb;

  system("sudo -v");

  print "Building finger data... ";
  #DANGER Looks like no other file called "data" is created...
  my $file = '/u/system/sysadmin/data';
  my $PATH_TMPFILE = $TMPDIR . basename($file);
  my $vars = {filename => $file, date => get_date(), dbh => $udb->storage->dbh};
  $self->tt->process('finger_data.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";
  $self->commit_local($PATH_TMPFILE, $file);
  print "done.\n";
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

