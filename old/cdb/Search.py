# $Id$

import Parser

class Search:
    def __init__(self, dbConn):
        self.dbConn = dbConn

    def run(self, query):
        self.parse(query)
        cursor = self.dbConn.cursor()
        cursor.execute(self.getSql())
        return [ x[0] for x in cursor.fetchall() ]

    def parse(self, query):
        lex = Parser.Lexer(query)
        tree = lex.getExpression()
        self.sql = Parser.SqlGenerator(tree)
        
    def getSql(self):
        return self.sql.getSQL()
