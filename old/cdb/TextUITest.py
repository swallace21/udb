import unittest
import TextUI

availableIP = '128.148.38.243'

class TextUITest(unittest.TestCase):
    def testVirtual(self):
        t = TextUI.TextUI('testprogram')
        self.assertRaises(NotImplementedError, t.insert, None)
        self.assertRaises(NotImplementedError, t.profile, None)
        self.assertRaises(NotImplementedError, t.delete, None)
        self.assertRaises(NotImplementedError, t.modify, None)

    def testMain(self):
        t = TextUI.TextUI('testprogram')
        self.assertRaises(SystemExit, t.main, [])
        self.assertRaises(SystemExit, t.main, ['bletch'])
        self.assertRaises(SystemExit, t.main, ['bletch', 'hostname'])
        self.assertRaises(SystemExit, t.main, ['profile'])
        self.assertRaises(NotImplementedError, t.main, ['profile', 'hostname'])

    def test_makeList(self):
        t = TextUI.TextUI('testprogram')
        self.assertEquals([], t.makeList(''))
        self.assertEquals(['one'], t.makeList('one'))
        st = 'one,two,three'
        l = ['one', 'two', 'three']
        self.assertEquals(l, t.makeList(st))
        st = 'one , two, three'
        self.assertEquals(l, t.makeList(st))
        st = ' one , two, three  '
        self.assertEquals(l, t.makeList(st))
        st = 'one,,two,three'
        l = ['one', 'two', 'three']
        self.assertEquals(l, t.makeList(st))
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

    def test_pickIp(self):
        t = TextUI.TextUI('testprogram')
        ip = t.pickIp('128.148.34');
        self.assertEquals('128.148.34.6', ip)
        ip = t.pickIp('128.148.38');
        self.assertEquals(availableIP, ip)

    def test_gethostnum(self):
        t = TextUI.TextUI('testprogram')
        self.assertEquals(1, t.gethostnum('128.148.34.1', '128.148.34'))
        self.assertEquals(22, t.gethostnum('128.148.34.22', '128.148.34'))
        self.assertEquals(222, t.gethostnum('128.148.34.222', '128.148.34'))
        self.assertEquals(222, t.gethostnum('1.1.3.222', '1.1.3'))

    def test_isYes(self):
        t = TextUI.TextUI('testprogram')
        self.assert_(t.isYes('y'))
        self.assert_(t.isYes('ye'))
        self.assert_(t.isYes('yes'))
        self.assert_(t.isYes('Y'))
        self.assert_(t.isYes('YE'))
        self.assert_(t.isYes('YES'))

        self.assert_(not t.isYes('n'))
        self.assert_(not t.isYes('no'))
        self.assert_(not t.isYes('N'))
        self.assert_(not t.isYes('NO'))
        self.assert_(not t.isYes('YESn'))
        self.assert_(not t.isYes('x'))

def suite():
    return unittest.makeSuite(TextUITest,'test')
