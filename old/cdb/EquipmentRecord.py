#!/usr/bin/python

# $Id$

from udb import *
import DBRecord
import NetworkRecord

def isValidLid(lid):
    if not lid:
        return 0
    locRec = Location.getUnique(lid = lid)
    if locRec:
        return 1
    return 0

def isArchValid(arch):
    if not arch:
        return 1
    rec = ArchList.getUnique(arch = arch)
    if rec is None:
        return 0
    return 1

def checkOses(l):
    for os in l:
        if not isOSValid(os):
            return os
    return None

def isOSValid(os):
    rec = OsList.getSQLWhere("os ~* '^%s$'" % os)
    return len(rec)

def fixOs(os):
    rec = OsList.getSQLWhere("os ~* '^%s$'" % os)
    if not rec:
        return None
    return rec[0]['os']

def fetchEqById(id):
    if not type(id) is int:
        if not id.isdigit():
            return None
    rec = Equipment.getUnique(id = id)
    if rec is None:
        return None
    return EquipmentRecord(None, rec)

def fetchEqByHostname(hostname):
    netrec = NetworkRecord.fetchNetByHostname(hostname)
    if netrec is None:
        return None
    return netrec.getEquipmentRec()

class EquipmentRecord(DBRecord.DBRecord):
    record = None

    def __init__(self, desc, eqrec = None, lid = 'unknown'):
        if eqrec is None:
            self.record = Equipment.new(lid = lid, descr = desc)
        else:
            self.record = eqrec

    def getHostnames(self):
        rec = Network.getSome(id = self.getId())
        names = []
        for h in rec:
            names.append(h['hostname'])
        return names
        
    def getId(self):
        return self.record['id']

    def setComment(self, comment):
        self.record['comment'] = comment

    def getDescr(self):
        return self.record['descr']

    def setDescr(self, desc):
        self.record['descr'] = desc

    def getArch(self):
        archRec = self.record.getArchitecture()
        if archRec:
            return archRec['arch']
        return None

    def getLid(self):
        return self.record['lid']

    def setLid(self, lid):
        self.record['lid'] = lid

    def getUsers(self):
        urec = self.record.getUsers()
        if urec is None:
            return None
        if len(urec) < 1:
            return None
        return urec[0]['users']

    def getSerialNumber(self):
        return self.record['serial_num']

    def getInventoryNumber(self):
        return self.record['inventory_num']

    def getUsage(self):
        return self.record['usage']

    def getComment(self):
        return self.record['comment']

    def setArch(self, arch):
        a = self.record.getArchitecture()
        if a:
            a.delete()
        if arch:
            Architecture.new(id = self.getId(), arch = arch)

    def getOses(self):
        os = self.record.getOsTypes()
        #list = map(lambda o: o['os'], os)
        list = [ o['os'] for o in os ]
        list.sort()
        return list

    def setOs(self, osList):
        problem = checkOses(osList)
        if problem:
            return problem
        old = self.record.getOsTypes()
        for os in old:
            os.delete()
            
        for os in osList:
            OsType.new(id = self.getId(), os = fixOs(os))
        return None

    def getPO(self):
        po = self.record.getPurchase()
        if not po:
            return (None, None, None, None)
        return ( po['po_num'], po['date'], po['price'], po['comment'] )

    def getInstallation(self):
        inst = self.record.getInstallation()
        if not inst:
            return ( None, None )
        return ( inst['date'], inst['comment'] )
