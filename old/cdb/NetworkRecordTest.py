#!/usr/bin/python

# $Id$

import unittest
import NetworkRecord

class NetworkRecordTest(unittest.TestCase):
    def testCreate(self):
        netrec = NetworkRecord.NetworkRecord()
        self.assert_(netrec.getNid() > 0)

    def testFetch(self):
        netrec = NetworkRecord.fetchNetByHostname('mothra')
        self.assertEquals('mothra', netrec.getHostname())

    def testFetchByNid(self):
        netrec = NetworkRecord.fetchNetByNid(108)
        self.assertEquals('mothra', netrec.getHostname())
        netrec = NetworkRecord.fetchNetByNid('108')
        self.assertEquals('mothra', netrec.getHostname())

    def testHostname(self):
        netrec = NetworkRecord.NetworkRecord()
        self.assert_( netrec.setHostname('mothra') == 0 )
        self.assert_( netrec.setHostname('zyadfakjh') == 1 )

    def test_bcase(self):
        self.assertEquals('128.148.33.255', NetworkRecord.bcast('128.148.33.23'))

    def testAliases(self):
        netrec = NetworkRecord.fetchNetByHostname('mothra')
        aliases = netrec.getAliases()
        self.assert_( aliases is not None )
        self.assertEquals( 5, len(aliases) )
        l = [ 'abhost', 'calhost', 'fingerhost','hqnserver1', 'radmin' ]
        self.assertEquals( l, aliases )

        error = netrec.setAliases(['fingerhost'])
        self.assertEquals(None, error)

        error = netrec.setAliases(['foo', 'bar'])
        self.assertEquals(None, error)
        
        error = netrec.setAliases(['printhost'])
        self.assertEquals('printhost', error)

        error = netrec.setAliases(['discordia'])
        self.assertEquals('discordia', error)

    def testNetgroups(self):
        netrec = NetworkRecord.fetchNetByHostname('shutter')
        l = ['4th5th', 'graphics', 'linux', 'unsup']
        self.assertEquals(l, netrec.getNetgroups())
        l = [ '4th5th', 'graphics', 'linux', 'unsup' ]
        self.assertEquals(l, netrec.getNetgroups())
        netrec.setNetgroups(l)
        self.assertEquals(l, netrec.getNetgroups())
        l = [ 'blort' ]
        netrec.setNetgroups(l)
        self.assertEquals(l, netrec.getNetgroups())
        netrec.setNetgroups([])
        self.assertEquals([], netrec.getNetgroups())
        netrec.setNetgroups(None)
        self.assertEquals([], netrec.getNetgroups())

    def testIpAddr(self):
        netrec = NetworkRecord.fetchNetByHostname('mothra')
        self.assertEquals('128.148.31.17', netrec.getIP())
        error = netrec.setIP('128.148.33.1')
        self.assert_(error is not None)
        error = netrec.setIP('128.148.31.17')
        self.assertEquals(None, error)

    def testEthernet(self):
        netrec = NetworkRecord.fetchNetByHostname('mothra')
        self.assertEquals('08:00:20:89:f3:25', netrec.getEthernet())
        self.assertEquals('Ethernet in use on subnet by trogon',
                          netrec.setEthernet('8:0:20:e9:49:c0'))
        self.assertEquals(None, netrec.setEthernet('08:00:20:89:f3:25'))
        self.assertEquals('08:00:20:89:f3:25', netrec.getEthernet())

    def testOs(self):
        netrec = NetworkRecord.fetchNetByHostname('mothra')
        oses = netrec.getOses()
        self.assertEquals(1, len(oses))
        self.assertEquals(oses[0], 'sunos5.7b')
        
        netrec = NetworkRecord.fetchNetByHostname('dhcp33-1')
        oses = netrec.getOses()
        self.assertEquals([], oses)

        netrec = NetworkRecord.fetchNetByHostname('hudson31')
        oses = netrec.getOses()
        self.assertEquals(2, len(oses))
        self.assertEquals(['linux', 'win2k'], oses)

        self.assertEquals(None, netrec.setOs(['sunos5.6', 'WinXP']))
        netrec = NetworkRecord.fetchNetByHostname('hudson31')
        oses = netrec.getOses()
        self.assertEquals(['sunos5.6', 'winxp'], oses)

        self.assertEquals('blort', netrec.setOs(['blort']))

    def testStatus(self):
        netrec = NetworkRecord.fetchNetByHostname('mothra')
        stat= netrec.getStatus()
        self.assertEquals(1, len(stat))
        self.assertEquals(stat[0], 'active')

        netrec = NetworkRecord.fetchNetByHostname('martin')
        stat= netrec.getStatus()
        self.assertEquals(2, len(stat))
        self.assertEquals(['active', 'monitoredPC'], stat)

        self.assertEquals(None, netrec.setStatus(['disabled']))

        netrec = NetworkRecord.fetchNetByHostname('martin')
        stat = netrec.getStatus()
        self.assertEquals(['disabled'], stat)

        self.assertEquals('blort', netrec.setStatus(['blort']))

def suite():
    return unittest.makeSuite(NetworkRecordTest,'test')
