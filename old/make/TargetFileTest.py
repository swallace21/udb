#!/usr/bin/python

# $Id$

import unittest
import TargetFile
import globals

class StringOut:
    def __init__(self):
        self.buffer = []

    def write(self, st):
        self.buffer.append(st)

    def getData(self):
        return self.buffer

    def reset(self):
        self.buffer = []

class DummyDB:
    def getHostnameEthernet(self):
        return [ ('12:34:56:78:90:ab', 'hostname'),
                 ('08:00:20:12:23:34', 'foobar')
                 ]
        
class TargetFileTest(unittest.TestCase):
    def testGetSetBuildDir(self):
        TargetFile.Target.clearBuildDir()
        globals.debug = 0
        self.assertEquals(globals.temp_dir,
                          TargetFile.Target.getBuildDir())

        TargetFile.Target.clearBuildDir()
        globals.debug = 1
        self.assertEquals('.' + globals.temp_dir,
                          TargetFile.Target.getBuildDir())

        TargetFile.Target.setBuildDir('/blort')
        self.assertEquals('./blort', TargetFile.Target.getBuildDir())

        TargetFile.Target.clearBuildDir()
        globals.debug = 0
        TargetFile.Target.setBuildDir('/blort')
        self.assertEquals('/blort', TargetFile.Target.getBuildDir())
        TargetFile.Target.clearBuildDir()

    def testGetIncludePath(self):
        globals.debug = 0
        t = TargetFile.TargetFile(None)
        self.assertEquals('/tstaff/include/cdb', t.getIncludePath())

        globals.debug = 1
        self.assertEquals('./include', t.getIncludePath())

    def testEthersTarget(self):
        TargetFile.Target.clearBuildDir()
        globals.debug = 0
        eth = TargetFile.Ethers(None)
        t = eth.getBuildFile()
        self.assertEquals('/tmp/ethers', t)

        TargetFile.Target.clearBuildDir()
        globals.debug = 1
        t = eth.getBuildFile()
        self.assertEquals('./tmp/ethers', t)

    def testEthersDynamic(self):
        eth = TargetFile.Ethers(DummyDB())

        out = StringOut()
        eth.addDynamicData(out)
        lines = ''.join(out.getData())
        self.assertEquals('12:34:56:78:90:ab\thostname\n08:00:20:12:23:34\tfoobar\n', lines)

    def testBuildEthers(self):
        globals.debug = 1
        eth = TargetFile.Ethers(DummyDB())
        eth.build()
        
    def testIncludeStatic(self):
        out = StringOut()
        t = TargetFile.TargetFile(None)
        t.includeFile('nosuchfile', out)
        lines = out.getData()
        self.assertEquals(0, len(lines))

        out.reset()
        t.includeFile('testdata/empty', out)
        lines = out.getData()
        self.assertEquals(0, len(lines))

        out.reset()
        t.includeFile('testdata/one', out)
        lines = out.getData()
        self.assertEquals(1, len(lines))
        self.assertEquals('1', lines[0])

        out.reset()
        t.includeFile('testdata/oneline', out)
        lines = out.getData()
        self.assertEquals(1, len(lines))
        self.assertEquals('one line\n', lines[0])

        out.reset()
        t.includeFile('testdata/cdb_ethers.in', out)
        lines = out.getData()
        self.assertEquals(1, len(lines))
        self.assertEquals('0:40:9d:21:f9:5e        portserver\n',
                          lines[0])

        def testMapList(self):
            self.assertEquals(['bootparams', 'dhcp', 'dns', 'ethers', 'hosts',
                               'hosts.equiv', 'netgroup', 'tftpboot'],
                              TargetFile.getAllTargets())
            self.assertNotEquals(['bootparams', 'dhcp', 'dns', 'ethers',
                                  'hosts', 'hosts.equiv', 'netgroup',
                                  'tftpboot', 'foobar'],
                                 TargetFile.getAllTargets())

    def testBuildDNS(self):
        dns = TargetFile.DNS(None)
        l = dns.makeFileList()
        self.assertEquals(['db.cs', 'db.128.148.31', 'db.128.148.32', 'db.128.148.33', 'db.128.148.37', 'db.128.148.38'], l)

def suite():
    return unittest.makeSuite(TargetFileTest, 'test')
