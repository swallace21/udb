# $Id$

import os
import os.path
import errno
import filecmp
import unittest
import Utils

def createFile(filename):
    file(filename, 'w').close()

def fillDir(dirname):
    for i in xrange(15):
        createFile("%s/file%d" % (dirname,i))
        os.mkdir("%s/dir%d" % (dirname,i))
    
class UtilsTest(unittest.TestCase):
    def testCreateFile(self):
        filename = '/tmp/foobarbaz'
        self.assert_(not os.path.exists(filename), "%s exists" % filename)
        createFile(filename)
        self.assert_(os.path.exists(filename))
        os.unlink(filename)
        
    def testRecursiveRemove_SingleFile(self):
        filename = '/tmp/foobarbaz'
        self.assert_(not os.path.exists(filename), 'temp file already exists')
        createFile(filename)
        self.assert_(os.path.exists(filename), "didn't create temp file")
        Utils.deleteHierarchy(filename)
        self.assert_(not os.path.exists(filename), "remove failed")

    def testRecursiveRemove_SingleDir(self):
        filename = '/tmp/foobarbaz'
        self.assert_(not os.path.exists(filename), 'temp dir already exists')
        os.mkdir(filename)
        self.assert_(os.path.exists(filename), "didn't create temp dir")
        Utils.deleteHierarchy(filename)
        self.assert_(not os.path.exists(filename), "remove failed")

    def testRecursiveRemove_DirWithFile(self):
        dirname = '/tmp/foobarbaz'
        self.assert_(not os.path.exists(dirname), 'temp dir already exists')
        os.mkdir(dirname)
        self.assert_(os.path.exists(dirname), "didn't create temp dir")
        filename = dirname + '/blort'
        createFile(filename)
        self.assert_(os.path.exists(filename), "didn't create temp file")
        Utils.deleteHierarchy(dirname)
        self.assert_(not os.path.exists(dirname), "didn't create temp dir")

    def testRecursiveRemove(self):
        dirname = '/tmp/foobarbaz'
        self.assert_(not os.path.exists(dirname), 'temp dir already exists')
        os.mkdir(dirname)
        self.assert_(os.path.exists(dirname), "didn't create temp dir")
        fillDir(dirname)
        fillDir(dirname + '/dir1')
        fillDir(dirname + '/dir1/dir1')
        fillDir(dirname + '/dir1/dir1/dir1')
        self.assert_(os.path.exists(dirname + '/dir1/dir1/dir1/file1'))
        Utils.deleteHierarchy(dirname)
        self.assert_(not os.path.exists(dirname), "remove failed")

    def testSimpleMove(self):
        src = '/var/tmp/foobar'
        dst = '/var/tmp/baz'
        createFile(src)
        self.assert_(os.path.exists(src), "didn't source file")
        Utils.moveFile(src, dst)
        self.assert_(os.path.exists(dst), "dest file doesn't exist")
        self.assert_(not os.path.exists(src), "source file exists")

    def testSimpleMoveFails(self):
        # No source file
        src = '/var/tmp/nosuchfile'
        dst = '/var/tmp/baz'
        try:
            Utils.moveFile(src, dst)
            self.fail("Didn't get OSError")
        except OSError, e:
            self.assertEquals(errno.ENOENT, e.errno)

        # No perms on dest. file
        src = '/var/tmp/foobar'
        dst = '/etc/baz'
        createFile(src)
        try:
            Utils.moveFile(src, dst)
            self.fail("Didn't get OSError")
        except IOError, e:
            self.assertEquals(errno.EACCES, e.errno)

    def testDifferentFileSystemMove(self):
        src = './tmp/foobar'
        dst = '/tmp/baz'
        createFile(src)
        self.assert_(os.path.exists(src), "didn't create source file")
        Utils.moveFile(src, dst)
        self.assert_(os.path.exists(dst), "dest file doesn't exist")
        self.assert_(not os.path.exists(src), "source file exists")

    def testMoveLink(self):
        src = './tmp/motd-link'
        dst = '/tmp/motd-link'
        if os.path.exists(dst):
            os.unlink(dst)
        os.symlink('/etc/motd', src)
        self.assert_(os.path.exists(src), "didn't create source file")
        Utils.moveFile(src, dst)
        self.assert_(os.path.exists(dst), "dest file doesn't exist")
        self.assert_(not os.path.exists(src), "source file exists")
        self.assert_(os.path.islink(dst), "Moved link isn't symlink")
            
    def testRemoteMove(self):
        src = './tmp/mvtoremote'
        dst = 'discordia.cs.brown.edu:/tmp/baz'
        createFile(src)
        self.assert_(os.path.exists(src), "didn't create source file")
        Utils.moveFile(src, dst)
        # Should really make sure remote file exists
        self.assert_(not os.path.exists(src), "source file exists")

    def testRemoteMoveFail(self):
        src = '/var/tmp/foobar'
        dst = 'discordia.cs.brown.edu:/etc/shadow'
        createFile(src)
        self.assert_(os.path.exists(src), "didn't create source file")
        try:
            Utils.moveFile(src, dst)
            self.fail("Didn't get ssh error")
        except Utils.SshError:
            pass
        self.assert_(os.path.exists(src), "source file exists")
        
        
    def testIsRemote(self):
        self.assert_(not Utils.isRemote('/foobar/baz'))
        self.assert_(not Utils.isRemote('baz'))
        self.assert_(not Utils.isRemote('/foobar/:baz'))
        
        self.assert_(Utils.isRemote('dis:/foobar'))
        self.assert_(Utils.isRemote('dis:foobar'))

    def testCopyFile(self):
        src = '/etc/motd'
        dst = '/tmp/motd'
        Utils.copyFile(src, dst)
        status = file
        self.assertEquals(1 ,filecmp.cmp(src, dst, 0))

    def testCopyFileFail(self):
        src = '/etc/motd'
        dst = '/etc/shadow'
        try:
            Utils.copyFile(src, dst)
        except IOError, e:
            self.assertEquals(errno.EACCES, e.errno)
        
        src = '/etc/shadow'
        dst = '/tmp/shadow-copy'
        try:
            Utils.copyFile(src, dst)
        except IOError, e:
            self.assertEquals(errno.EACCES, e.errno)

        src = '/aljdfhlajkdfh'
        dst = '/tmp/junk-copy'
        try:
            Utils.copyFile(src, dst)
        except IOError, e:
            self.assertEquals(errno.ENOENT, e.errno)

def suite():
    return unittest.makeSuite(UtilsTest, 'test')

