#!/usr/bin/python

# $Id$

import udb
import DBRecord
import EquipmentRecord

#
# make sure all aliases are available
#
def checkAliases(aliases, nid = None):
    for a in aliases:
        if not isNameAvailable(a, nid):
            return a
    return None
    
#
# returns 1 if hostname is available, 0 if it's in use
#
def isNameAvailable(name, nid = None):
    if not name:
        return 1
    if nid:
        rec = udb.Network.getSQLWhere("hostname = '%s' and nid != %d"
                                  % (name, nid))
        if len(rec) != 0:
            return 0
    else:
        rec = udb.Network.getUnique(hostname = name)
        if rec:
            return 0

    if nid:
        rec = udb.Aliases.getSQLWhere("alias = '%s' and nid != %d"
                                  % (name, nid))
        if len(rec) != 0:
            return 0
        else:
            return 1
    else:
        rec = udb.Aliases.getUnique(alias = name)
        if rec:
            return 0
        else:
            return 1

#
# Check to make sure eth is a valid ethernet
#
def isValidEthernet(eth):
    eth = eth.replace('-', ':')
    bytes = eth.split(':')
    if len(bytes) != 6:
        return "not enough bytes: need 6, got %d" % len(bytes)
    for b in bytes:
        try:
            v = int(b, 16)
        except ValueError:
            return "'%s' isn't a valid hex byte" % b
        if v > 0xFF:
            return "'%s' is too large for a hex byte" % b
    return None

def checkSubnetEthernet(ip, ether, nid = None):
    if not ip:
        return None
    if not ether:
        return None
    broadcast = bcast(ip) + '/24'
    rec = udb.Network.getSome(bcast = DBRecord.quote(broadcast),
                          ethernet = ether)
    if len(rec) == 0:
        return None
    if len(rec) == 1:
        if nid:
            if rec[0]['nid'] == nid:
                return None
        return rec[0]['hostname']
    assert 0, "NOT REACHED: Ethernet: %s, Ip: %s" % (ether, ip)

def bcast(ip):
    bytes = ip.split('.')
    bytes[3] = '255'
    return '.'.join(bytes)

def isValidIp(ip):
    if not ip:
        return None
    bytes = ip.split('.')
    if len(bytes) < 4:
        return "Not enough bytes.  Need 4, got %d" % len(bytes)
    bytes = [ int(n) for n in bytes ]
    for b in bytes:
        if not 0 <= b <= 255:
            return "Bytes must be between 0 and 255, not %d" % b
    if bytes[3] == 1 or bytes[3] == 255:
        return "Hosts can't be 1 or 255"
    if bytes[0] == 0:
        return "Network can't be zero"
    return None

def isIpAvailable(ip, nid = None):
    ip += '/24'
    rec = udb.Network.getUnique(ipaddr = "'%s'" % ip)
    if rec is None:
        return 1
    if nid:
        if rec['nid'] == nid:
            return 1
    return 0

def checkStatuses(l):
    for stat in l:
        if not isStatusValid(stat):
            return stat
    return None

def isStatusValid(stat):
    # get list of statuses, ignoring case
    rec = udb.StatusList.getSQLWhere("status ~* '^%s$'" % stat)
    return len(rec)

def fixStatus(stat):
    rec = udb.StatusList.getSQLWhere("status ~* '^%s$'" % stat)
    if not rec:
        return None
    return rec[0]['status']

def fetchNetByHostname(host):
    netrec = udb.Network.getUnique(hostname = host)
    if netrec is None:
        return None
    return NetworkRecord(netrec)
        
def fetchNetByNid(nid):
    netrec = udb.Network.getUnique(nid = nid)
    if netrec is None:
        return None
    return NetworkRecord(netrec)

class NetworkRecord(DBRecord.DBRecord):
    record = None
    eqRec = None

    def __init__(self, netrec = None):
        if netrec is None:
            self.record = udb.Network.new()
            self.eqRec = EquipmentRecord.EquipmentRecord( 'None')
            self.setId(self.eqRec.getId())
        else:
            self.record = netrec
            self.eqRec = self.getEquipmentRec()

    def getEquipmentRec(self):
        id = self.getId()
        if id is None:
            return  None
        return EquipmentRecord.fetchEqById(self.getId())
    
    def getHostname(self):
        return self.record['hostname']
    
    def setHostname(self, name):
        if not isNameAvailable(name):
            return 0

        if not name:
            name = None
        self.record['hostname'] = name
        if self.eqRec.getDescr() == 'None':
            self.eqRec.setDescr('(' + name + ')')
        return 1

    def getNid(self):
        return self.record['nid']
    
    def getId(self):
        return self.record['id']

    def getMxHost(self):
        return self.record['mxhost']

    def setMxHost(self, host):
        self.record['mxhost'] = host
        
    def setId(self, id):
        if not id:
            id = None
        self.record['id'] = id

    def getNetgroup(self):
        return self.record['netgroup']

    def setNetgroup(self, group):
        if not group:
            group = None
        self.record['netgroup'] = group
        
    def getAliases(self):
        aliases = self.record.getAliases()
        list = [ a['alias'] for a in aliases ]
        list.sort()
        return list

    def deleteAllAliases(self):
        for alias in self.record.getAliases():
            alias.delete()

    def setAliases(self, aliases):
        aliases.sort()
        old = self.record.getAliases()
        if old:
            if old == aliases:
                return None
            problem = checkAliases(aliases, self.record['nid'])
            if problem:
                return problem
            self.deleteAllAliases()
        else:
            problem = checkAliases(aliases)
            if problem:
                return problem

        for a in aliases:
            udb.Aliases.new(nid = self.record['nid'], alias = a)
        return None

    def getOtherNetgroups(self):
        groups = self.record.getNetgroups()
        list = [ a['netgroup'] for a in groups ]
        list.sort()
        return list

    def setOtherNetgroups(self, groups):
        if not groups:
            for group in self.record.getNetgroups():
                group.delete()
            return
            
        groups.sort()
        old = self.getOtherNetgroups()
        if old:
            if groups == old:
                return

            for group in self.record.getNetgroups():
                group.delete()
        for g in groups:
            udb.Netgroups.new(nid = self.record['nid'], netgroup = g)
            

    def getComment(self):
        return self.record['comment']

    def setComment(self, comment):
        self.record['comment'] = comment

    def getEthernet(self):
        if self.record.has_key('ethernet'):
            return self.record['ethernet']
        return None

    def setEthernet(self, ether):
        error = isValidEthernet(ether)
        if error:
            return error

        error = checkSubnetEthernet(self.getIP(), ether, self.getNid())
        if error:
            return "Ethernet in use on subnet by %s" % error
        self.record['ethernet'] = ether
        return None

    def getIP(self):
        if not self.record.has_key('ipaddr'):
            return None
        ip = self.record['ipaddr']
        if ip:
            ip = ip[:-3]   # strip the /24 off the end
        return ip

    def setIP(self, ip):
        if ip:
            error = isValidIp(ip)
            if error:
                return "Not a valid IP: " + error
            if not isIpAvailable(ip, self.getNid()):
                return "Ip is in use"

            error = checkSubnetEthernet(ip, self.getEthernet(), self.getNid())
            if error:
                return "Ethernet in use on subnet by %s" % error

        self.record['bcast'] = None
        self.record['ipaddr'] = None
        if ip:
            self.record['bcast'] = self.quote(bcast(ip) + '/24')
            self.record['ipaddr'] = self.quote(ip + '/24')
        return None

    def getStatus(self):
        stats = self.record.getStatuses()
        list = [ s['status'] for s in stats ]
        list.sort()
        return list
        
    def setStatus(self, statusList):
        error = checkStatuses(statusList)
        if error:
            return error
        
        old = self.record.getStatuses()
        for s in old:
            s.delete()
            
        for stat in statusList:
            udb.Status.new(nid = self.getNid(), status = fixStatus(stat))
        return None

    def getOses(self):
        if not self.eqRec:
            return None
        return self.eqRec.getOses()
        
    def setOs(self, osList):
        if not self.eqRec:
            return 'No equpiment record'
        return self.eqRec.setOs(osList)

    def getArch(self):
        if not self.eqRec:
            return None
        return self.eqRec.getArch()

    def commit(self):
        self.record.commit()
