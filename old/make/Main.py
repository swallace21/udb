#!/usr/bin/python

# $Id$

import sys
import os
import getopt
import time
import globals
import Utils
import DB
import Targets

map_depends = {
    'hostname': ['hosts', 'hosts.equiv', 'ethers', 'netgroup', 'dns',
                 'bootparams', 'tftpboot', 'dhcp'],
    'aliases': [ 'hosts', 'dns' ],
    'ipaddr': [ 'hosts', 'dns', 'bootparams', 'tftpboot' ],
    'ethernet': [ 'ethers', 'dhcp' ],
    'os_type': [ 'bootparams', 'tftpboot' ],
    'arch': [ 'bootparams', 'tftpboot' ],
    'netgroup': [ 'netgroup', 'bootparams', 'tftpboot' ],
    'supp_groups': [ 'netgroup' ],
    'mxhost': [ 'dns' ],
    'jspaths': [ 'tftpboot', 'bootparams']
    }
    
def build(db, map):
    Utils.verbose(1, "%s\n" % map)
    Utils.verbose(1, '  Building...')

    target = Targets.getClassForTarget(db, map)
    if not target:
        Utils.verbose(1, "WARNING: unknown target file: %s\n" % (map))
        return

    start_time = time.time()
    target.build()
    stop_time = time.time()
    Utils.verbose(1, 'done. (%f secs)\n' % (stop_time - start_time) )
    install(db, map)

def install(db, map):
    if globals.build_only:
        return
    
    Utils.verbose(1, '  Installing...')
    target = Targets.getClassForTarget(db, map)
    if not target:
        Utils.verbose(1, "WARNING: unknown target file: %s\n" % (map))
        return
    start_time = time.time()
    target.install()
    stop_time = time.time()
    Utils.verbose(1, 'done. (%f secs)\n' % (stop_time - start_time) )

def getOutOfDateTargets(db):
    dirty_tables = db.getDirtyTables()
    targets = []
    for t in dirty_tables:
        targets.extend(map_depends[t])
    return Utils.unique(targets)

def ypmake():
    Utils.verbose(1, "Rebuild NIS maps...")
    start_time = time.time()
    if globals.debug:
        os.spawnlp(os.P_WAIT, 'echo', 'echo', '-n', globals.ypmake, ' ')
    else:
        os.spawnlp(os.P_WAIT, 'ypmake', globals.ypmake)
    stop_time = time.time()
    Utils.verbose(1, 'done. (%f secs)\n' % (stop_time - start_time) )

def getTargetsToBuild(db, args):
    targets = Targets.getAllTargets()
    to_build = []
    for a in args:
        if a.lower() == 'all':
            to_build = targets
            break
        elif a.lower() in targets:
            to_build.append(a.lower())
        else:
            usage()
            sys.exit(1)
    if not to_build:
        return getOutOfDateTargets(db)
    return to_build

def main(args):
    args = processCommandOptions(args)

    if not globals.debug and os.getuid() != 0:
        Utils.die("Must be root to run.")
        
    db = DB.DB()

    to_build = getTargetsToBuild(db, args)

    if to_build:
        os.umask(022)
        Targets.makeBuildDir()
        ypChanged = 0
        for target in to_build:
            build(db, target)
            if target in ['hosts', 'ethers', 'netgroup', 'bootparams' ]:
                ypChanged = 1
        if not globals.build_only:
            Targets.removeBuildDir()
            db.clearDirty()
            if ypChanged:
                ypmake()
            db.commit()
    else:
        print 'All targets are up to date.'

    db.close()

def processCommandOptions(args):
    try:
        opts, args = getopt.getopt(args, "bd:v:")
    except getopt.GetoptError:
        usage()
        sys.exit(1)

    for o, a in opts:
        if o == "-d":
            globals.debug = int(a)
        elif o == "-v":
            globals.verbose = int(a)
        elif o == '-b':
            globals.build_only = 1
    return args
    
def usage():
    sys.stderr.write("Usage: %s [ all | [ <file>...] ]\n" % (globals.prog) )
    sys.stderr.write("\twhere file is one or more of:\n");
    sys.stderr.write("\t%s\n" % (' '.join(Targets.getAllTargets())));

