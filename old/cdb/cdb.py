#!/usr/bin/python2.1

import sys, string
from udb import *
import NetworkRecord
import EquipmentRecord

#
# Writes message to stderr, adding program name.
#
def warn(message):
    sys.stderr.write(prog + ": " + message + '\n')

#
# If "val" isn't None, write it to the standard out
#
def writeVal(val):
    if val is not None:
        sys.stdout.write(val)
    print

#
# Prompt the user for information, possibly with a default value.  If a
# default is given, a return key returns the default.  A '\' key
# returns an empty string, and any other input is just return
#
def prompt(st, default = None):
    if default:
        prompt = "%s [%s] " % (st, default)
    else:
        prompt = st
    resp = raw_input(prompt).strip()
    if not default:
        return resp

    if not resp:
        return default
    if resp == '\\':
        return ''
    return resp

#
# Given an ip address and a subnet, return the host portion
#
def gethostnum(ip, subnet):
    l = len(subnet) + 1
    return int(ip[l:])

#
# Convert a comma separated string into a list
#
def makeList(st):
    if len(st) == 0:
        return []
    l = st.split(",")
    l = map(string.strip, l)
    return l

#
# Return the first available IP address on the given subnet.  The result
# will have a host portion between 2 and 254
#
def pickIp(subnet):
    # select ipaddr from network where network(ipaddr) = '128.148.38';
    # get all the records for the given subnet
    rec = Network.getSQLWhere("network(ipaddr) = '%s' order by ipaddr"
                              % subnet)

    ips = map(lambda n: n['ipaddr'][:-3], rec)
    for i in xrange(len(ips)):
        ips[i] = gethostnum(ips[i], subnet)
    for i in xrange(2, 254):
        if i not in ips:
            return "%s.%d" % (subnet, i)
    return None

#
# If st is a substring of 'yes' (case insenstive) return 1, else 0
#
def isYes(st):
    return 'yes'[0:len(st)] == st.lower()

###########################################################################
# PROFILE - prints out network information
###########################################################################
def profile(argv):
    if len(argv) < 3:
        warn("Usage: cdb profile <hostname>")
        return
    host = argv[2]    

    netrec = NetworkRecord.fetchNetByHostname(host)
    if not netrec:
        warn('No record for "%s" found in database' % host)
        return

    print "hostname = " + netrec.getHostname()

    sys.stdout.write("prim_grp = ")
    writeVal(netrec.getNetgroup())

    sys.stdout.write("aliases = ")
    alias = netrec.getAliases()
    if alias is not None:
        st = string.join(alias, ",")
        print st

    sys.stdout.write("comment = ")
    writeVal(netrec.getComment())

    sys.stdout.write("ethernet = ")
    writeVal(netrec.getEthernet())

    sys.stdout.write("hw_arch = ")
    id = netrec.getId()
    if id is not None:
        archrec = Architecture.getUnique(id = id)
        if archrec is not None:
            writeVal(archrec['arch'])
        else:
            print
    else:
        print

    sys.stdout.write("ip_addr = ")
    ip = netrec.getIP()
    writeVal(ip)

    sys.stdout.write("mxhost = ")
    writeVal(netrec.getMxHost())

    sys.stdout.write("os_type = ")
    oses = netrec.getOses()
    st = string.join(oses, ",")
    print st

    sys.stdout.write("status = ")
    status = netrec.getStatus()
    if status is not None:
        st  = string.join(status, ",")
        print st

    sys.stdout.write("supp_grps = ")
    sup = netrec.getOtherNetgroups()
    if sup is not None:
        st = string.join(sup, ",")
        print st
    else:
        print

###########################################################################
# DELETE - deletes network information.  Leave equipment info as is.
###########################################################################
def delete(argv):
    if len(argv) < 3:
        warn("Usage: cdb delete <hostname>")
        return
    host = argv[2]

    netrec = Network.getUnique(hostname = host)
    if netrec is None:
        warn("No record for host " + host)
    else:
        id = netrec['id']
        netrec.delete()
        if id:
            eqrec = Equipment.getUnique(id = id)
            if not eqrec['comment']:
                eqrec['comment'] = 'formerly ' + host
        Network.commit()

###########################################################################
# INSERT
###########################################################################
class Insert:
    id = None
    netrec = None
    
    def __init__(self, argv):
        if len(argv) >= 3:
            self.id = argv[2]
        self.netrec = NetworkRecord.NetworkRecord()

    def hostname(self):
        while 1:
            resp = prompt("Enter hostname: ")
            if not resp:
                return
            if self.netrec.setHostname(resp):
                if self.id is None:
                    eqrec = Equipment.new(lid = 'unknown', descr = "(%s)" % resp)
                    self.id = eqrec['id']
                self.netrec.setId(self.id)
                return
            warn('There is already a host record for %s' % resp)

    def aliases(self):
        while 1:
            resp = prompt("Enter aliases: ")
            error = self.netrec.setAliases(makeList(resp))
            if not error:
                return
            warn(error)

    def prime_group(self):
        resp = prompt("Enter primary netgroup: ")
        self.netrec.setNetgroup(resp)

    def other_groups(self):
        resp = prompt("Enter other netgroups: ")
        self.netrec.setOtherNetgroups(makeList(resp))

    def comment(self):
        self.netrec.setComment(prompt("Enter comment: "))

    def ethernet(self):
        while 1:
            resp = prompt("Enter ethernet: ")
            if len(resp) == 0:
                return
            error = self.netrec.setEthernet(resp)
            if error:
                warn(error)
            else:
                return

    def ipaddr(self):
        while 1:
            resp = prompt("Enter IP addr: ")
            if len(resp) == 0:
                return
            if resp[-1] == '*':
                resp = pickIp(resp[:-2])
                print "  Picked " + resp
            error = self.netrec.setIP(resp)
            if error:
                warn(error)
            else:
                return

    def arch(self):
        while 1:
            resp = prompt("Enter hw arch: ").lower()
            if EquipmentRecord.isArchValid(resp):
                if resp:
                    Architecture.new(id = self.netrec.getId(), arch = resp)
                return
            sys.stdout.write(prog + ": Unrecognized architecture\n")

    def os(self):
        while 1:
            resp = prompt("Enter OS type: ")
            l = makeList(resp)
            problem = self.netrec.setOs(l)
            if problem is None:
                return
            sys.stdout.write(prog + ": Unrecognized OS: %s\n" % problem)

    def mxhost(self):
        resp = prompt("Enter mxhost: ")
        if resp:
            self.netrec.setMxHost(resp)

    def status(self):
        while 1:
            resp = prompt("Enter status: ")
            l = makeList(resp)
            problem = NetworkRecord.checkStatuses(l)
            if ( problem is None ):
                self.netrec.setStatus(l)
                break
            sys.stdout.write(prog + ": Unrecognized status: %s\n" % problem)


    def confirm(self):
        resp = prompt("Insert new record (y/n)[y]? ")
        if not resp:
            resp = 'y'
        if isYes(resp):
            self.netrec.commit()
        else:
            print "Insert cancelled."

###########################################################################
# MODIFY
###########################################################################
class Modify:
    def __init__(self, argv):
        if len(argv) < 3:
            warn("Usage: cdb modify <hostname>")
            sys.exit(1)
        self.netrec = NetworkRecord.fetchNetByHostname(argv[2])
        if not self.netrec:
            warn('No record for "%s" found in database' % argv[2])
            sys.exit(1)

    def getName(self):
        return self.netrec.getHostname()

    def hostname(self):
        hostname = self.netrec.getHostname()
        while 1:
            resp = prompt("Enter hostname:", hostname)
            if resp == hostname:
                return
            error = self.netrec.setHostname(resp)
            if not error:
                return
            warn('There is already a host record for %s' % resp)

    def aliases(self):
        alias = self.netrec.getAliases()
        default = string.join(alias, ',')
        while 1:
            resp = prompt("Enter aliases:", default)
            new = makeList(resp)
            new.sort()
            error = self.netrec.setAliases(new)
            if not error:
                return
            warn(error)

    def prime_group(self):
        default = self.netrec.getNetgroup()
        resp = prompt("Enter primary netgroup:", default)
        if resp != default:
            if resp:
                self.netrec.setNetgroup(resp)
            else:
                self.netrec.setNetroup(None)

    def other_groups(self):
        groups = self.netrec.getOtherNetgroups()
        default = string.join(groups, ',')
        resp = prompt("Enter other netgroups:", default)
        new = makeList(resp)
        new.sort()
        if new != groups:
            self.netrec.setOtherNetgroups(new)

    def comment(self):
        default = self.netrec.getComment()
        resp = prompt("Enter comment:", default)
        if default != resp:
            if resp:
                self.netrec.setComment(resp)
            else:
                self.netrec.setComment(None)
        
    def ethernet(self):
        default = self.netrec.getEthernet()
        while 1:
            resp = prompt("Enter ethernet:", default)
            if resp == default:
                return
            if not resp:
                return
            error = self.netrec.setEthernet(resp)
            if not error:
                return
            warn(error)

    def ipaddr(self):
        default = self.netrec.getIP()
        while 1:
            resp = prompt("Enter IP addr:", default)
            if resp == default:
                return
            if resp[-1] == '*':
                resp = pickIp(resp[:-2])
                print "  Picked " + resp
            error = self.netrec.setIP(resp)
            if error:
                warn(error)
            else:
                return

    def arch(self):
        eqrec = self.netrec.getEquipmentRec()
        default = eqrec.getArch()
        while 1:
            resp = prompt("Enter hw arch:", default).lower()
            if resp == default:
                return
            if EquipmentRecord.isArchValid(resp):
                eqrec.setArch(resp)
                return
            sys.stdout.write(prog + ": Unrecognized architecture\n")
        
    def os(self):
        default = string.join(self.netrec.getOses(), ',')
        while 1:
            resp = prompt("Enter OS type:", default)
            if resp == default:
                return
            new = makeList(resp)
            problem = self.netrec.setOs(new)
            if problem is None:
                return
            sys.stdout.write(prog + ": Unrecognized OS: %s\n" % problem)

    def mxhost(self):
        default = self.netrec.getMxHost()
        resp = prompt("Enter mxhost:", default)
        if resp == default:
            return
        self.netrec.setMxHost(resp)

    def status(self):
        default = string.join(self.netrec.getStatus(), ',')
        while 1:
            resp = prompt("Enter status:", default)
            if resp == default:
                return
            l = makeList(resp)
            problem = NetworkRecord.checkStatuses(l)
            if ( problem is None ):
                self.netrec.setStatus(l)
                break
            sys.stdout.write(prog + ": Unrecognized status: %s\n" % problem)

    def confirm(self):
        resp = prompt("\nSave changed record (y/n)[y]? ")
        if not resp:
            resp = 'y'
        if isYes(resp):
            self.netrec.commit()
        else:
            print "No modifications saved."


###########################################################################
# Main braches of the program.  Eventually, these should be subclasses
###########################################################################
def modify(argv):
    modify = Modify(argv)

    print '\nModifying record for host "%s":\n' % modify.getName()

    modify.hostname()
    modify.aliases()
    modify.prime_group()
    modify.other_groups()
    modify.comment()
    modify.ethernet()
    modify.ipaddr()
    modify.arch()
    modify.os()
    modify.mxhost()
    modify.status()

    modify.confirm()
        
def insert(argv):
    insert = Insert(argv)
    insert.hostname()
    insert.aliases()
    insert.prime_group()
    insert.other_groups()
    insert.comment()
    insert.ethernet()
    insert.ipaddr()
    insert.arch()
    insert.os()
    insert.mxhost()
    insert.status()

    insert.confirm()

###########################################################################
# MAIN
###########################################################################
def main():
    if len(sys.argv) < 2:
        warn("Usage: " + prog + " <command> [<hostname>]")
        sys.exit(1)
    command = sys.argv[1]
        
    if command == 'insert':
        insert(sys.argv)
    elif command == 'delete':
        delete(sys.argv)
    elif command == 'modify':
        modify(sys.argv)
    elif command == 'profile':
        profile(sys.argv)
    else:
        warn(prog + ": Unknown command: " + command + "\n")
        sys.exit(1)

if __name__ == '__main__':
    import os.path
    prog = os.path.basename(sys.argv[0])
    try:
        if prog == 'edb':
            import TextUI
            ui = TextUI.edb(prog)
            ui.main(sys.argv[1:])
        else:
            main()
    except KeyboardInterrupt:
        Network.rollback()
        print "\nCaught control-C"

