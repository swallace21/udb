# $Id$

import Parser

ParseError = Parser.ParseError

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
        self.sql = self.getParser(tree)
        
    def getSql(self):
        return self.sql.getSQL()

    def getParser(self, tree):
        raise NotImplementedError

class CdbSearch(Search):
    def getParser(self, tree):
        return Parser.NidSql(tree)

class EdbSearch(Search):
    def getParser(self, tree):
        return Parser.ActiveIdSql(tree)

class SurplusSearch(Search):
    def getParser(self, tree):
        return Parser.SurplusIdSql(tree)

class FullSearch(Search):
    def getParser(self, tree):
        return Parser.FullIdSql(tree)
