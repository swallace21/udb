#!/usr/bin/python

import unittest
import cdb
import NetworkRecord

availableIP = '128.148.38.243'
mothraNid = 94

class IPTests(unittest.TestCase):
    def test_isValidIp(self):
        bad = ['x', '1.2.3', '12.-4.34.34', '128.148.32.255',
               '192.168.1.255', '255.255.255.255', '0.0.0.0']
        for ip in bad:
            self.assert_(NetworkRecord.isValidIp(ip) is not None,
                         "%s should be invalid" % ip)

        good = [None, '', '10.0.0.2', '128.148.33.100']
        for ip in good:
            self.assert_(NetworkRecord.isValidIp(ip) is None, "%s should be valid" % ip)

    def test_isIpAvailable(self):
        taken = ['128.148.31.1', '128.148.34.101']
        for ip in taken:
            self.assert_(not NetworkRecord.isIpAvailable(ip))
        avail = ['128.148.34.56', '128.148.19.190']
        for ip in avail:
            self.assert_(NetworkRecord.isIpAvailable(ip))

    def test_pickIp(self):
        ip = cdb.pickIp('128.148.34');
        self.assertEquals('128.148.34.6', ip)

        ip = cdb.pickIp('128.148.38');
        self.assertEquals(availableIP, ip)

    def test_gethostnum(self):
        self.assertEquals(1, cdb.gethostnum('128.148.34.1', '128.148.34'))
        self.assertEquals(22, cdb.gethostnum('128.148.34.22', '128.148.34'))
        self.assertEquals(222, cdb.gethostnum('128.148.34.222', '128.148.34'))
        self.assertEquals(222, cdb.gethostnum('1.1.3.222', '1.1.3'))

class HostnameTests(unittest.TestCase):
    def test_isNameAvailable(self):
        self.assert_(NetworkRecord.isNameAvailable('mothra') == 0)
        self.assert_(NetworkRecord.isNameAvailable('mothra', mothraNid) == 1)
        self.assert_(NetworkRecord.isNameAvailable('printhost') == 0)
        self.assert_(NetworkRecord.isNameAvailable('') == 1)
        self.assert_(NetworkRecord.isNameAvailable(None) == 1)
        self.assert_(NetworkRecord.isNameAvailable('xyzzy'))

    def test_checkAliases(self):
        list = ['mothra', 'xyzzy']
        self.assertEquals('mothra', NetworkRecord.checkAliases(list))
        list = ['xyzzy', 'mothra']
        self.assertEquals('mothra', NetworkRecord.checkAliases(list))
        list = ['xyzzy', 'adsjfhdf']
        self.assert_(NetworkRecord.checkAliases(list) is None)

class UtilTests(unittest.TestCase):
    def test_makeList(self):
        self.assertEquals([], cdb.makeList(''))
        self.assertEquals(['one'], cdb.makeList('one'))
        st = 'one,two,three'
        l = ['one', 'two', 'three']
        self.assertEquals(l, cdb.makeList(st))
        st = 'one , two, three'
        self.assertEquals(l, cdb.makeList(st))
        st = ' one , two, three  '
        self.assertEquals(l, cdb.makeList(st))
        st = 'one,,two,three'
        l = ['one', '', 'two', 'three']
        self.assertEquals(l, cdb.makeList(st))

    def test_bcase(self):
        self.assertEquals('128.148.33.255', NetworkRecord.bcast('128.148.33.23'))

    def test_isYes(self):
        self.assert_(cdb.isYes('y'))
        self.assert_(cdb.isYes('ye'))
        self.assert_(cdb.isYes('yes'))
        self.assert_(cdb.isYes('Y'))
        self.assert_(cdb.isYes('YE'))
        self.assert_(cdb.isYes('YES'))

        self.assert_(not cdb.isYes('n'))
        self.assert_(not cdb.isYes('no'))
        self.assert_(not cdb.isYes('N'))
        self.assert_(not cdb.isYes('NO'))
        self.assert_(not cdb.isYes('YESn'))
        self.assert_(not cdb.isYes('x'))

class StatusTests(unittest.TestCase):
    valid = ['active', 'monitoredPC', 'home', 'special', 'notCS', 'disabled']

    def test_isStatusValid(self):
        for status in self.valid:
            self.assert_(NetworkRecord.isStatusValid(status))
        self.assert_(not NetworkRecord.isStatusValid('blort'))

    def test_checkStatuses(self):
        self.assert_(NetworkRecord.checkStatuses(self.valid) is None)
        self.assertEquals('blort', NetworkRecord.checkStatuses(self.valid + ['blort']))

    def test_ignoreCase(self):
        for stat in self.valid:
            self.assert_(NetworkRecord.isStatusValid(stat.lower()))
        self.assert_(not NetworkRecord.isStatusValid('tiv'))

    def test_fixStatus(self):
        for stat in self.valid:
            self.assertEquals(stat, NetworkRecord.fixStatus(stat.lower()))

class EthernetTests(unittest.TestCase):
    def test_available(self):
        result = NetworkRecord.checkSubnetEthernet('128.148.31.23', '8:0:20:89:f3:25')
        self.assertEquals('mothra', result)
        result = NetworkRecord.checkSubnetEthernet('128.148.33.23', '8:0:20:89:f3:25')
        self.assertEquals(None, result)
        result = NetworkRecord.checkSubnetEthernet('128.148.31.23', '8:0:20:89:f3:25',
                                         mothraNid)
        self.assertEquals(None, result)
        result = NetworkRecord.checkSubnetEthernet('128.148.31.26', '8:0:20:89:f3:25',
                                         mothraNid)
        self.assertEquals(None, result)
    
def suite():
    suite = unittest.TestSuite()
    suite.addTest(unittest.makeSuite(IPTests, 'test'))
    suite.addTest(unittest.makeSuite(EthernetTests, 'test'))
    suite.addTest(unittest.makeSuite(HostnameTests, 'test'))
    suite.addTest(unittest.makeSuite(UtilTests, 'test'))
    suite.addTest(unittest.makeSuite(StatusTests,'test'))
    return suite

if __name__ == "__main__":
    unittest.main()   

