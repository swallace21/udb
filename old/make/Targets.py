# $Id$

import os
import Utils
import globals
import TargetFile

targets = { 'bootparams': TargetFile.BootParams,
            'dhcp': TargetFile.DHCP,
            'dns': TargetFile.DNS,
            'ethers': TargetFile.Ethers,
            'hosts': TargetFile.Hosts,
            'hosts.equiv': TargetFile.HostsEquiv,
            'netgroup': TargetFile.Netgroup,
            'tftpboot': TargetFile.Tftpboot }

def getAllTargets():
    keys = targets.keys()
    keys.sort()
    return keys

def getClassForTarget(db, target):
    targetClass = targets.get(target, None)
    if not targetClass:
        return None
    return targetClass(db)

def makeBuildDir():
    pid = os.getpid()
    TargetFile.Target.setBuildDir('%s/%d' % ( globals.temp_dir, pid ))
    os.mkdir(TargetFile.Target.getBuildDir())

def removeBuildDir():
    if globals.debug < 2:
        Utils.verbose(1, "Removing build directory: %s\n" %
                      TargetFile.Target.getBuildDir())
        Utils.deleteHierarchy(TargetFile.Target.getBuildDir())
    else:
        Utils.verbose(1, "Not removing build directory: %s\n" %
                      TargetFile.Target.getBuildDir())
