#!/usr/bin/python

# $Id$

import unittest
import sys
import Main
import globals

class CleanDB:
    def getDirtyTables(self):
        return []

class DirtyDB:
    def getDirtyTables(self):
        return [ 'ipaddr' ]
    
class MainTest(unittest.TestCase):
    def testBadArgs(self):
        try:
            Main.getTargetsToBuild(None, ['foobar'])
            self.fail("Didn't get expected exit")
        except SystemExit:
            pass

        l = ['dns', 'dhcp', 'frobz']
        try:
            Main.getTargetsToBuild(None, l)
            self.fail("Didn't get expected exit")
        except SystemExit:
            pass

    def testGoodArgs(self):
        try:
            Main.getTargetsToBuild(None, ['all'])
        except SystemExit:
            self.fail("Exited with valid args")

        l = ['dns', 'dhcp']
        try:
            Main.getTargetsToBuild(None, l)
        except SystemExit:
            self.fail("Exited with valid args")

        l = ['dns', 'all', 'frobz']
        try:
            Main.getTargetsToBuild(None, l)
        except SystemExit:
            self.fail("Exited with valid args:")

    def testUnique(self):
        import Utils
        l = [ 1, 2, 2, 3 ]
        x = Utils.unique(l)
        self.assertEquals([1,2,3], x)

        l = [3,2,1]
        x = Utils.unique(l)
        self.assertEquals([1,2,3], x)

        l = ['one', 'two', 'three', 'one']
        x = Utils.unique(l)
        self.assertEquals(['one', 'three', 'two'], x)

    def testDebug(self):
        Main.processCommandOptions(['-d', '1', 'all'])
        self.assertEquals(1, globals.debug)
        globals.debug = 0
        Main.processCommandOptions(['all'])
        self.assertEquals(0, globals.debug)

    def testDirty(self):
        try:
            targets = Main.getTargetsToBuild(CleanDB(), [])
        except SystemExit:
            self.fail("Exited with valid args")
        self.assertEquals([], targets)

        try:
            targets = Main.getTargetsToBuild(DirtyDB(), [])
        except SystemExit:
            self.fail("Exited with valid args")
        self.assertEquals(['bootparams', 'dns', 'hosts', 'tftpboot'],
                           targets)
                    
def suite():
    return unittest.makeSuite(MainTest, 'test')
