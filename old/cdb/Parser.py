#!/usr/bin/python

# $Id$

# GRAMMAR:
# -------
#
# expr	::=	term
# 	|	term bin_op expr
# 
# term	::=	'(' expr ')'
# 	|	field '=' value
# 
# bin_op	::=	'&&'
# 	|	'||'
#

import sys

TOKEN_FIELD = 0
TOKEN_DATA = 1
TOKEN_BINOP = 2
TOKEN_EQUALS = 3
    
class Token:
    def __init__(self, token_type, value):
        self.type = token_type
        self.value = value

    def __repr__(self):
        return "%d: %s" % (self.type, self.value)

class Node:
    def __init__(self, token):
        self.data = token
        self.left = None
        self.right = None
        self.st = 'Err'

    def setLeft(self, node):
        self.left = node

    def setRight(self, node):
        self.right = node

class Lexer:
    def __init__(self, st):
        self.st = st
        self.currentPos = 0

    def skipWhitespace(self):
        while self.currentPos < len(self.st):
            if not self.st[self.currentPos].isspace():
                break
            self.currentPos += 1
            
    def getTerm(self):
        self.skipWhitespace()
        if self.st[self.currentPos] == '(':
            self.currentPos += 1
            node = self.getExpression()
            self.skipWhitespace()
            if self.st[self.currentPos] == ')':
                self.currentPos += 1
                return node
            return None
        
        f = self.getField()
        if f is None:
            return None
        e = self.getEquals()
        d = self.getData()

        node = Node(e)
        node.setLeft(Node(f))
        node.setRight(Node(d))
        return node
        
    def getField(self):
        if self.currentPos >= len(self.st):
            return None
        
        self.skipWhitespace()
        startpos = self.currentPos
        while self.currentPos < len(self.st):
            if self.st[self.currentPos] == '=':
                return Token(TOKEN_FIELD,
                             self.st[startpos:self.currentPos].rstrip())
            self.currentPos += 1
        return Token(TOKEN_FIELD, self.st[startpos:-1])

    def getData(self):
        self.skipWhitespace()
        startpos = self.currentPos
        while self.currentPos < len(self.st):
            if self.st[self.currentPos] in '=&|()':
                return Token(TOKEN_DATA,
                             self.st[startpos:self.currentPos].rstrip())
            self.currentPos += 1
        return Token(TOKEN_DATA, self.st[startpos:])

    def getEquals(self):
        self.skipWhitespace()
        if self.st[self.currentPos] == '=':
            self.currentPos += 1
            return Token(TOKEN_EQUALS, '=')
        return None

    def getBinOp(self):
        self.skipWhitespace()
        if self.currentPos >= len(self.st):
            return None
        
        if self.st[self.currentPos] == '|' and self.st[self.currentPos+1] == '|':
            self.currentPos += 2
            return Token(TOKEN_BINOP, '||')

        if self.st[self.currentPos] == '&' and self.st[self.currentPos+1] == '&':
            self.currentPos += 2
            return Token(TOKEN_BINOP, '&&')
        return None

    def getExpression(self):
        if self.currentPos >= len(self.st):
            return

        termNode = self.getTerm()
        tok = self.getBinOp()
        if not tok:
            return termNode
        opNode = Node(tok)
        opNode.setLeft(termNode)
        opNode.setRight(self.getExpression())
        return opNode

class SqlGenerator:
    def __init__(self, parseTree):
        self.tree = parseTree

    def getSQL(self):
        self.visit(self.tree)
        return self.tree.st

    def visit(self, tree, indent = ''):
        if tree is None:
            return
        child_indent = '  ' + indent
        self.visit(tree.left, child_indent)
        self.visit(tree.right, child_indent)
        if tree.data.type == TOKEN_EQUALS:
            self.do_equal(tree)
        if tree.data.type == TOKEN_BINOP:
            self.do_op(tree)

    def do_equal(self, node):
        field = node.left.data.value
        data = node.right.data.value
        if field in ('hostname', 'ipaddr', 'id', 'ethernet', 'netgroup',
                     'mxhost', 'comment', 'nid'):
            node.st = "SELECT nid FROM network WHERE %s ~* '%s'"\
                      % (field, data)
        elif field == 'os' or field == 'os_type':
            node.st = "SELECT nid FROM network, os_type WHERE os_type.os ~* '%s' AND os_type.id = network.id" % (data)
        elif field == 'arch' or field == 'hw_arch':
            node.st = "SELECT nid FROM network, architecture WHERE architecture.arch ~* '%s' AND architecture.id = network.id" % (data)
        elif field == 'lid':
            node.st = "SELECT nid FROM network, equipment WHERE lid ~* '%s' AND network.id = equipment.id" % (data)
        elif field == 'floor':
            node.st = "SELECT n.nid FROM network n, equipment e, location l WHERE l.floor = '%s' AND e.lid = l.lid AND e.id = n.id" % (data)
        elif field == 'building':
            node.st = "SELECT n.nid FROM network n, equipment e, location l WHERE l.building ~* '%s' AND e.lid = l.lid AND e.id = n.id" % (data)
        elif field == 'alias' or field == 'aliases':
            node.st = "SELECT network.nid FROM network, aliases WHERE aliases.alias ~* '%s' AND network.nid = aliases.nid" % (data)
        elif field in [ 'group', 'netgroup', 'netgroups', 'supp_grps',
                        'prim_grp' ]:
            node.st = "SELECT nid FROM network WHERE netgroup ~* %s UNION SELECT nid FROM netgroups WHERE netgroup ~* %s" % (data, data)
        else:
            pass

    def do_op(self, node):
        if node.data.value == '&&':
            self.do_and(node)
        elif node.data.value == '||':
            self.do_or(node)
        else:
            assert 0, 'NOT REACHED'

    def do_or(self, node):
        node.st = node.right.st + ' UNION ' + node.left.st

    def do_and(self, node):
        node.st = node.right.st + ' AND nid IN ( ' + node.left.st + ' )'


if __name__ == '__main__':
    #lex = Lexer('hostname=mothra')
    #lex = Lexer('hostname=mothra||hostname=foo')
    #lex = Lexer('(hostname=mothra||hostname=foo)')
    #lex = Lexer(' ethernet = 123 || ( hostname = mothra && hostname = foo ) ')
    #lex = Lexer('hostname=discordia||(room=123&&hostname=mothra)')
    #lex = Lexer('hostname=cslab&&ip_addr=128.148.33')
    #lex = Lexer('(hostname=cslab)&&hostname=10')
    lex = Lexer(sys.argv[1])
    tree = lex.getExpression()
    sql = SqlGenerator(tree)
    print sql.getSQL()
