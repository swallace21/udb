import unittest
import TextUI

class TextUITest(unittest.TestCase):
    def testVirtual(self):
        t = TextUI.TextUI('testprogram')
        self.assertRaises(NotImplementedError, t.insert)
        self.assertRaises(NotImplementedError, t.profile)
        self.assertRaises(NotImplementedError, t.delete)
        self.assertRaises(NotImplementedError, t.modify)

    def testMain(self):
        t = TextUI.TextUI('testprogram')
        self.assertRaises(SystemExit, t.main, [None])
        self.assertRaises(SystemExit, t.main, ['bletch'])
        self.assertRaises(SystemExit, t.main, ['bletch', 'hostname'])
        self.assertRaises(SystemExit, t.main, ['profile'])
        self.assertRaises(NotImplementedError, t.main, ['profile', 'hostname'])

def suite():
    return unittest.makeSuite(TextUITest,'test')
