# $Id$

import sys
import os
import os.path
import errno
import stat
import shutil
import globals

class SshError(Exception):
    pass

def verbose(level, st):
    if level <= globals.verbose:
        sys.stdout.write(st)
        sys.stdout.flush()

def unique(l):
    map = {}
    for item in l:
        map[item] = 1
    l = map.keys()
    l.sort()
    return l

def break_lines(st, max = 72):
    lines = []
    while 1:
        if len(st) < max:
            lines.append(st)
            return lines
        space = st.rfind(' ', 0, max)
        if space == -1:
            lines.append(st)
            return lines
        lines.append("%s\\\n" % st[0:space+1])
        st = st[space+1:]

def deleteHierarchy(path):
    if os.path.isdir(path):
        shutil.rmtree(path)
    else:
        os.unlink(path)

def scp(src, dst):
    command = [ 'scp' ]
    if globals.verbose > 1:
        command.append('-p')
    else:
        command.append('-qp')
    if isinstance(src, list):
        command.extend(src)
    else:
        command.append(src)
    command.append(dst)
    verbose(2, '\n' + ' '.join(command) + '\n')
    return os.spawnvp(os.P_WAIT, 'scp', command)

def isRemote(filename):
    colon = filename.find(':')
    if colon == -1:
        return 0
    slash = filename.find('/')
    if slash == -1:
        return 1
    if slash < colon:
        return 0
    return 1;

def copyFile(src, dst):
    if os.path.islink(src):
        make_link(os.readlink(src), dst)
    else:
        shutil.copy2(src, dst)

def moveFile(src, dst):
    if isRemote(dst):
        status = scp(src, dst)
        if status == 0:
            os.unlink(src)
        else:
            raise SshError
    else:
        try:
            os.rename(src, dst)
        except OSError, e:
            if e.errno != errno.EXDEV:
                raise e
            else:
                copyFile(src, dst)
                os.unlink(src)

def make_link(src, dst):
    try:
        rm(dst)
    except OSError, e:
        warn("Can't remove existing file %s" % dst, e)
        return

    try:
        os.symlink(src, dst)
    except OSError, e:
        warn("Can't create symlink", e)
        sys.stderr.write("  %s -> %s\n" % (src, dst))
        
def rm(path):
    try:
        os.unlink(path)
    except OSError, e:
        if e.errno != errno.ENOENT:
            raise e

def warn(st, err = None):
    if err:
        sys.stderr.write("%s: %s: %s\n" % ( globals.prog, st, err.strerror ))
    else:
        sys.stderr.write("%s: %s\n" % (globals.prog, st))

def die(*args):
    warn(*args)
    sys.exit(1)
    #sys.exit("%s: %s" % (globals.prog, st))
