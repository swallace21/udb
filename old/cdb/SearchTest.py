# $Id$

import unittest
import udb
import Search

class SearchTest(unittest.TestCase):
    def testSQL(self):
        search = Search.Search(udb.getConnection())
        search.parse('hostname=mothra')
        sql = search.getSql()
        self.assertEquals("SELECT nid FROM network WHERE hostname ~* 'mothra'",
                          sql)

    def testRun(self):
        search = Search.Search(udb.getConnection())
        result = search.run('hostname=mothra')
        self.assertEquals(1, len(result))
        self.assertEquals(94, result[0])

    def testOr(self):
        search = Search.Search(udb.getConnection())
        result = search.run('hostname=mothra||hostname=discordia')
        self.assertEquals(2, len(result))
        self.assertEquals([94, 480], result)

    def testAnd(self):
        search = Search.Search(udb.getConnection())
        result = search.run('hostname=mothra&&ipaddr=128.148.31')
        self.assertEquals(1, len(result))
        self.assertEquals([94], result)

def suite():
    return unittest.makeSuite(SearchTest,'test')
