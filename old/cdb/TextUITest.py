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
        self.assertRaises(SystemExit, t.main, [])
        self.assertRaises(SystemExit, t.main, ['bletch'])
        self.assertRaises(SystemExit, t.main, ['bletch', 'hostname'])
        self.assertRaises(SystemExit, t.main, ['profile'])
        self.assertRaises(NotImplementedError, t.main, ['profile', 'hostname'])

    def testMakeList(self):
        t = TextUI.TextUI('testprogram')
        l = t.makeList("one, two, three")
        self.assertEquals(['one', 'two', 'three'], l)
        l = t.makeList(" one , two , three ")
        self.assertEquals(['one', 'two', 'three'], l)
        l = t.makeList(" one ,  , three ")
        self.assertEquals(['one', 'three'], l)


    def testJoinList(self):
        t = TextUI.TextUI('testprogram')
        self.assertEquals(None, t.joinList(None))
        self.assertEquals('', t.joinList([]))
        self.assertEquals('one', t.joinList(['one']))
        self.assertEquals('one,two', t.joinList(['one', 'two']))
        

def suite():
    return unittest.makeSuite(TextUITest,'test')
