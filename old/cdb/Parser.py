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

class ParseError(Exception):
    pass

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

    def checkField(self, field):
        if not field:
            raise ParseError, 'Empty field'
        
    def getField(self):
        if self.currentPos >= len(self.st):
            return None
        
        self.skipWhitespace()
        startpos = self.currentPos
        while self.currentPos < len(self.st):
            if self.st[self.currentPos] == '=':
                field = self.st[startpos:self.currentPos].rstrip()
                self.checkField(field)
                return Token(TOKEN_FIELD,
                             self.st[startpos:self.currentPos].rstrip())
            self.currentPos += 1
        field = self.st[startpos:-1]
        self.checkField(field)
        return Token(TOKEN_FIELD, self.st[startpos:-1])

    def checkData(self, data):
        if not data:
            raise ParseError, 'Empty data'
        
    def getData(self):
        self.skipWhitespace()
        startpos = self.currentPos
        while self.currentPos < len(self.st):
            if self.st[self.currentPos] in '=&|()':
                data = self.st[startpos:self.currentPos].rstrip()
                self.checkData(data)
                return Token(TOKEN_DATA,
                             self.st[startpos:self.currentPos].rstrip())
            self.currentPos += 1
        data = self.st[startpos:]
        self.checkData(data)
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
            raise ParseError, 'Empty expression'
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
        self.initSearchStrings()

    def getSQL(self):
        self.visit(self.tree)
        return self.tree.st

    def visit(self, tree):
        if tree is None:
            return
        self.visit(tree.left)
        self.visit(tree.right)
        if tree.data.type == TOKEN_EQUALS:
            self.do_equal(tree)
        if tree.data.type == TOKEN_BINOP:
            self.do_op(tree)

    def do_equal(self, node):
        raise NotImplementedError

    def do_and(self, node):
        raise NotImplementedError

    def initSearchStrings(self):
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
    def initSearchStrings(self):
        self.field2sql = {
            'hostname': self.makeSqlString('network', 'hostname'),
            'ethernet': self.makeSqlString('network', 'text(ethernet)'),
            'mxhost': self.makeSqlString('network', 'mxhost'),
            'comment': self.makeSqlString('network', 'comment'),
            'id': self.makeSqlStringNum('network', 'id'),
            'nid': self.makeSqlStringNum('network', 'nid'),
            'ipaddr': self.makeSqlString('network', 'text(ipaddr)'),
            'status': self.makeSqlString('status', 'status'),
            'os': "SELECT nid FROM network, os_type WHERE os_type.os ~* '%s' AND os_type.id = network.id",
            'arch': "SELECT nid FROM network, architecture WHERE architecture.arch ~* '%s' AND architecture.id = network.id",
            'lid': "SELECT nid FROM network, eq WHERE lid ~* '%s' AND network.id = eq.id",
            'floor': "SELECT n.nid FROM network n, eq e, location l WHERE l.floor = '%s' AND e.lid = l.lid AND e.id = n.id",
            'building': "SELECT n.nid FROM network n, eq e, location l WHERE l.building ~* '%s' AND e.lid = l.lid AND e.id = n.id",
            'alias': "SELECT DISTINCT network.nid FROM network, aliases WHERE aliases.alias ~* '%s' AND network.nid = aliases.nid",
            'netgroup': "SELECT nid FROM netgroups WHERE netgroup ~* '%s'",
            'subnet': "SELECT nid FROM network WHERE bcast = '128.148.%s.255/24'"
            }
        self.field2sql['host'] = self.field2sql['hostname']
        self.field2sql['ether'] = self.field2sql['ethernet']
        self.field2sql['mac'] = self.field2sql['ethernet']
        self.field2sql['mx'] =  self.field2sql['mxhost']
        self.field2sql['ip'] =  self.field2sql['ipaddr']
        self.field2sql['ip_addr'] = self.field2sql['ipaddr']
        self.field2sql['os_type'] = self.field2sql['os']
        self.field2sql['hw_arch'] = self.field2sql['arch']
        self.field2sql['aliases'] = self.field2sql['alias']
        for k in ['netgroups', 'group', 'supp_grps', 'prim_grp']:
            self.field2sql[k] = self.field2sql['netgroup']        
        
    def makeSqlString(self, table, field):
        return "SELECT nid FROM %s WHERE %s ~* '%%s'" % (table, field)
    def makeSqlStringNum(self, table, field):
        return "SELECT nid FROM %s WHERE %s = %%s" % (table, field)
        
    def do_and(self, node):
        node.st = node.right.st + ' AND nid IN ( ' + node.left.st + ' )'
    
    def do_equal(self, node):
        field = node.left.data.value
        data = node.right.data.value
        if self.field2sql.has_key(field):
            node.st = self.field2sql[field] % ( data )
        else:
            raise ParseError, "Unrecognized search field: %s" % field
            
class IdSql(SqlGenerator):
    def __init__(self, parseTree, eqTable = 'equipment'):
        self.eqTable = eqTable;
        SqlGenerator.__init__(self, parseTree)
        
    def initSearchStrings(self):
        self.field2sql = {
            'hostname': self.makeSqlString('network', 'hostname'),
            'descr': self.makeSqlString(self.eqTable, 'descr'),
            'serial_num': self.makeSqlString(self.eqTable, 'serial_num'),
            'inventory_num': self.makeSqlString(self.eqTable, 'inventory_num'),
            'comment': self.makeSqlString(self.eqTable, 'comment'),
            'lid': self.makeSqlString(self.eqTable, 'lid'),
            'id': self.makeSqlStringNum(self.eqTable, 'id'),
            'type': self.makeSqlString('usage', 'usage'),
            'po_num': self.makeSqlString('purchase', 'po_num'),
            'po_date': self.makeSqlString('purchase', 'date'),
            'po_price': self.makeSqlStringNum('purchase', 'price'),
            'po_comment': self.makeSqlString('purchase', 'comment'),
            'arch': self.makeSqlString('architecture', 'arch'),
            'users': self.makeSqlString('users', 'users'),
            'inst_date': self.makeSqlString('installation', 'date'),
            'inst_comment': self.makeSqlString('installation', 'comment'),
            'cpu': self.makeSqlString('config', 'cpu'),
            'memory': self.makeSqlString('config', 'memory'),
            'disk': self.makeSqlString('config', 'disk'),
            'graphics': self.makeSqlString('config', 'graphics'),
            'conf_comment': self.makeSqlString('config', 'comment'),
            'floor': "SELECT e.id FROM %s e, location l WHERE l.floor = '%%s' AND e.lid = l.lid" % self.eqTable,
            'building': "SELECT e.id FROM %s e, location l WHERE l.building ~* '%%s' AND e.lid = l.lid" % self.eqTable,
            }
        self.field2sql['desc'] = self.field2sql['descr']
        self.field2sql['serial'] = self.field2sql['serial_num']
        self.field2sql['inv'] = self.field2sql['inventory_num']
        self.field2sql['inv_num'] = self.field2sql['inventory_num']
        self.field2sql['ponum'] = self.field2sql['po_num']
        self.field2sql['podate'] = self.field2sql['po_date']
        self.field2sql['price'] = self.field2sql['po_price']
        self.field2sql['poprice'] = self.field2sql['po_price']
        self.field2sql['pocomment'] = self.field2sql['po_comment']
        self.field2sql['hw_arch'] = self.field2sql['arch']
        self.field2sql['install_date'] = self.field2sql['inst_date']
        self.field2sql['instdate'] = self.field2sql['inst_date']
        self.field2sql['instcomment'] = self.field2sql['inst_comment']
        self.field2sql['mem'] = self.field2sql['memory']
        self.field2sql['gfx'] = self.field2sql['graphics']
        self.field2sql['config_comment'] = self.field2sql['conf_comment']
        
    def makeSqlString(self, table, field):
        return "SELECT id FROM %s WHERE %s ~* '%%s'" % (table, field)

    def makeSqlStringNum(self, table, field):
        return "SELECT id FROM %s WHERE %s = %%s" % (table, field)
    
    def do_and(self, node):
        node.st = node.right.st + ' AND id IN ( ' + node.left.st + ' )'

    def do_equal(self, node):
        field = node.left.data.value
        data = node.right.data.value
        if self.field2sql.has_key(field):
            if field.find('date') >= 0 :
                data = data.replace('/', '-')
            node.st = self.field2sql[field] % ( data )
        else:
            raise ParseError, "Unrecognized search field: %s" % field

class ActiveIdSql(IdSql):
    def __init__(self, parseTree):
        IdSql.__init__(self, parseTree, 'eq')
    
class SurplusIdSql(IdSql):
    def __init__(self, parseTree):
        IdSql.__init__(self, parseTree, 'surplus')


class FullIdSql(IdSql):
    def __init__(self, parseTree):
        IdSql.__init__(self, parseTree, 'equipment')
