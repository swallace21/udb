package BrownCS::udb::Build;
use Moose;

use Template;
use Template::Stash;
use FindBin qw($RealBin);
use BrownCS::udb::Util qw(:all);
use NetAddr::IP qw(Coalesce);
use List::MoreUtils qw(uniq);
use File::Temp qw(tempfile tempdir);
use File::Basename;
use File::Copy;

has 'udb' => ( is => 'ro', isa => 'BrownCS::udb::Schema', required => 1 );
has 'verbose' => ( is => 'ro', isa => 'Bool', required => 1 );
has 'dryrun' => ( is => 'ro', isa => 'Bool', required => 1 );
has 'tt' => ( is => 'ro', isa => 'Template', required => 0 );
has 'TMPDIR' => (is => 'rw', isa => 'Str', required => 0 );

sub BUILD {
  my $self = shift;
  $self->{tt} = Template->new({INCLUDE_PATH => "$RealBin/../templates"}) || die "$Template::ERROR\n";
  $self->{TMPDIR} = File::Temp::tempdir("/tmp/udb-build.XXXX") . "/";
}

sub build_lock {
  my $self = shift;

  my $udb = $self->udb;
  my $build_lock = $udb->resultset('State')->find('build_lock');

  if ($build_lock->value != 0) {
    print "ERROR: another build is in progress, please try again later\n";
    exit 1;
  }

  $build_lock->value(1);
  $build_lock->update;
}

sub build_unlock {
  my $self = shift;

  my $udb = $self->udb;
  my $build_lock = $udb->resultset('State')->find('build_lock');

  $build_lock->value(0);
  $build_lock->update;
}

sub add_build_ref {
  my $self = shift;
  my ($buildref, $table) = @_;

  if ($self->verbose) { print "Adding build reference for \"$table\" table.\n"; }
  if ($buildref->{$table}) {
    $buildref->{$table}++;
  } else {
    $buildref->{$table} = 1;
  }
}

sub del_build_ref {
  my $self = shift;
  my ($buildref, $table) = @_;
  
  if ($buildref->{$table} && $buildref->{$table} > 0) {
    if ($self->verbose) { print "Deleting build reference for \"$table\" table.\n"; }
    $buildref->{$table}--;
  } else {
    print "\n  WARNING: buildref for table \"$table\" was already zero";
  }
}

sub update_build_times {
  my $self = shift;
  my ($build_time, $buildref) = @_;

  my $udb = $self->udb;

  foreach my $table (keys %$buildref) {
    if ($buildref->{$table} == 0) {
      my $table = $udb->resultset('BuildLog')->find($table);
      $table->last_build($build_time);
      $table->update;
    }
  } 
}

sub get_keytab {
  my $self = shift;
  my ($krbadmin, $keytab) = @_;

  if (! -x '/usr/sbin/kadmin') {
    print "ERROR: can't execute /usr/sbin/kadmin\n";
    exit 1;
  }

  system("/usr/sbin/kadmin -q \"ktadd -q -k $keytab $krbadmin\" 2> /dev/null");
  print "\n";

  if (! -e $keytab) {
    print "ERROR: unable to extract keytab file, did you enter your correct password?\n";
    exit 1;
  }
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

sub commit_chmod {
  my $self = shift;
  my $udb = $self->udb;
  my $dst = $_[-1];
  if ($self->verbose) {
    print "Running chmod $dst\n";
  }
  if (not $self->dryrun) {
    # The following line works. Think about it. 
    if (!system("ksu -e /usr/bin/sudo /bin/chmod @_ >/dev/null 2>&1") == 0){
      die "$0: ERROR: Failed committing $dst: $!\n" ;
    }
  }
}

sub commit_chown {
  my $self = shift;
  my $udb = $self->udb;
  my $dst = $_[-1];
  if ($self->verbose) {
    print "Running chown $dst\n";
  }
  if (not $self->dryrun) {
    # The following line works. Think about it. 
    if (!system("ksu -e /usr/bin/sudo /bin/chown @_ >/dev/null 2>&1") == 0){
      die "$0: ERROR: Failed committing $dst: $!\n" ;
    }
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
    if (!system("ksu -e /usr/bin/sudo /bin/cp @_ >/dev/null 2>&1") == 0){
      die "$0: ERROR: Failed committing $dst: $!\n" ;
    }
  }
}

sub commit_ln {
  my $self = shift;
  my $udb = $self->udb;
  my $dst = $_[-1];
  if ($self->verbose) {
    print "Linking $dst\n";
  }
  if (not $self->dryrun) {
    # The following line works. Think about it. 
    if (!system("ksu -e /usr/bin/sudo /bin/ln -s @_ >/dev/null 2>&1") == 0){
      die "$0: ERROR: Failed committing $dst: $!\n" ;
    }
  }
}

sub commit_rm {
  my $self = shift;
  my $udb = $self->udb;
  my $dst = $_[-1];
  if ($self->verbose) {
    print "Removing $dst\n";
  }
  if (not $self->dryrun) {
    # The following line works. Think about it. 
    if (!system("ksu -e /usr/bin/sudo /bin/rm -f @_ >/dev/null 2>&1") == 0){
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
    if (!system("ksu -e /usr/bin/sudo /usr/bin/scp -pq @_ >/dev/null 2>&1") == 0){
      die "$0: ERROR: Failed committing $dst: $!\n" ;
    }
  }
}

sub commit_ssh {
  my $self = shift;
  my $udb = $self->udb;
  my $dst = $_[-1];

  if ($self->verbose) {
    print "Committing $dst via ssh\n";
  }
  if (not $self->dryrun) {
    # The following line works. Think about it. 
    if (!system("ksu -e /usr/bin/sudo /usr/bin/ssh -x @_ >/dev/null 2>&1") == 0){
      die "$0: ERROR: Failed committing $dst: $!\n" ;
    }
  }
}

sub build_tftpboot {
  my $self = shift;
  my $udb = $self->udb;
  my ($host) = @_;

  if ($host) {
    print "\n  Building tftpboot on $host... ";
  } else {
    print "Building tftpboot... ";
  }

  my $tftpboot_path = "/sysvol/tftpboot/pxelinux.cfg";

  my $addrs;
  if ($host) {
    $addrs = $udb->resultset('NetAddresses')->search(
      { 'dns_name' => $host },
      { join => 'net_dns_entries' }
    );
  } else {
    $addrs = $udb->resultset('NetAddresses')->search({},
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
  }

  my $host_classes = get_host_class_map($udb);

  while (my $addr = $addrs->next) {
    my $iface = $addr->primary_interface;
    next if not defined $iface;

    my $comp = $iface->device->computer;
    next if not defined $comp;

    my $os = ($comp->os_type);
    next if not defined $os;

    my $bootimage;

    if ($comp->pxelink) {
      $bootimage = $comp->pxelink;
    } elsif ($os->os_type eq 'debian') {
      $bootimage = "fai-workstation-i386";
    } elsif ($os->os_type eq 'debian64') {
      $bootimage = "fai-workstation-amd64";
    } elsif ($os->os_type eq 'centos') {
      $bootimage = "centos-workstation-i386";
    } elsif ($os->os_type eq 'centos64') {
      $bootimage = "centos-workstation-x86_64";
    } elsif ($os->os_type eq 'windows7') {
      $bootimage = "fai-windows";
    } elsif ($os->os_type eq 'windows764') {
      $bootimage = "fai-windows";
    } elsif ($os->os_type eq 'server2008') {
      $bootimage = "fai-windows";
    } elsif ($os->os_type eq 'server200864') {
      $bootimage = "fai-windows";
    }
    
    next if not defined($bootimage);

    if (grep /^server$/, @{$host_classes->{$comp->device_name}}) {
      $bootimage =~ s/workstation/server/g;
    }

    # determine whether this will use an internal or DMZS install server
    my $install_server = $udb->resultset('NetVlans')->find($addr->vlan_num)->install_server;
    if ($install_server) {
      $bootimage .= ".$install_server";
    }

    next if not defined $addr->ipaddr;
    my $hex_ip = ipv4_n2x($addr->ipaddr);

    if ($self->verbose) {
      printf "\nlink %s (%s) -> %s\n", $comp->device_name, $hex_ip, $bootimage;
    }
    if (not $self->dryrun) {
      if (-e "$tftpboot_path/$bootimage") {
        $self->commit_rm("$tftpboot_path/$hex_ip");
        $self->commit_ln("$bootimage $tftpboot_path/$hex_ip");
      } else {
        print "\n  WARNING: bootimage $bootimage doesn't existing, not touching link for " . $comp->device_name;
      }
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

  if(not $self->dryrun) { BrownCS::udb::Util::okay_kerberos; }

  print "Building netgroups... ";

  my $hosts = $udb->resultset('Computers')->search({
    -and => [
      'net_dns_entries.authoritative' => 1,
      -or => [
        'net_dns_entries.dns_region' => 'internal',
        'net_dns_entries.dns_region' => 'all',
      ],
    ]},
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

    if (trusted_nfs($host)) {
      $self->add_to_group($netgroups, "trusted", $fqdn);
    }

    if (nfs_host_install($host)) {
      $self->add_to_group($netgroups, "install", $fqdn);
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
      } elsif (/^'-e', ssh\.forward$/) {
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

  print "Building dhcp... ";

  my $file = '/sysvol/dhcp/dhcpd.conf';
  my $PATH_TMPFILE = $self->TMPDIR . basename($file);
  my $vars = {filename => $file, date => get_date(), dbh => $udb->storage->dbh};
  $self->tt->process('dhcpd.conf.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  $self->commit_local($PATH_TMPFILE, $file);

  # send new config file to each server
  my $class_rs = $udb->resultset('CompClasses')->search({
    name => 'dhcp.server',
  });

  my @dhcp_servers = ();
  while (my $class = $class_rs->next) {
    @dhcp_servers = (@dhcp_servers, $class->computers->get_column("me.device_name")->all);
  }
  foreach my $host (@dhcp_servers) {
    $self->commit_scp($file, "$host.cs.brown.edu:/etc/dhcp3");
    if ($? != 0) {
      warn "$0: ERROR: Failed to copy DHCP files to $host\n";
    }
  }

  # end of old server cruft

  $self->commit_ssh('dhcp.cs.brown.edu','/etc/init.d/dhcp3-server restart');
  if ( (not $self->dryrun) && $? != 0 ) {
    warn "$0: ERROR: Failed to restart dhcp server\n";
  }

  print "done.\n";

}

sub build_nagios {
  my $self = shift;
  my $udb = $self->udb;

  print "Building nagios files... ";
  $self->build_nagios_hosts;
  $self->build_nagios_hostgroups;
  $self->build_nagios_services;
  $self->commit_ssh('storm.cs.brown.edu','/etc/init.d/nagios3 restart');
  if ( (not $self->dryrun) && $? != 0 ) {
    warn "$0: ERROR: Failed to restart nagios server\n";
  }
  print "done.\n";
}

sub build_nagios_hosts {
  my $self = shift;
  my $udb = $self->udb;

  my $file = '/sysvol/nagios/hosts.cfg';
  my $PATH_TMPFILE = $self->TMPDIR . basename($file);
  my $vars = {filename => $file, date => get_date(), dbh => $udb->storage->dbh};
  $self->tt->process('hosts.cfg.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  # send new config file to each server
  $self->commit_local($PATH_TMPFILE, $file);
  $self->commit_scp($file, "storm.cs.brown.edu:/etc/nagios3/conf.d/");
  if ( (not $self->dryrun) && $? != 0 ) {
    warn "$0: ERROR: Failed to copy nagios files to storm\n";
  }
}

sub build_nagios_hostgroups {
  my $self = shift;
  my $udb = $self->udb;

  my $file = '/sysvol/nagios/hostgroups.cfg';
  my $PATH_TMPFILE = $self->TMPDIR . basename($file);
  my $vars = {filename => $file, date => get_date(), dbh => $udb->storage->dbh};
  $self->tt->process('hostgroups.cfg.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  # send new config file to each server
  $self->commit_local($PATH_TMPFILE, $file);
  $self->commit_scp($file, "storm.cs.brown.edu:/etc/nagios3/conf.d/");
  if ( (not $self->dryrun) && $? != 0 ) {
    warn "$0: ERROR: Failed to copy nagios files to storm\n";
  }
}

sub build_nagios_services {
  my $self = shift;
  my $udb = $self->udb;

  my $file = '/sysvol/nagios/services.cfg';
  my $PATH_TMPFILE = $self->TMPDIR . basename($file);
  my $vars = {filename => $PATH_TMPFILE, date => get_date(), dbh => $udb->storage->dbh};
  $self->tt->process('services.cfg.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  # send new config file to each server
  $self->commit_local($PATH_TMPFILE, $file);
  $self->commit_scp($file, "storm.cs.brown.edu:/etc/nagios3/conf.d/");
  if ( (not $self->dryrun) && $? != 0 ) {
    warn "$0: ERROR: Failed to copy nagios files to storm\n";
  }
}

sub build_wpkg_hosts {
  my $self = shift;
  my $udb = $self->udb;

  print "Building wpkg hosts file... ";

  my $file = '/sysvol/wpkg/hosts/cdb.xml';
  my $PATH_TMPFILE = $self->TMPDIR . basename($file);

  my $vars = {
    filename => $file,
    date => get_date(),
    hosts => [],
  };

  my $host_classes = get_host_class_map($udb);

  my $hosts = $udb->resultset('Computers')->search( {}, {
      prefetch => [ 'os_type', { 'device' => 'manager', }, ],
      order_by => [qw(me.device_name)],
    });

  while (my $host = $hosts->next) {
    next unless((defined $host->os_type) && ($host->os_type->wpkg));
    my $os_type = $host->os_type->os_type;

    next unless((defined $host->device) && ($host->device->manager->management_type =~ /^tstaff$/));

    # generate profile list
    my @wpkg_profiles = ();

    # all hosts get an os_type profile definition
    push @wpkg_profiles, $os_type;

    # all machines get a core profile
    push @wpkg_profiles, "$os_type-core";

    # determine if there are other profiles we should apply
    my $classes_ref = $host_classes->{$host->device_name};
    if (defined $classes_ref) {
      my @classes = @{$classes_ref};

      for (@classes) {
        if (/^desktop$/) {
          push @wpkg_profiles, "$os_type-desktop";
          push @wpkg_profiles, "$os_type-dept";
        }

        if (/^classroom$/) {
          push @wpkg_profiles, "$os_type-classroom";
        }

        if (/^maya$/) {
          push @wpkg_profiles, "$os_type-maya";
        }

        if (/^astaff$/) {
          push @wpkg_profiles, "$os_type-astaff";
        }

        if (/^tstaff$/) {
          push @wpkg_profiles, "$os_type-tstaff";
        }

        if (/^fun$/) {
          push @wpkg_profiles, "$os_type-ugrad";
        }

        if (/^research$/) {
          push @wpkg_profiles, "$os_type-research";
        }

        if (/^server$/) {
          push @wpkg_profiles, "server";
        }

        if (/^remote$/) {
          push @wpkg_profiles, "$os_type-desktop";
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
          push @wpkg_profiles, "$os_type-acrobat9";
        }

	if (/^office2010$/) {
          push @wpkg_profiles, "$os_type-office2010";
        }

	if (/^testsoft$/) {
          push @wpkg_profiles, "$os_type-testsoft";
        }

	if (/^vs2010u$/) {
          push @wpkg_profiles, "$os_type-vs2010u";
        }

        # licensed software
  
        if (/^adobe-ae-pp$/) {
          push @wpkg_profiles, "$os_type-adobe-ae-pp";
        }

        if (/^framemaker$/) {
          push @wpkg_profiles, "$os_type-framemaker";
        }

        if (/^powerdvd$/) {
          push @wpkg_profiles, "$os_type-powerdvd";
        }
	
	if (/^filemaker$/) {
          push @wpkg_profiles, "$os_type-filemaker";
        }

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
  chmod 0664, $file;

  # copy the file over to the old location
  copy($file, "/u/system/win32/WPKG/hosts/cdb.xml") || die "ERROR: could't copy cdb.xml: $!\n";
  chmod 0664, "/u/system/win32/WPKG/hosts/cdb.xml";

  print "done.\n";

}

sub build_dns_map_forward {
  my $self = shift;
  my $udb = $self->udb;
  my ($serial_num, $region, $domain) = @_;

  my @domain_parts = split(/\./, $domain);
  my $zone = $domain_parts[0];

  my $file = "/sysvol/dns/db.$zone.$region";
  my $PATH_TMPFILE = $self->TMPDIR . basename($file);
  my $vars = {
    filename => $file,
    date => get_date(),
    dbh => $udb->storage->dbh,
    zone => $zone,
    serial_num => $serial_num,
    domain => $domain,
  };

  $self->tt->process("dns.db.forward.$region.tt2", $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  return $file;
}

sub build_dns_map_reverse {
  my $self = shift;
  my $udb = $self->udb;
  my ($serial_num, $region, $subnet) = @_;
  my $zone = $subnet->prefix;

  $zone =~ s/\.$//;

  my $file = "/sysvol/dns/db.$zone.$region";
  chomp($file);

  my $PATH_TMPFILE = $self->TMPDIR . basename($file);
  my $vars = {
    filename => $file,
    date => get_date(),
    dbh => $udb->storage->dbh,
    zone => $zone,
    serial_num => $serial_num,
    cidr => $subnet->cidr,
  };

  $self->tt->process("dns.db.reverse.$region.tt2", $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";

  return $file;
}

sub build_dns {
  my $self = shift;
  my $udb = $self->udb;

  print "Building dns... ";

  $Template::Stash::SCALAR_OPS->{fix_width} = \&fix_width;

  $Template::Stash::SCALAR_OPS->{to_dns_ptr_record} = sub {
    my ($ip) = @_;
    my $formatted_ip = join(".",reverse(split(/\./, $ip)));
    return "$formatted_ip.IN-ADDR.ARPA.";
  };

  # TODO increment the SOA line
  my ($serial_num) = $udb->storage->dbh->selectrow_array("select nextval('dns_serial_num_seq')");

  my $subnets_rs = $udb->resultset("NetVlans")->search(
    {
      'zone.zone_manager' => 'tstaff',
    },
    {
      join => 'zone',
    }
  );

  my @all_subnets = ();

  # bind doesn't play well with anything that isn't a "FULL" subnet, i.e. class A, B, or C subnet.
  # as such, we need to play some games with our subnets here, to make sure they come out as 
  # intended and bind will serve them properly.
  while (my $subnet = $subnets_rs->next) {
    push @all_subnets, (new NetAddr::IP($subnet->network));
  }

  my $classC = Coalesce(24, 1, grep {$_->masklen >= 24} @all_subnets);
  my $classB = Coalesce(16, 1, grep {$_->masklen < 24} @all_subnets);
  my @subnets = uniq( @{$classC}, @{$classB} );

  my @files = ();

  # Build reverse maps, split the data based in internal and external regions
  # subnets.
  my @regions = qw(internal external);
  foreach my $region (@regions) {
    foreach my $subnet (@subnets) {
      my $file = $self->build_dns_map_reverse($serial_num, $region, $subnet);
      push @files, $file;
    }
  }

  # Build forward maps.  Once the ilab.cs.brown.edu domain is no longer, then
  # remove the foreach loop and next statement below.
  my @domains = qw(cs.brown.edu ilab.cs.brown.edu);
  foreach my $region (@regions) {
    foreach my $domain (@domains) {
      next if ($region =~ /external/ && $domain =~/ilab.cs.brown.edu/);
      my $file = $self->build_dns_map_forward($serial_num, $region, $domain);
      push @files, $file;
    }
  }

  # fix permissions
  foreach my $file (@files) {
    $self->commit_local($self->TMPDIR . basename($file), $file);
    if ($self->verbose) {
      print "DEBUG: fix permissions\n";
    }
    if ((not $self->dryrun)) {
      # fix permissions the file
      my $group = (getgrnam('sys'))[2];
      $self->commit_chown("0:$group $file");
      $self->commit_chmod("0444 $file");
    }
  }

  # send new config file to each server
  my %dns_servers = (
    internal => [ 'firebird','oracle' ],
    external => [ 'salt','pepper' ],
  );

  foreach my $region (@regions) {
    foreach my $host (@{$dns_servers{$region}}) {
      my @tosend = grep(/$region/,@files);
      #Be careful, note @tosend != $tosend
      $self->commit_scp(@tosend, "$host.cs.brown.edu:/var/cache/bind");
      if ( (not $self->dryrun) && $? != 0 ) {
        warn "$0: ERROR: Failed to copy DNS files to $host\n";
      }
  
      $self->commit_ssh("$host.cs.brown.edu",'/usr/sbin/rndc reload');
      if ( (not $self->dryrun) && $? != 0 ) {
        warn "$0: ERROR: Failed to send DNS reload command on $host\n";
      }
    }
  } 

  print "done.\n";

}

sub build_finger_data {
  my $self = shift;
  my $udb = $self->udb;

  print "Building finger data... ";
  #DANGER Looks like no other file called "data" is created...
  my $file = '/u/system/sysadmin/data';
  my $PATH_TMPFILE = $self->TMPDIR . basename($file);
  my $vars = {filename => $file, date => get_date(), dbh => $udb->storage->dbh};
  $self->tt->process('finger_data.tt2', $vars, $PATH_TMPFILE) || die $self->tt->error(), "\n";
  $self->commit_local($PATH_TMPFILE, $file);
  print "done.\n";
}

sub staged_additions {
  my $self = shift;
  my ($krbadmin, $keytab, $buildref) = @_;

  my $udb = $self->udb;
  my $ret;

  if(not $self->dryrun) { BrownCS::udb::Util::okay_kerberos; }

  print "Building staged additions... ";

  # get list of devices that have been changed since last build
  my $device_log = $udb->resultset('BuildLog')->find('devices');
  unless ($device_log) { die "ERROR: can't find build log for devices table\n" };
  
  my $timestamp = $device_log->last_build;

  # select hosts that need ldap entries
  my $devices_rs = $udb->resultset('Devices')->search({
    'last_updated' => { '>=' => $timestamp },
  });

  while (my $device = $devices_rs->next) {
    # stage any additions that won't be caught by staged_modifications
  }

  print "done.\n";
}

sub staged_deletions {
  my $self = shift;
  my ($krbadmin, $keytab, $buildref) = @_;

  my $udb = $self->udb;
  my $ret;

  if(not $self->dryrun) { BrownCS::udb::Util::okay_kerberos; }

  print "Building staged deletions... ";

  # select devices for which we need to delete ldap entries
  my $devices_rs = $udb->resultset('Devices')->search({
    'status' => 'deleted',
  });

  while (my $device = $devices_rs->next) {
    log("staging delete of $device->device_name");
    if ($device->computer) {
      $self->add_build_ref($buildref, 'computers');
      log("  deleting ldap entry");
      $ret = delete_ldap_host($self, $device->device_name);
      if ($ret) {
        next;
      } else {
        $self->del_build_ref($buildref, 'computers');
      }
    }

    $self->add_build_ref($buildref, 'devices');
    log("  deleting kerberos credentials");
    $ret = delete_kerberos_host($self, $krbadmin, $keytab, $device->device_name);
    if ($ret) {
      next;
    } else {
      $self->del_build_ref($buildref, 'devices');
    }

    $device->delete;
  }

  print "done.\n";
}

sub staged_modifications {
  my $self = shift;
  my ($krbadmin, $keytab, $buildref) = @_;

  my $udb = $self->udb;
  my $ret;
  my $timestamp;

  if(not $self->dryrun) { BrownCS::udb::Util::okay_kerberos; }

  print "Building staged modifications... ";

  # get list of devices that have changed since last build log
  my $device_log = $udb->resultset('BuildLog')->find('devices');
  unless ($device_log) { die "ERROR: can't find build log for computers table\n" };

  $timestamp = $device_log->last_build;

  my $devices_rs = $udb->resultset('Devices')->search({
    'last_updated' => { '>=', $timestamp },
  });

  while (my $device = $devices_rs->next) {
    my $name = $device->device_name;
    log("staging modifications of device $name");

    if ($device->computer && host_is_trusted($device->computer)) {
      $self->add_build_ref($buildref, 'devices');
      log("  adding/checking kerberos host credentials");
      $ret = add_kerberos_host($self, $krbadmin, $keytab, $device->device_name);
      if (! $ret) {
        $self->del_build_ref($buildref, 'devices');
      }
    } else {
      $self->add_build_ref($buildref, 'devices');
      log ("  deleting kerberos credentials");
      $ret = delete_kerberos_host($self, $krbadmin, $keytab, $device->device_name);
      if (! $ret) {
        $self->del_build_ref($buildref, 'devices');
      }
    }
  }

  # get list of computers that have changed since last build
  my $computer_log = $udb->resultset('BuildLog')->find('computers');
  unless ($computer_log) { die "ERROR: can't find build log for computers table\n" };

  $timestamp = $computer_log->last_build;

  my $computers_rs = $udb->resultset('Computers')->search({
    'last_updated' => { '>=', $timestamp },
  });

  # get a resultset for the various samba classes
  my $samba_class_rs = $udb->resultset('CompClasses')->search({
    -or => [
      name => { '~*' => 'samba'},
      name => { '~*' => 'gpfs.server.fs'},
      name => { '~*' => 'gpfs.server.cifs'},
    ],
  });

  while (my $computer = $computers_rs->next) {
    my $name = $computer->device_name;
    log("staging modifications of computer $name");

    # manage any LDAP host changes
    my $samba_server = 0;
# temporary hack to ensure GPFS servers aren't removed from ldap, while I try to figure out what's causing them to be removed
if ($name =~ /dewey/ || $name =~ /louie/ || $name =~ /peeps/ || $name =~ /andes/ || $name =~ /runts/ || $name =~ /nerds/ || $name =~ /stride/ || $name =~ /orbit/) {
  $samba_server = 1;
}
# this search is busted
    while (my $samba_class = $samba_class_rs->next) {
      if ($samba_class->computers()->find($computer->device_name)) {
        $samba_server = 1;
      }
    }

    if (host_is_trusted($computer) && (
        ($computer->os_type && $computer->os_type->os_type =~ /^win/) || 
        $samba_server)) {
      $self->add_build_ref($buildref, 'computers');
      log ("  adding/checking ldap host entry");
      $ret = add_ldap_host($self, $computer->device_name);
      if (! $ret) {
        $self->del_build_ref($buildref, 'computers');
      }
    } else {
      $self->add_build_ref($buildref, 'computers');
      log ("  deleting ldap host entry");
      $ret = delete_ldap_host($self, $computer->device_name);
      if (! $ret) {
        $self->del_build_ref($buildref, 'computers');
      }
    }

    # build any required PXE links
    build_tftpboot($self, $name);
  }

  print "done.\n";
}

sub add_kerberos_host {
  my ($self, $krbadmin, $keytab, $name) = @_;

  if ($self->verbose) { print "adding host \"$name\" to Kerberos\n"; }
  my $ret = $self->maybe_system("/tstaff/bin/krb-host-admin -c $krbadmin -k $keytab add $name.cs.brown.edu > /dev/null");
  
  return $ret;
}

sub delete_kerberos_host {
  my ($self, $krbadmin, $keytab, $name) = @_;

  if ($self->verbose) { print "deleting host \"$name\" from Kerberos\n"; }
  my $ret = $self->maybe_system("/tstaff/bin/krb-host-admin -c $krbadmin -k $keytab delete $name.cs.brown.edu > /dev/null");
  
  return $ret;
}

sub add_ldap_host {
  my ($self, $name) = @_;

  if ($self->verbose) { print "adding host \"$name\" to LDAP\n"; }
  my $ret = $self->maybe_system("/tstaff/bin/ldap-host add $name 2>/dev/null >/dev/null");

  if ($ret) {
    print "\n  WARNING: unable to add \"$name\" to ldap\n";
  }

  return $ret; 
}

sub delete_ldap_host {
  my ($self, $name) = @_;

  if ($self->verbose) { print "deleting host \"$name\" from LDAP\n"; }
  my $ret = $self->maybe_system("/tstaff/bin/ldap-host delete $name 2>/dev/null >/dev/null");

  if ($ret) {
    print "\n  WARNING: unable to delete \"$name\" from ldap\n";
  }

  return $ret;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

