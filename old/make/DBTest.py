#!/usr/bin/python

# $Id$

import unittest
import DB

mothraNid = 108
phredNid = 535
charlesNid = 6
adminhostNid = 474
firstEtherNoIpNid = 6
firstEtherNoIpEther = '00:0a:95:66:51:d8'
numDNSEntries = 797
numHostsInLinuxNetgroup = 313
numHostsInUnsuppNetgroup = 86
hostWithNoAliasesNid = 342
numActiveDynamicHosts = 81

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
        self.assertEquals(firstEtherNoIpNid, foo[0][0])
        self.assertEquals(firstEtherNoIpEther, foo[0][1])

    def testNetgroup(self):
        result = db.getNetgroup('linux')
        self.assertEquals(313, len(result))
        self.assert_(phredNid in result)
        self.assert_(10000 not in result)

    def testDdhcp(self):
        result = db.getDdhcp()
        self.assertEquals(numActiveDynamicHosts, len(result))
        self.assert_([charlesNid, '00:0a:95:66:51:d8', 'spr?'] in result)
        
    def testMakeSt(self):
        st = DB.makeSt( [1, 2] )
        self.assertEquals('1, 2', st)

    def testGetAliases(self):
        result = db.getAliases(mothraNid)
        self.assertEquals(['abhost', 'calhost', 'fingerhost',
                           'hqnserver1', 'radmin'], result)
        result = db.getAliases(hostWithNoAliasesNid)
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
        self.assertEquals(numHostsInUnsuppNetgroup, len(result))
        self.assertEquals('z', result[-1])

    def testGetAllNetgroups(self):
        result = db.getAllNetgroups()
        self.assertEquals(25, len(result))

    def testGetFAIConfig(self):
        # this should be in the table
        result = db.getFAIConfig(phredNid)
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
            self.assertEquals([474, '128.148.31.174', 'adminhost'], row)
        self.assertEquals(1, count)

    def testIterManyResult(self):
        iter = db.get_nid_ipaddr_hostname('linux')
        count = 0
        while iter.hasNext():
            count += 1
            row = iter.next()
            self.assertNotEquals(None, row)
        self.assertEquals(numHostsInLinuxNetgroup, count)

    def testGetDNSData(self):
        iter = db.getDNSData()
        self.assert_(iter.hasNext())
        row = iter.next()
        self.assertEquals('adminhost', row[2])
        count = 0
        while iter.hasNext():
            count += 1
            row = iter.next()
        self.assertEquals(numDNSEntries, count)
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
