#!/usr/bin/python

import unittest
import NetworkRecord

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
    suite.addTest(unittest.makeSuite(StatusTests,'test'))
    return suite

if __name__ == "__main__":
    unittest.main()   

