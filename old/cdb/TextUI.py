# $Id$

import sys
import mx.DateTime
import udb
import EquipmentRecord
import NetworkRecord
import Search

class TextUI:
    def __init__(self, progname):
        self.prog = progname
        
    def main(self, args):
        if len(args) < 1:
            self.usage()
            sys.exit(1)
        command = args.pop(0)

        if command == 'insert':
            if len(args) > 1:
                self.usage()
                sys.exit(1)
            self.insert(args)
        elif command == 'delete':
            if len(args) != 1:
                self.usage()
                sys.exit(1)
            self.delete(args[0])
        elif command == 'modify':
            if len(args) != 1:
                self.usage()
                sys.exit(1)
            self.modify(args[0])
        elif command == 'query':
            if len(args) < 1:
                self.usage()
                sys.exit(1)
            self.query(args)
        elif command == 'profile':
            if len(args) != 1:
                self.usage()
                sys.exit(1)
            self.profile(args[0])
        else:
            try:
                exec "self.%s(args)" % command
            except AttributeError, e:
                if e.args[0].endswith("has no attribute '%s'" % command):
                    self.warn("Unknown command: " + command + "\n")
                    sys.exit(1)
                else:
                    raise e

    def profile(self, target):
        raise NotImplementedError

    def modify(self, target):
        raise NotImplementedError

    def delete(self, target):
        raise NotImplementedError

    def insert(self, args):
        raise NotImplementedError

    def query(self, args):
        raise NotImplementedError

    #
    # Writes message to stderr, adding program name.
    #
    def warn(self, message):
        sys.stderr.write(self.prog + ": " + message + '\n')

    def usage(self):
        self.warn("Usage: " + self.prog + " <command> [<hostname>]")

    def display(self, field, val):
        sys.stdout.write("%s = " % field)
        if val is not None:
            sys.stdout.write(str(val))
        print

    def joinList(self, l):
        if l is None:
            return None
        return ','.join(l)

    def formatDate(self, d):
        if d:
            return '%d/%d/%d' % (d.month, d.day, d.year)
        else:
            return None

    def bold(self, st):
        return '\033[1m' + st + '\033[0m'
    
    #
    # Prompt the user for information, possibly with a default value.  If a
    # default is given, a return key returns the default.  A '\' key
    # returns an empty string, and any other input is just return
    #
    def prompt(self, st, default = None):
        if default:
            prompt = "%s [%s] " % (st, default)
        else:
            prompt = st + ' '
        resp = raw_input(prompt).strip()
        if not default:
            return resp

        if not resp:
            return default
        if resp == '\\':
            return ''
        return resp

    #
    # If st is a substring of 'yes' (case insenstive) return 1, else 0
    #
    def isYes(self, st):
        return 'yes'[0:len(st)] == st.lower()

    #
    # Convert a comma separated string into a list
    #
    def makeList(self, st):
        if len(st) == 0:
            return []
        l = st.split(",")
        l = [ s.strip() for s in l ]
        return [ s for s in l if s ]

    def setLid(self, eqrec, notUsed = 0):
        while 1:
            default = eqrec.getLid()
            resp = self.prompt("Enter location ID:", default)
            if default == resp:
                return
            if EquipmentRecord.isValidLid(resp):
                eqrec.setLid(resp)
                return
            print "ERROR: Invalid lid"

    #
    # Return the first available IP address on the given subnet.  The result
    # will have a host portion between 2 and 254
    #
    def pickIp(self, subnet):
        # select ipaddr from network where network(ipaddr) = '128.148.38';
        # get all the records for the given subnet
        rec = udb.Network.getSQLWhere("network(ipaddr) = '%s' order by ipaddr"
                                  % subnet)

        ips = [ n['ipaddr'][:-3] for n in rec ]
        for i in xrange(len(ips)):
            ips[i] = self.gethostnum(ips[i], subnet)
        for i in xrange(2, 254):
            if i not in ips:
                return "%s.%d" % (subnet, i)
        return None

    #
    # Given an ip address and a subnet, return the host portion
    #
    def gethostnum(self, ip, subnet):
        l = len(subnet) + 1
        return int(ip[l:])

    def setHostname(self, netrec, hasDefault = 0):
        if hasDefault:
            default = netrec.getHostname()
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter hostname:", default)
            if resp == default:
                break
            if netrec.setHostname(resp):
                break
            print 'There is already a host record for %s' % resp

    def setAliases(self, netrec, hasDefault = 0):
        if hasDefault:
            alias = netrec.getAliases()
            default = ','.join(alias)
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter aliases:", default)
            new = self.makeList(resp)
            new.sort()
            error = netrec.setAliases(new)
            if not error:
                break
            print error

    def setNetgroups(self, netrec, hasDefault = 0):
        if hasDefault:
            groups = netrec.getNetgroups()
            default = ','.join(groups)
        else:
            groups = []
            default = ''
        resp = self.prompt("Enter netgroups:", default)
        new = self.makeList(resp)
        new.sort()
        if new != groups:
            netrec.setNetgroups(new)

    def setEthernet(self, netrec, hasDefault = 0):
        if hasDefault:
            default = netrec.getEthernet()
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter ethernet:", default)
            if resp == default:
                break
            if not resp:
                break
            error = netrec.setEthernet(resp)
            if not error:
                break
            print error

    def setIp(self, netrec, hasDefault = 0):
        if hasDefault:
            default = netrec.getIP()
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter IP addr:", default)
            if resp == default:
                break
            if resp and resp[-1] == '*':
                resp = self.pickIp(resp[:-2])
                print "  Picked " + resp
            error = netrec.setIP(resp)
            if not error:
                break
            print error

    def setComment(self, rec, hasDefault = 0):
        if hasDefault:
            default = rec.getComment()
        else:
            default = ''
        resp = self.prompt("Enter comment:", default)
        if default != resp:
            if resp:
                rec.setComment(resp)
            else:
                rec.setComment(None)

    def setArch(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getArch()
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter hw arch:", default).lower()
            if resp == default:
                break
            if EquipmentRecord.isArchValid(resp):
                eqrec.setArch(resp)
                break
            print "ERROR: Unrecognized architecture"

    def setOs(self, netrec, hasDefault = 0):
        if hasDefault:
            default = ','.join(netrec.getOses())
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter OS type:", default)
            if resp == default:
                break
            new = self.makeList(resp)
            problem = netrec.setOs(new)
            if problem is None:
                break
            print "ERROR: Unrecognized OS: %s\n" % problem

    def setMx(self, netrec, hasDefault = 0):
        if hasDefault:
            default = netrec.getMxHost()
        else:
            default = 'cs.brown.edu'
        resp = self.prompt("Enter mxhost:", default)
        if resp != default:
            netrec.setMxHost(resp)

    def setStatus(self, netrec, hasDefault = 0):
        if hasDefault:
            default = ','.join(netrec.getStatus())
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter status:", default)
            if resp == default:
                break
            l = self.makeList(resp)
            problem = NetworkRecord.checkStatuses(l)
            if not problem:
                netrec.setStatus(l)
                break
            print "ERROR: Unrecognized status: %s\n" % problem

    def setDescription(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getDescr()
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter description:", default)
            if not resp:
                print "ERROR: Description can't be empty"
                continue
            if default == resp:
                break
            eqrec.setDescr(resp)
            break

    def setSerialNumber(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getSerialNumber()
        else:
            default = ''
        resp = self.prompt("Enter serial number:", default)
        if resp != default:
            eqrec.setSerialNumber(resp)

    def setInventoryNumber(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getInventoryNumber()
        else:
            default = ''
        resp = self.prompt("Enter inventory number:", default)
        if resp != default:
            eqrec.setInventoryNumber(resp)

    def setUsage(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getUsage()
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter type:", default)
            if resp == default:
                break
            if EquipmentRecord.isValidUsage(resp):
                eqrec.setUsage(resp)
                break
            print "ERROR: Not a valid type"

    def setPONumber(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getPO()[0]
        else:
            default = ''
        resp = self.prompt("Enter PO number:", default)
        if resp != default:
            eqrec.setPONumber(resp)

    def setPODate(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = self.formatDate(eqrec.getPO()[1])
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter PO date:", default)
            if resp == default:
                break
            if not resp:
                eqrec.setPODate(None)
                break
            dateTime = self.makeDate(resp)
            if dateTime:
                eqrec.setPODate(dateTime)
                break
            print "ERROR: Can't parse date"
            
    def setPOPrice(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getPO()[2]
            if not default:
                default = ''
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter PO price:", default)
            if resp == default:
                break
            if not resp:
                eqrec.setPOPrice(None)
                break
            try:
                f = float(resp)
                eqrec.setPOPrice(f)
                break
            except ValueError:
                print "ERROR: Not a valid price" 
        
    def setPOComment(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getPO()[3]
        else:
            default = ''
        resp = self.prompt("Enter PO comment:", default)
        if resp != default:
            eqrec.setPOComment(resp)

    def setInstallDate(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = self.formatDate(eqrec.getInstallation()[0])
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter installation date:", default)
            if resp == default:
                break
            if not resp:
                eqrec.setInstallDate(None)
                break
            dateTime = self.makeDate(resp)
            if dateTime:
                eqrec.setInstallDate(dateTime)
                break
            print "ERROR: Can't parse date"

    def setInstallComment(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getInstallation()[1]
        else:
            default = ''
        resp = self.prompt("Enter installation comment:", default)
        if resp != default:
            eqrec.setInstallComment(resp)

    def setUsers(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = self.joinList(eqrec.getUsers())
        else:
            default = ''
        resp = self.prompt("Enter users:", default)
        if resp != default:
            new = self.makeList(resp)
            eqrec.setUsers(new)

    def setCpu(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getConfiguration()['cpu']
            if not default:
                default = ''
        else:
            default = ''
        resp = self.prompt("Enter CPU:", default)
        if resp != default:
            eqrec.setCpu(resp)
        
    def setDisk(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getConfiguration()['disk']
            if not default:
                default = ''
        else:
            default = ''
        resp = self.prompt("Enter disk:", default)
        if resp != default:
            eqrec.setDisk(resp)

    def setMem(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getConfiguration()['memory']
            if not default:
                default = ''
        else:
            default = ''
        resp = self.prompt("Enter memory:", default)
        if resp != default:
            eqrec.setMem(resp)

    def setGraphics(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getConfiguration()['graphics']
            if not default:
                default = ''
        else:
            default = ''
        resp = self.prompt("Enter graphics:", default)
        if resp != default:
            eqrec.setGraphics(resp)

    def setConfComment(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getConfiguration()['comment']
            if not default:
                default = ''
        else:
            default = ''
        resp = self.prompt("Enter config comment:", default)
        if resp != default:
            eqrec.setConfComment(resp)

    def setSurplusDate(self, eqrec, hasDefault = 0):
        default = mx.DateTime.now()
        if hasDefault:
            default = eqrec.getDispose()['surplus_date']
            if not default:
                default = mx.DateTime.now()
        default = self.formatDate(default)
        while 1:
            resp = self.prompt("Enter date surplused:", default)
            if not resp:
                eqrec.setDisposeSurplusDate(None)
                break
            dateTime = self.makeDate(resp)
            if dateTime:
                eqrec.setDisposeSurplusDate(dateTime)
                break
            print "ERROR: Can't parse date"

    def setSoldDate(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getDispose()['sold_date']
        else:
            default = ''
        default = self.formatDate(default)
        while 1:
            resp = self.prompt("Enter date sold:", default)
            if resp == default:
                break
            if not resp:
                eqrec.setDisposeSoldDate(None)
                break
            dateTime = self.makeDate(resp)
            if dateTime:
                eqrec.setDisposeSoldDate(dateTime)
                break
            print "ERROR: Can't parse date"

    def setSoldPrice(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getDispose()['price']
            if not default:
                default = ''
        else:
            default = ''
        while 1:
            resp = self.prompt("Enter sold price:", default)
            if resp == default:
                break
            if not resp:
                eqrec.setDisposePrice(None)
                break
            try:
                f = float(resp)
                eqrec.setDisposePrice(f)
                break
            except ValueError:
                print "ERROR: Not a valid price" 

    def setSurplusBuyer(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getDispose()['buyer']
            if not default:
                default = ''
        else:
            default = ''
        resp = self.prompt("Enter buyer:", default)
        if resp != default:
            eqrec.setDisposeBuyer(resp)

    def setSurplusComment(self, eqrec, hasDefault = 0):
        if hasDefault:
            default = eqrec.getDispose()['comment']
            if not default:
                default = ''
        else:
            default = ''
        resp = self.prompt("Enter surplus comment:", default)
        if resp != default:
            eqrec.setDisposeComment(resp)

    def makeDate(self, st):
        return mx.DateTime.Parser.DateFromString(st, ('us', 'altus',
                                                      'iso', 'altiso',
                                                      'lit', 'altlit'))

    def confirmUpdate(self):
        resp = self.prompt("\nSave changed record (y/n)[y]?", 'y')
        if not resp:
            resp = 'y'
        if self.isYes(resp):
            udb.commit()
        else:
            print "No modifications saved."

    def confirmInsert(self):
        resp = self.prompt("Insert new record (y/n)[y]?", 'y')
        if self.isYes(resp):
            udb.commit()
        else:
            print "Insert cancelled."

    def confirmDelete(self):
        print
        resp = self.prompt("Delete this record (y/n)[n]?", 'n')
        if self.isYes(resp):
            udb.commit()
        else:
            print "Deletion cancelled."            

    def searchForRecord(self, target, searchClass):
        if target.find('=') == -1:
            return None
        search = searchClass(udb.getConnection())
        try:
            result = search.run(target)
        except Search.ParseError:
            return None
        if len(result) == 1:
            return self.getRec(result[0])
        if len(result) == 0:
            return None
        self.warn("Multiple records for %s" % target)
        return None

    def displayIdSurp(self, id, surp):
        sys.stdout.write("id = %d" % id)
        if surp:
            sys.stdout.write(self.bold(" *SURPLUS*"))
        print

class edb ( TextUI ):
    def profile(self, target):
        eqrec = self.getRec(target)
        if not eqrec:
            eqrec = self.searchForRecord(target, Search.EdbSearch)
            if not eqrec:
                self.warn('No record for "%s" found in database' % target)
                return

        self.displayIdSurp(eqrec.getId(), eqrec.isSurplus())
        hostnames = eqrec.getHostnames()
        self.display("hostnames", ','.join(hostnames))
        self.display("descr", eqrec.getDescr())
        self.display("lid", eqrec.getLid())
        self.display("serial number", eqrec.getSerialNumber())
        self.display("inventory number", eqrec.getInventoryNumber())
        self.display("type", eqrec.getUsage())
        self.display("comment", eqrec.getComment())
        (po_num, po_date, po_price, po_comment) = eqrec.getPO()
        self.display("po number", po_num)
        self.display("po date", self.formatDate(po_date))
        self.display("po price", po_price)
        self.display("po comment", po_comment)
        (inst_date, inst_comment) = eqrec.getInstallation()
        self.display("install date", self.formatDate(inst_date))
        self.display("install comment", inst_comment)
        self.display("users", self.joinList(eqrec.getUsers()))
        conf = eqrec.getConfiguration()
        self.display("cpu", conf['cpu'])
        self.display("disk", conf['disk'])
        self.display("memory", conf['memory'])
        self.display("graphics", conf['graphics'])
        self.display("conf_comment", conf['comment'])
        if eqrec.isSurplus():
            self.profileSurplus(eqrec)
                             
    def profileSurplus(self, eqrec):
        disp = eqrec.getDispose()
        if disp:
            self.display("surplus date", self.formatDate(disp['surplus_date']))
            self.display("sold date", self.formatDate(disp['sold_date']))
            self.display("sale price", disp['price'])
            self.display("buyer", disp['buyer'])
            self.display("surplus comment", disp['comment'])

    def surplus(self, args):
        if len(args) != 1:
            self.usage()
            sys.exit(1)
        eqrec = self.getRec(args[0])
        if not eqrec:
            eqrec = self.searchForRecord(args[0], Search.EdbSearch)
            if not eqrec:
                self.warn('No record for "%s" found in database' % args[0])
                return
        self.profile(eqrec.getId())
        print
        resp = self.prompt("Surplus this item (y/n)[y]?", 'y')
        if not self.isYes(resp):
            print "Surplus cancelled."
            return
        eqrec.setSurplus()
        self.setSurplusDate(eqrec, 1)
        self.setSoldDate(eqrec, 1)
        self.setSoldPrice(eqrec, 1)
        self.setSurplusBuyer(eqrec, 1)
        self.setSurplusComment(eqrec, 1)
        udb.commit()

    def unsurplus(self, args):
        if len(args) != 1:
            self.usage()
            sys.exit(1)
        if type(args[0]) is int or args[0].isdigit():
            eqrec = udb.Equipment.getUnique(id = args[0])
        else:
            self.warn("'unsurplus' must be given an id")
            return
        if eqrec['active']:
            self.warn("%s is not surplused" % args[0])
        else:
            eqrec['active'] = 1
            disp = udb.Dispose.getUnique(id = eqrec['id'])
            if disp:
                disp.delete()
            udb.commit()

    def notifyOfOrphaning(self, id):
        netrecs = udb.Network.getSome(id = id)
        for n in netrecs:
            n['id'] = None
            print "Orphaning network record %s/%d" % (n['hostname'], n['nid'])
        
    def delete(self, target):
        #
        # Note: this eqrec is not an EquipmentRecord, but a "raw" PyDO
        # Equipment object
        #
        if type(target) is int or target.isdigit():
            eqrec = udb.Equipment.getUnique(id = target)
        else:
            netrec = NetworkRecord.fetchNetByHostname(target)
            if netrec:
                eqrec = udb.Equipment.getUnique(id = netrec.getId())
            else:
                eqrec = None
        if not eqrec:
            eqrec = self.searchForRecord(target, Search.EdbSearch)
            if not eqrec:
                self.warn('No record for "%s" found in database' % target)
                return
            eqrec = eqrec.record
        self.profile(eqrec['id'])
        print
        self.notifyOfOrphaning(eqrec['id'])
        eqrec.delete()
        self.confirmDelete()

    def insert(self, notUsed):
        eqrec = EquipmentRecord.EquipmentRecord('Unknown')
        self.setDescription(eqrec)
        self.setLid(eqrec)
        self.setSerialNumber(eqrec)
        self.setInventoryNumber(eqrec)
        self.setUsage(eqrec)
        self.setComment(eqrec)
        self.setPONumber(eqrec)
        self.setPODate(eqrec)
        self.setPOPrice(eqrec)
        self.setPOComment(eqrec)
        self.setInstallDate(eqrec)
        self.setInstallComment(eqrec)
        self.setUsers(eqrec)
        self.setCpu(eqrec)
        self.setDisk(eqrec)
        self.setMem(eqrec)
        self.setGraphics(eqrec)
        self.setConfComment(eqrec)

        self.confirmInsert()

    def modify(self, target):
        eqrec = self.getRec(target)
        if not eqrec:
            eqrec = self.searchForRecord(target, Search.EdbSearch)            
            if not eqrec:
                self.warn('No record for "%s" found in database' % target)
                return
        if eqrec.isSurplus():
            print self.bold('*SURPLUS*')
        self.setDescription(eqrec, 1)
        self.setLid(eqrec, 1)
        self.setSerialNumber(eqrec, 1)
        self.setInventoryNumber(eqrec, 1)
        self.setUsage(eqrec, 1)
        self.setComment(eqrec, 1)
        self.setPONumber(eqrec, 1)
        self.setPODate(eqrec, 1)
        self.setPOPrice(eqrec, 1)
        self.setPOComment(eqrec, 1)
        self.setInstallDate(eqrec, 1)
        self.setInstallComment(eqrec, 1)
        self.setUsers(eqrec, 1)
        self.setConfComment(eqrec, 1)
        self.setCpu(eqrec, 1)
        self.setDisk(eqrec, 1)
        self.setMem(eqrec, 1)
        self.setGraphics(eqrec, 1)

        self.confirmUpdate()
    
    def query(self, args):
        search = Search.EdbSearch(udb.getConnection())
        try:
            result = search.run(args[0])
        except Search.ParseError, ex:
            self.warn("ERROR: Can't parse query: " + ex.args[0])
            return
        
        if not result:
            return
        
        if len(args) == 1:
            for id in result:
                eqrec = EquipmentRecord.fetchEqById(id)
                hostnames = eqrec.getHostnames()
                if hostnames:
                    print hostnames[0]
                else:
                    print eqrec.getId()
                
        elif args[1] == 'all':
            if len(result) == 1:
                self.profile(result[0])
            else:
                for id in result:
                    print '=' * 40
                    self.profile(id)
        else:
            for id in result:
                eqrec = EquipmentRecord.fetchEqById(id)
                self.printFields(eqrec, args)

    def printFields(self, eqrec, args):
        l = []
        for field in args[1:]:
            if field == 'hostname':
                hostnames = eqrec.getHostnames()
                if hostnames:
                    l.append(hostnames[0])
                else:
                    l.append('')
            elif field == 'desc' or field == 'descr':
                l.append(eqrec.getDescr())
            elif field == 'serial_num' or field == 'serial':
                l.append(eqrec.getSerialNumber())
            elif field == 'inventory_number' or field == 'inv' \
                     or field == 'inv_num':
                l.append(eqrec.getInventoryNumber())
            elif field == 'comment':
                l.append(eqrec.getComment())
            elif field == 'lid':
                l.append(eqrec.getLid())
            elif field == 'id':
                l.append(str(eqrec.getId()))
            elif field == 'type':
                l.append(eqrec.getUsage())
            elif field == 'po_num' or field == 'ponum':
                l.append(eqrec.getPO()[0])
            elif field == 'po_date' or field == 'podate':
                l.append(eqrec.getPO()[1])
            elif field == 'po_price' or field == 'poprice' or field == 'price':
                price = eqrec.getPO()[2]
                if price is None:
                    l.append('')
                else:
                    l.append(str(price))
            elif field == 'po_comment' or field == 'pocomment':
                l.append(eqrec.getPO()[3])
            elif field == 'arch' or field == 'hw_arch':
                l.append(eqrec.getArch())
            elif field == 'users':
                l.append(self.joinList(eqrec.getUsers()))
            elif field == 'inst_date' or field == 'install_date' \
                     or field == 'instdate':
                l.append(eqrec.getInstallation()[0])
            elif field == 'inst_comment' or field == 'instcomment':
                l.append(eqrec.getInstallation()[1])
            elif field == 'cpu':
                l.append(eqrec.getConfiguration()['cpu'])
            elif field == 'memory' or field == 'mem':
                l.append(eqrec.getConfiguration()['memory'])
            elif field == 'disk':
                l.append(eqrec.getConfiguration()['disk'])
            elif field == 'graphics' or field == 'gfx':
                l.append(eqrec.getConfiguration()['graphics'])
            elif field == 'conf_comment' or field == 'config_comment':
                l.append(eqrec.getConfiguration()['comment'])
            elif field == 'building':
                l.append(eqrec.getBuilding())
            elif field == 'floor':
                l.append(eqrec.getFloor())
            elif field == 'room':
                l.append(eqrec.getRoom())
            else:
                self.warn("Unrecognized field: %s" % field)
        print '\t'.join([ a or '' for a in l])

    def getRec(self, target):
        if type(target) is int or target.isdigit():
            eqrec = EquipmentRecord.fetchEqById(target)
        else:
            eqrec = EquipmentRecord.fetchEqByHostname(target)
        return eqrec

class cdb ( TextUI ):
    def profile(self, target):
        netrec = self.getRec(target)
        if not netrec:
            netrec = self.searchForRecord(target, Search.CdbSearch)            
            if not netrec:
                self.warn('No record for "%s" found in database' % target)
                return
            
        self.display("nid", netrec.getNid())
        self.display("hostname", netrec.getHostname())
        eqrec = netrec.getEquipmentRec()
        if eqrec:
            self.displayIdSurp(eqrec.getId(), eqrec.isSurplus())
            self.display("lid", eqrec.getLid())
        self.display("netgroups", self.joinList(netrec.getNetgroups()))
        self.display("aliases", self.joinList(netrec.getAliases()))
        self.display("comment", netrec.getComment())
        self.display("ethernet", netrec.getEthernet())

        st = None
        id = netrec.getId()
        if id is not None:
            archrec = udb.Architecture.getUnique(id = id)
            if archrec is not None:
                st = archrec['arch']
        self.display("hw_arch", st)
        self.display("ip_addr", netrec.getIP())
        self.display("mxhost", netrec.getMxHost())
        self.display("os_type", self.joinList(netrec.getOses()))
        self.display("status", self.joinList(netrec.getStatus()))

    def delete(self, target):
        #
        # Note: this netrec is not a NetworkRecord, but a "raw" PyDO
        # Network object
        #
        if type(target) is int or target.isdigit():
            netrec = udb.Network.getUnique(nid = target)
        else:
            netrec = udb.Network.getUnique(hostname = target)
        if netrec is None:
            netrec = self.searchForRecord(target, Search.CdbSearch)
            if not netrec:
                self.warn('No record for "%s" found in database' % target)
                return
            else:
                netrec = netrec.record
        id = netrec['id']
        self.profile(netrec['nid'])
        netrec.delete()
        if id:
            eqrec = udb.Equipment.getUnique(id = id)
            if not eqrec['comment']:
                eqrec['comment'] = 'formerly ' + target

        self.confirmDelete()

    def query(self, args):
        search = Search.CdbSearch(udb.getConnection())
        try:
            result = search.run(args[0])
        except Search.ParseError, ex:
            self.warn("ERROR: Can't parse query: " + ex.args[0])
            return
        if not result:
            return
        
        if len(args) == 1:
            for nid in result:
                netrec = NetworkRecord.fetchNetByNid(nid)
                print netrec.getHostname()
        elif args[1] == 'all':
            if len(result) == 1:
                self.profile(result[0])
            else:
                for nid in result:
                    print '=' * 40
                    self.profile(nid)
        else:
            for nid in result:
                netrec = NetworkRecord.fetchNetByNid(nid)
                self.printFields(netrec, args)

    def printFields(self, netrec, args):
        l = []
        eqrec = netrec.getEquipmentRec()
        
        for field in args[1:]:
            if field == 'hostname':
                l.append(netrec.getHostname())
            elif field == 'ipaddr' or field == 'ip_addr' or field == 'ip':
                l.append(netrec.getIP())
            elif field == 'mxhost' or field == 'mx':
                l.append(netrec.getMxHost())
            elif field == 'status':
                l.append(self.joinList(netrec.getStatus()))
            elif field == 'os' or field == 'os_type':
                l.append(self.joinList(netrec.getOses()))
            elif field == 'alias' or field == 'aliases':
                l.append(self.joinList(netrec.getAliases()))
            elif field == 'comment':
                l.append(netrec.getComment())
            elif field == 'ether' or field == 'ethernet' or field == 'mac':
                l.append(netrec.getEthernet())
            elif field == 'arch' or field == 'hw_arch':
                l.append(netrec.getArch())
            elif field == 'lid':
                val = ''
                if eqrec:
                    val = eqrec.getLid()
                l.append( val )
            elif field == 'nid':
                l.append(str(netrec.getNid()))
            elif field == 'id':
                val = ''
                if eqrec:
                    val = str(eqrec.getId())
                l.append(val)
            elif field in ('netgroup', 'netgroups', 'group', 'supp_grps',
                           'prim_grp'):
                l.append(self.joinList(netrec.getNetgroups()))
            else:
                self.warn("Unrecognized field: %s" % field)
        print '\t'.join([a or '' for a in l])
    
    def insert(self, args):
        if len(args) == 1:
            eqid = args[0]
        else:
            eqid = None
        netrec = NetworkRecord.NetworkRecord()
        eqrec = None

        #
        # Eq ID
        #
        if not eqid:
            while 1:
                resp = self.prompt("Enter equipment ID:")
                if not resp:
                    resp = self.prompt("Creating a network entry with no associated equipment.\nIs this really what you want to do? (y/n)", 'N')
                    if not self.isYes(resp):
                        continue
                    else:
                        break
                else:
                    eqrec = EquipmentRecord.fetchEqById(resp)
                    if not eqrec:
                        print 'No equipment with id %s in database' % resp
                    else:
                        netrec.setId(eqrec.getId())
                        break
        if eqrec:
            self.setLid(eqrec)
        self.setHostname(netrec)
        self.setAliases(netrec)
        self.setNetgroups(netrec)
        self.setComment(netrec)
        self.setEthernet(netrec)
        self.setIp(netrec)
        if eqrec:
            self.setArch(eqrec)
        self.setOs(netrec)
        self.setMx(netrec)
        self.setStatus(netrec)

        self.confirmInsert()

    def modify(self, target):
        netrec = self.getRec(target)
        if not netrec:
            netrec = self.searchForRecord(target, Search.CdbSearch)
            if not netrec:
                self.warn('No record for "%s" found in database' % target)
                return

        #
        # Equipment ID
        #
        default = netrec.getId()
        while 1:
            resp = self.prompt("Enter equipment ID:", default)
            if default == resp:
                break
            if resp and not resp.isdigit():
                print "Id must be a number"
            else:
                netrec.setId(resp)
                break
        self.setHostname(netrec, 1)
        self.setAliases(netrec, 1)
        self.setNetgroups(netrec, 1)
        self.setComment(netrec, 1)
        self.setEthernet(netrec, 1)
        self.setIp(netrec, 1)
        eqrec = netrec.getEquipmentRec()
        if eqrec:
            self.setArch(eqrec, 1)
        self.setOs(netrec, 1)
        self.setMx(netrec, 1)
        self.setStatus(netrec, 1)

        self.confirmUpdate()

    def getRec(self, target):
        if type(target) is int or target.isdigit():
            netrec = NetworkRecord.fetchNetByNid(target)
        else:
            netrec = NetworkRecord.fetchNetByHostname(target)
        return netrec
