# $Id$

import unittest
import udb
import Search

mothraNid = 109
discordiaNid = 344
surpId = 2147

class SearchTest(unittest.TestCase):
    def testSQL(self):
        search = Search.CdbSearch(udb.getConnection())
        search.parse('hostname=mothra')
        sql = search.getSql()
        self.assertEquals("SELECT nid FROM network WHERE hostname ~* 'mothra'",
                          sql)

    def testRun(self):
        search = Search.CdbSearch(udb.getConnection())
        result = search.run('hostname=mothra')
        self.assertEquals(1, len(result))
        self.assertEquals(mothraNid, result[0])

    def testOr(self):
        search = Search.CdbSearch(udb.getConnection())
        result = search.run('hostname=mothra||hostname=discordia')
        self.assertEquals(2, len(result))
        self.assertEquals([mothraNid, 344], result)

    def testAnd(self):
        search = Search.CdbSearch(udb.getConnection())
        result = search.run('hostname=mothra&&ipaddr=128.148.31')
        self.assertEquals(1, len(result))
        self.assertEquals([mothraNid], result)

    def testArch(self):
        search = Search.CdbSearch(udb.getConnection())
        result = search.run('hostname=mothra&&arch=sun')
        self.assertEquals(1, len(result))
        self.assertEquals([mothraNid], result)

    def testActiveId(self):
        search = Search.EdbSearch(udb.getConnection())
        result = search.run('serial=724f154c')
        self.assertEquals(1, len(result))
        self.assertEquals([mothraNid], result)
        result = search.run('serial=wf84105048&&active=t')
        self.assertEquals(0, len(result))
        
    def testSurplusId(self):
        search = Search.EdbSearch(udb.getConnection())
        result = search.run('serial=wf84105048&&surplus=t')
        self.assertEquals(1, len(result))
        self.assertEquals([surpId], result)
        result = search.run('serial=724f154c&&surplus=t')
        self.assertEquals(0, len(result))

def suite():
    return unittest.makeSuite(SearchTest,'test')
