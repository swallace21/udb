#!/usr/bin/python

# $Id$

import unittest
import DB

class DBTest(unittest.TestCase):
        
    def setUp(self):
        global db
        db = DB.DB()

    def tearDown(self):
        db.close()

    def testEthernetHostname(self):
        foo = db.getHostnameEthernet()
        self.assertEquals('00:02:b3:28:4a:46', foo[0][0])
        self.assertEquals('adminhost', foo[0][1])
        self.assertEquals('00:04:75:bc:7a:f3', foo[len(foo)-1][0])
        self.assertEquals('zuul2', foo[len(foo)-1][1])

    def testEthernetNoIp(self):
        foo = db.getEthernetNoIp()
        self.assertEquals(953, foo[0][0])
        self.assertEquals('00:02:a5:99:8f:f8', foo[0][1])

    def testNetgroup(self):
        result = db.getNetgroup('linux')
        self.assertEquals(289, len(result))
        self.assert_(86 in result)
        self.assert_(1 not in result)

    def testDdhcp(self):
        result = db.getDdhcp()
        self.assertEquals(89, len(result))
        self.assert_([1026, '00:0a:95:66:51:d8', 'charles: '] in result)
        
    def testMakeSt(self):
        st = DB.makeSt( [1, 2] )
        self.assertEquals('1, 2', st)

    def testGetAliases(self):
        result = db.getAliases(94)
        self.assertEquals(['abhost', 'calhost', 'cvs', 'fingerhost',
                           'hqnserver1', 'radmin'], result)
        result = db.getAliases(480)
        self.assertEquals([], result)

    def testGetHostfile(self):
        result = db.getHostfile()
        self.assertEquals('128.148.31.1', result[0][0])
        self.assertEquals('cat4000-31', result[0][1])
        self.assertEquals([], result[0][2])

    def testGetHostnamesInNetgroup(self):
        result = db.getHostnamesInNetgroup('cgc')
        self.assertEquals(['maxou', 'sphere', 'tetra'], result)
        result = db.getHostnamesInNetgroup('unsup')
        self.assertEquals(81, len(result))
        self.assertEquals('z', result[80])

    def testGetAllNetgroups(self):
        result = db.getAllNetgroups()
        self.assertEquals(25, len(result))

    def testGetFAIConfig(self):
        # this should be in the table
        result = db.getFAIConfig(678)
        self.assertEquals('phred', result)
        result = db.getFAIConfig(-1)
        self.assertEquals(None, result)

    def testIterNoResult(self):
        iter = db. get_nid_ipaddr_hostname('xyzzy')
        count = 0
        while iter.hasNext():
            count += 1
            row = iter.next()
            self.assertNotEquals(None, row)
        self.assertEquals(0, count)
                          
    def testIterSingleResult(self):
        iter = db.get_nid_ipaddr_hostname('unsupp')
        count = 0
        while iter.hasNext():
            count += 1
            row = iter.next()
            self.assertNotEquals(None, row)
            self.assertEquals([635, '128.148.31.174', 'adminhost'], row)
        self.assertEquals(1, count)

    def testIterManyResult(self):
        iter = db.get_nid_ipaddr_hostname('linux')
        count = 0
        while iter.hasNext():
            count += 1
            row = iter.next()
            self.assertNotEquals(None, row)
        self.assertEquals(289, count)

    def testGetDNSData(self):
        iter = db.getDNSData()
        self.assert_(iter.hasNext())
        row = iter.next()
        self.assertEquals('adminhost', row[2])
        count = 0
        while iter.hasNext():
            count += 1
            row = iter.next()
        self.assertEquals(751, count)
        self.assertEquals('zuul2', row[2])

    def testGetRevDNS(self):
        iter = db.getReverseDNS(31)
        self.assert_(iter.hasNext())
        row = iter.next()
        self.assertEquals(['128.148.31.1', 'cat4000-31'], row)
        while iter.hasNext():
            row = iter.next()
        self.assertEquals(['128.148.31.254','snickers-31'], row)

def suite():
    return unittest.makeSuite(DBTest, 'test')
