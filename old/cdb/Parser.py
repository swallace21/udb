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
        raise NotImplementedError

    def do_and(self, node):
        raise NotImplementedError
        
    def do_op(self, node):
        if node.data.value == '&&':
            self.do_and(node)
        elif node.data.value == '||':
            self.do_or(node)
        else:
            assert 0, 'NOT REACHED'

    def do_or(self, node):
        node.st = node.right.st + ' UNION ' + node.left.st

class NidSql(SqlGenerator):
    def do_and(self, node):
        node.st = node.right.st + ' AND nid IN ( ' + node.left.st + ' )'
    
    def do_equal(self, node):
        field = node.left.data.value
        data = node.right.data.value
        if field in ('hostname', 'id', 'ethernet',
                     'mxhost', 'comment', 'nid'):
            node.st = "SELECT nid FROM network WHERE %s ~* '%s'"\
                      % (field, data)
        elif field == 'ipaddr':
            node.st = "SELECT nid FROM network WHERE text(ipaddr) ~* '%s'" % data
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
            node.st = "SELECT DISTINCT network.nid FROM network, aliases WHERE aliases.alias ~* '%s' AND network.nid = aliases.nid" % (data)
        elif field in [ 'group', 'netgroup', 'netgroups', 'supp_grps',
                        'prim_grp' ]:
            node.st = "SELECT nid FROM network WHERE netgroup ~* '%s' UNION SELECT nid FROM netgroups WHERE netgroup ~* '%s'" % (data, data)
        else:
            print "Warning: Unrecognized search field: %s" % field

class IdSql(SqlGenerator):
    def makeSt(self, table, field, data):
        return "SELECT id FROM %s WHERE %s ~* '%s'" % (table, field, data)

    def makeNum(self, table, field, data):
        return "SELECT id FROM %s WHERE %s = %s" % (table, field, data)
    
    def do_and(self, node):
        node.st = node.right.st + ' AND id IN ( ' + node.left.st + ' )'

    def do_equal(self, node):
        field = node.left.data.value
        data = node.right.data.value
        if field in ('descr', 'lid', 'serial_num', 'inventory_num',
                     'comment'):
            node.st = self.makeSt('equipment', field, data)
        elif field == 'id':
            node.st = self.makeNum('equipment', 'id', data)
        elif field == 'desc':
            node.st = self.makeSt('equipment', 'descr', data)
        elif field == 'serial':
            node.st = self.makeSt('equipment', 'serial_num', data)
        elif field == 'inv_num' or field == 'inv':
            node.st = self.makeSt('equipment', 'inventory_num', data)
        elif field == 'type':
            node.st = self.makeSt('usage', 'usage', data)
        elif field == 'ponum' or field == 'po_num':
            node.st = self.makeSt('purchase', 'po_num', data)
        elif field == 'podate' or field == 'po_date':
            node.st = self.makeSt('purchase', 'date', data.replace('/', '-'))
        elif field == 'poprice' or field == 'po_price' or field == 'price':
            node.st = self.makeNum('purchase', 'price', data)
        elif field == 'pocomment' or field == 'po_comment':
            node.st = self.makeSt('purchase', 'comment', data)
        elif field == 'arch' or field == 'hw_arch':
            node.st = self.makeSt('architecture', 'arch', data)
        elif field == 'users' or field == 'user':
            node.st = self.makeSt('users', 'users', data)
        elif field == 'install_date' or field == 'inst_date' or field == 'instdate':
            node.st = self.makeSt('installation', 'date', data.replace('/', '-'))
        elif field == 'install_comment' or field == 'inst_comment' or field == 'commentdate':
            node.st = self.makeSt('installation', 'comment', data)
        else:
            print "Warning: Unrecognized search field: %s" % field
