#!/usr/bin/python

import unittest
import udb
import EquipmentRecord

class EquipmentRecordTest(unittest.TestCase):
    def testCreate(self):
        rec = EquipmentRecord.EquipmentRecord('new host')
        self.assert_(rec is not None)

    def testId(self):
        rec = EquipmentRecord.EquipmentRecord('blort')
        self.assert_(rec.getId() > 0 )

    def testFetch(self):
        rec = EquipmentRecord.fetchEqById(1)
        self.assert_(rec is not None)
        self.assertEquals('(clclap)', rec.getDescr())

    def testFetchByHostname(self):
        rec = EquipmentRecord.fetchEqByHostname('clclap');
        self.assert_(rec is not None)
        self.assertEquals(1, rec.getId())

        # hostname doesn't exists
        rec = EquipmentRecord.fetchEqByHostname('aadfijhadkfb');
        self.assert_(rec is None);

        # hostname has network entry, but no equipment entry
        rec = EquipmentRecord.fetchEqByHostname('swamp');
        self.assert_(rec is None);
        
    def test_checkOses(self):
        result = EquipmentRecord.checkOses(self.valid)
        self.assert_( result is None, result)
        self.assertEquals('blort', EquipmentRecord.checkOses(self.valid + ['blort']))

    def test_ignoreCase(self):
        for os in self.valid:
            self.assert_(EquipmentRecord.isOSValid(os.lower()), "%s should be valid" % os)
            
    valid = ['sunos5.6', 'sunos5.7', 'sunos5.7b', 'sunos5.8',
             'linux', 'windows', 'win95', 'win98', 'winCE', 'win2k',
             'winxp', 'nt','macos']

    def test_isOSValid(self):
        for os in self.valid:
            self.assert_(EquipmentRecord.isOSValid(os), "%s should be valid" % os)
        self.assert_(not EquipmentRecord.isOSValid('blort'))

    def test_fixOs(self):
        for os in self.valid:
            self.assertEquals(os, EquipmentRecord.fixOs(os.lower()))

    def test_isArchValid(self):
        valid = ['sun4c', 'sun4m', 'sun4u', 'apple', 'x86', 'alpha']
        for a in valid:
            self.assert_(EquipmentRecord.isArchValid(a))
        self.assert_(not EquipmentRecord.isArchValid('blort'))
        self.assert_(EquipmentRecord.isArchValid(None))
        self.assert_(EquipmentRecord.isArchValid(''))

    def test_setPO(self):
        eq = EquipmentRecord.EquipmentRecord('None')
        po = udb.Purchase.new(id = eq.getId())
        self.assertEquals(eq.getId(), po['id'])
        eq.setPOComment('foobar')
        self.assertEquals('foobar', eq.getPO()[3])

    def test_setInst(self):
        eq = EquipmentRecord.EquipmentRecord('None')
        inst = udb.Installation.new(id = eq.getId())
        inst['comment'] = 'foobar'
        self.assertEquals('foobar', inst['comment'])

def suite():
    return unittest.makeSuite(EquipmentRecordTest,'test')
