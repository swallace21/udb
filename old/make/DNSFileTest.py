# $Id$

import unittest
import DNSFile

class DNSFileTest(unittest.TestCase):
    def testGetSerial(self):
        dns = DNSFile.DNSFile(None)
        serial = dns.getSerialNumber('testdata/db.cs')
        self.assertEquals(3065, serial)

        serial = dns.getSerialNumber('/etc/motd')
        self.assertEquals(None, serial)

        serial = dns.getSerialNumber('testdata/db.cs-bad')
        self.assertEquals(None, serial)

def suite():
    return unittest.makeSuite(DNSFileTest, 'test')
