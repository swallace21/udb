#!/usr/bin/python

# $Id$

import udb
import DBRecord
import NetworkRecord

def isValidLid(lid):
    if not lid:
        return 0
    locRec = udb.Location.getUnique(lid = lid)
    if locRec:
        return 1
    return 0

def isArchValid(arch):
    if not arch:
        return 1
    rec = udb.ArchList.getUnique(arch = arch)
    if rec is None:
        return 0
    return 1

def checkOses(l):
    for os in l:
        if not isOSValid(os):
            return os
    return None

def isValidUsage(usage):
    rec = udb.Usage.getUnique(usage = usage)
    if rec:
        return 1
    return 0

def isOSValid(os):
    rec = udb.OsList.getSQLWhere("os ~* '^%s$'" % os)
    return len(rec)

def fixOs(os):
    rec = udb.OsList.getSQLWhere("os ~* '^%s$'" % os)
    if not rec:
        return None
    return rec[0]['os']

def fetchEqById(id):
    if not type(id) is int:
        if not id.isdigit():
            return None
    rec = udb.Equipment.getUnique(id = id)
    if rec is None:
        return None
    return EquipmentRecord(None, rec)

def fetchEqByHostname(hostname):
    netrec = NetworkRecord.fetchNetByHostname(hostname)
    if netrec is None:
        return None
    return netrec.getEquipmentRec()

class EquipmentRecord(DBRecord.DBRecord):
    def __init__(self, desc, eqrec = None, lid = 'unknown'):
        if eqrec is None:
            self.record = udb.Equipment.new(lid = lid, descr = desc)
        else:
            self.record = eqrec

    def getHostnames(self):
        rec = udb.Network.getSome(id = self.getId())
        return [ h['hostname'] for h in rec ]

    def getNids(self):
        rec = udb.Network.getSome(id = self.getId())
        return [ r['nid'] for r in rec ]

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
        if not urec:
            return None
        return [ u['users'] for u in urec ]

    def setUsers(self, userList):
        old = self.record.getUsers()
        for u in old:
            u.delete()
        for u in userList:
            udb.Users.new(id = self.getId(), users = u)

    def getSerialNumber(self):
        return self.record['serial_num']

    def setSerialNumber(self, serial):
        if not serial:
            self.record['serial_num'] = None
        else:
            self.record['serial_num'] = serial

    def getInventoryNumber(self):
        return self.record['inventory_num']

    def setInventoryNumber(self, num):
        if not num:
            self.record['inventory_num'] = None
        else:
            self.record['inventory_num'] = num

    def getUsage(self):
        return self.record['usage']

    def setUsage(self, usage):
        self.record['usage'] = usage

    def getComment(self):
        return self.record['comment']

    def setArch(self, arch):
        a = self.record.getArchitecture()
        if a:
            a.delete()
        if arch:
            udb.Architecture.new(id = self.getId(), arch = arch)

    def getOses(self):
        os = self.record.getOsTypes()
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
            udb.OsType.new(id = self.getId(), os = fixOs(os))
        return None

    def formatDate(self, d):
        if d:
            return '%d/%d/%d' % (d.month, d.day, d.year)
        else:
            return None
    
    def getPO(self):
        po = self.getPORec()
        if not po:
            return (None, None, None, None)
        return ( po['po_num'], self.formatDate(po['date']), po['price'],
                 po['comment'] )

    def fetchOrCreatePO(self):
        po = self.getPORec()
        if not po:
            po = udb.Purchase.new(id = self.getId())
        return po
        
    def getPORec(self):
        return self.record.getPurchase()

    def setPONumber(self, num):
        if not num:
            num = None
        po = self.fetchOrCreatePO()
        po['po_num'] = num

    def setPODate(self, date):
        if not date:
            date = None
        po = self.fetchOrCreatePO()
        po['date'] = date

    def setPOPrice(self, price):
        if not price:
            price = None
        po = self.fetchOrCreatePO()
        po['price'] = price

    def setPOComment(self, comment):
        if not comment:
            comment = None
        po = self.fetchOrCreatePO()
        po['comment'] = comment

    def getInstallRec(self):
        return self.record.getInstallation()
    
    def fetchOrCreateInstall(self):
        inst = self.getInstallRec()
        if not inst:
            inst = udb.Installation.new(id = self.getId())
        return inst
    
    def getInstallation(self):
        inst = self.getInstallRec()
        if not inst:
            return ( None, None )
        return ( self.formatDate(inst['date']), inst['comment'] )

    def setInstallDate(self, date):
        if not date:
            date = None
        inst = self.fetchOrCreateInstall()
        inst['date'] = date

    def setInstallComment(self, comment):
        if not comment:
            comment = None
        inst = self.fetchOrCreateInstall()
        inst['comment'] = comment

    def getConfRec(self):
        return self.record.getConfig()
    
    def getConfiguration(self):
        c = self.getConfRec()
        if not c:
            return (None, None, None, None, None)
        return (c['cpu'], c['disk'], c['memory'], c['graphics'], c['comment'])
        
        
