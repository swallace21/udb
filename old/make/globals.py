# $Id$

#
# Directory to use for tmp.  Shouldn't use /tmp since it's not really secure
#
temp_dir = '/tmp'

#
# Directory containing the static portion of the build files that will
# be included in the result
#
include_dir = '/tstaff/include/cdb'

#
# Netgroups that will have hosts included in /etc/hosts.equiv file
#
netgroups_hosts_equiv = [ 'linux', 'sun', 'server', 'servers' ]

#
# Netgroups that should have entries in bootparams NIS map
#
netgroups_bootparams = [ 'sun' ]

#
# NIS domain name
#
nis_domain = 'cs'

#
# Program that should be run for ypmake
#
ypmake = '/u/system/bin/ypmake'

#
# Directory in which to build tftpboot links
#
tftp_dir = '/maytag/sys0/tftpboot'

#
# The FAI config file to use if there isn't an entry in the data base
#  (This is only used for hosts in the 'linux' group)
#
default_fai_config = 'fai-default'

#
# DNS Server
#
dns_server = 'ns.cs.brown.edu'

#
# Subnets for which to build DNS maps
#   TODO: We aren't currently building a reverse map for subnet 34.  This
#         is an oversight and needs to be fixed.
#
dns_subnets = [ 31, 32, 34, 33, 37, 38 ]

###########################################################################

#
# Set via a command line option.  If set, don't install files, just build them.
#
build_only = 0

#
# Set to 1 for debug mode
#
debug = 2

#
# cdbmake version number
#
version = '0.0'

#
# program name of currently running program
#
prog = ''

#
# Verbosity level
#
verbose = 2
