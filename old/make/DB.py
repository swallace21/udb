# $Id$

try:
    import pgdb
    dbModule = pgdb
except ImportError:
    from pyPgSQL import PgSQL
    dbModule = PgSQL

class DBIter:
    def __init__(self, cursor):
        self.cursor = cursor
        self.nextRow = self.cursor.fetchone()

    def hasNext(self):
        return self.nextRow is not None

    def next(self):
        toReturn = self.nextRow
        self.nextRow = self.cursor.fetchone()
        return toReturn

class DB:
    def __init__(self):
        self.connection = dbModule.connect(database='udb',
                                           #host='db.cs.brown.edu',
                                           user='twh', password='changeme')

    def runQueuryAndReturnIter(self, sql):
        cursor = self.connection.cursor()
        cursor.execute(sql)
        return DBIter(cursor)

    def runQueryAndReturnList(self, sql):
        cursor = self.connection.cursor()
        cursor.execute(sql)
        return [ x[0] for x in cursor.fetchall() ]

    def runQueryAndReturnResult(self, sql):
        cursor = self.connection.cursor()
        cursor.execute(sql)
        return cursor.fetchall()        

    def close(self):
        self.connection.rollback()
        self.connection.close()

    def getHostnameEthernet(self):
        sql = """SELECT ethernet, hostname
                   FROM NETWORK
                   WHERE ethernet NOTNULL AND hostname NOTNULL
                   ORDER BY hostname"""
        return self.runQueryAndReturnResult(sql)

    def getEthernetNoIp(self):
        sql = """SELECT nid, ethernet, comment
                   FROM network
                   WHERE ethernet NOTNULL AND ipaddr ISNULL
                   ORDER BY nid"""
        return self.runQueryAndReturnResult(sql)

    def getDdhcp(self):
        sql = """SELECT network.nid, network.ethernet, network.comment
                   FROM network, netgroups, status
                   WHERE netgroups.netgroup = 'dynamic'
                     AND network.nid = netgroups.nid
                     AND status.nid = network.nid
                     AND status.status ~* '^active$'"""
        return self.runQueryAndReturnResult(sql)
    
    def getNetgroup(self, netgroup):
        sql = """SELECT nid FROM netgroups
                     WHERE netgroup = '%s'""" % (netgroup)
        return self.runQueryAndReturnList(sql)

    def getAllNetgroups(self):
        sql = """SELECT netgroup FROM netgroups GROUP BY netgroup 
                 ORDER BY netgroup"""
        return self.runQueryAndReturnList(sql)
        

    def getHostnamesInNetgroup(self, netgroup):
        sql = """SELECT network.hostname FROM network, netgroups
                   WHERE netgroups.netgroup = '%s'
                     AND network.nid = netgroups.nid
                     AND network.hostname NOTNULL
                   ORDER BY network.hostname""" % (netgroup)
        return self.runQueryAndReturnList(sql)

    def getAliases(self, nid):
        sql = """SELECT alias FROM aliases
                   WHERE nid = %d ORDER BY alias""" % nid
        return self.runQueryAndReturnList(sql)

    def getAliasCache(self):
        cache = {}
        cursor = self.connection.cursor()
        cursor.execute('SELECT nid, alias FROM aliases')
        while 1:
            r = cursor.fetchone()
            if not r:
                break
            (nid, name) = r
            if nid in cache:
                cache[nid].append(name)
            else:
                cache[nid] = [name]
        return cache

    def getHostfile(self):
        alias_cache = self.getAliasCache()
        result = []
        cursor = self.connection.cursor()
        sql = """SELECT nid, host(ipaddr), hostname
                   FROM network WHERE hostname NOTNULL AND ipaddr NOTNULL
                   ORDER BY ipaddr"""
        cursor.execute(sql)
        while 1:
            r = cursor.fetchone()
            if not r:
                break
            (nid, ip, host) = r
            aliases = []
            if nid in alias_cache:
                aliases = alias_cache[nid]
            result.append( (ip, host, aliases) )
        return result

    def getNetworkBootparams(self, nid):
        cursor = self.connection.cursor()
        cursor.execute("""SELECT id, host(ipaddr), hostname FROM network
                            WHERE nid = %d""" % (nid))
        return cursor.fetchone()

    def get_nid_ipaddr_hostname(self, group):
        sql = """SELECT nid, host(ipaddr), hostname FROM network
                   WHERE nid IN (
                     SELECT nid FROM netgroups
                       WHERE netgroup = '%s')
                   AND hostname NOTNULL and ipaddr NOTNULL""" % (group)
        return self.runQueuryAndReturnIter(sql)

    def getDNSData(self):
        sql = """SELECT nid, host(ipaddr), hostname, mxhost FROM network
                   WHERE hostname NOTNULL AND ipaddr NOTNULL
                   ORDER BY hostname"""
        return self.runQueuryAndReturnIter(sql)

    def getReverseDNS(self, subnet):
        sql = """SELECT host(ipaddr), hostname FROM network
                   WHERE ipaddr NOTNULL AND hostname NOTNULL
                     AND broadcast(ipaddr) = '128.148.%d.255/24'
                   ORDER BY ipaddr""" % subnet
        return self.runQueuryAndReturnIter(sql)

    def getOS(self, id):
        cursor = self.connection.cursor()
        cursor.execute("""SELECT os FROM os_type WHERE id = %d""" % id)
        return cursor.fetchone()[0]

    def getArch(self, id):
        cursor = self.connection.cursor()
        cursor.execute("""SELECT arch FROM architecture WHERE id = %d""" % id)
        return cursor.fetchone()[0]

    def getJSPaths(self, os):
        cursor = self.connection.cursor()
        cursor.execute("""SELECT netboot, install, jumpstart, cache
                            FROM js_paths WHERE os = '%s'""" % os)
        return cursor.fetchone()

    def getFAIConfigNids(self):
        sql = """SELECT nid FROM fai WHERE config NOTNULL"""
        return self.runQueryAndReturnList(sql)
        
    def getFAIConfig(self, nid):
        cursor = self.connection.cursor()
        cursor.execute("""SELECT config FROM fai WHERE nid = %d""" % nid)
        result = cursor.fetchone()
        if result:
            return result[0]
        return None

    def getDirtyTables(self):
        sql = """SELECT data FROM dirty WHERE dirty = 't'"""
        return self.runQueryAndReturnList(sql)

    def clearDirty(self):
        cursor = self.connection.cursor()
        cursor.execute("""UPDATE dirty SET dirty = 'f'""")

    def commit(self):
        self.connection.commit()

def makeSt(list):
    st = [str(x) for x in list]
    return ', '.join(st)
       
