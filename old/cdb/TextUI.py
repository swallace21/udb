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
            self.warn("Unknown command: " + command + "\n")
            sys.exit(1)

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

    def display(self, prompt, val):
        sys.stdout.write("%s = " % prompt)        
        if val is not None:
            sys.stdout.write(str(val))
        print

    def joinList(self, l):
        if l is None:
            return None
        return ','.join(l)

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
            groups = netrec.getOtherNetgroups()
            default = ','.join(groups)
        else:
            groups = []
            default = ''
        resp = self.prompt("Enter netgroups:", default)
        new = self.makeList(resp)
        new.sort()
        if new != groups:
            netrec.setOtherNetgroups(new)

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

    def setSerialNumber(self, eqrec, hasDefault):
        if hasDefault:
            default = eqrec.getSerialNumber()
        else:
            default = ''
        resp = self.prompt("Enter serial number:", default)
        if resp != default:
            eqrec.setSerialNumber(resp)

    def setInventoryNumber(self, eqrec, hasDefault):
        if hasDefault:
            default = eqrec.getInventoryNumber()
        else:
            default = ''
        resp = self.prompt("Enter inventory number:", default)
        if resp != default:
            eqrec.setInventoryNumber(resp)

    def setUsage(self, eqrec, hasDefault):
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

    def setPONumber(self, eqrec, hasDefault):
        if hasDefault:
            default = eqrec.getPO()[0]
        else:
            default = ''
        resp = self.prompt("Enter PO number:", default)
        if resp != default:
            eqrec.setPONumber(resp)

    def setPODate(self, eqrec, hasDefault):
        if hasDefault:
            default = eqrec.getPO()[1]
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
            
    def setPOPrice(self, eqrec, hasDefault):
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
        
    def setPOComment(self, eqrec, hasDefault):
        if hasDefault:
            default = eqrec.getPO()[3]
        else:
            default = ''
        resp = self.prompt("Enter PO comment:", default)
        if resp != default:
            eqrec.setPOComment(resp)

    def setInstallDate(self, eqrec, hasDefault):
        if hasDefault:
            default = eqrec.getInstallation()[0]
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

    def setInstallComment(self, eqrec, hasDefault):
        if hasDefault:
            default = eqrec.getInstallation()[1]
        else:
            default = ''
        resp = self.prompt("Enter installation comment:", default)
        if resp != default:
            eqrec.setInstallComment(resp)

    def setUsers(self, eqrec, hasDefault):
        if hasDefault:
            default = self.joinList(eqrec.getUsers())
        else:
            default = ''
        resp = self.prompt("Enter users:", default)
        if resp != default:
            new = self.makeList(resp)
            eqrec.setUsers(new)

    def makeDate(self, st):
        return mx.DateTime.Parser.DateFromString(st, ('us', 'altus',
                                                      'iso', 'altiso',
                                                      'lit', 'altlit'))

    def confirmUpdate(self):
        resp = self.prompt("\nSave changed record (y/n)[y]? ")
        if not resp:
            resp = 'y'
        if self.isYes(resp):
            udb.commit()
        else:
            print "No modifications saved."

    def confirmInsert(self):
        resp = self.prompt("Insert new record (y/n)?", 'y')
        if self.isYes(resp):
            udb.commit()
        else:
            print "Insert cancelled."
            
class edb ( TextUI ):
    def profile(self, target):
        eqrec = self.getRec(target)
        if not eqrec:
            return

        self.display("id", eqrec.getId())
        hostnames = eqrec.getHostnames()
        self.display("hostnames", ','.join(hostnames))
        self.display("descr", eqrec.getDescr())
        self.display("location", eqrec.getLid())
        self.display("serial number", eqrec.getSerialNumber())
        self.display("inventory number", eqrec.getInventoryNumber())
        self.display("type", eqrec.getUsage())
        self.display("comment", eqrec.getComment())
        (po_num, po_date, po_price, po_comment) = eqrec.getPO()
        self.display("po number", po_num)
        self.display("po date", po_date)
        self.display("po price", po_price)
        self.display("po comment", po_comment)
        (inst_date, inst_comment) = eqrec.getInstallation()
        self.display("install date", inst_date)
        self.display("install comment", inst_comment)
        self.display("User(s)", self.joinList(eqrec.getUsers()))

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
            self.warn('No record for "%s" found in database' % target)
            return
        netrecs = udb.Network.getSome(id = eqrec['id'])
        for n in netrecs:
            n['id'] = None
            print "Orphaning network record %s/%d" % (n['hostname'], n['nid'])
        eqrec.delete()
        udb.commit()

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

        self.confirmInsert()

    def modify(self, target):
        eqrec = self.getRec(target)
        if not eqrec:
            return
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

        self.confirmUpdate()
    
    def query(self, args):
        search = Search.EdbSearch(udb.getConnection())
        result = search.run(args[0])
        if not result:
            return
        print result
        
        if len(args) == 1:
            for id in result:
                eqrec = EquipmentRecord.fetchEqById(id)
                hostnames = eqrec.getHostnames()
                if hostnames:
                    print hostnames[0]
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
                l.append(eqrec.getDescr() or '')
            else:
                self.warn("Unrecognized field: %s" % field)
        print '\t'.join(l)

    def getRec(self, target):
        if type(target) is int or target.isdigit():
            eqrec = EquipmentRecord.fetchEqById(target)
        else:
            eqrec = EquipmentRecord.fetchEqByHostname(target)
        if not eqrec:
            self.warn('No record for "%s" found in database' % target)
        return eqrec

class cdb ( TextUI ):
    def profile(self, target):
        netrec = self.getRec(target)
        if not netrec:
            return

        self.display("nid", netrec.getNid())
        self.display("hostname", netrec.getHostname())
        self.display("prim_grp", netrec.getNetgroup())
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
        self.display("supp_grps", self.joinList(netrec.getOtherNetgroups()))

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
            self.warn('No record for "%s" found in database' % target)
            return
        id = netrec['id']
        netrec.delete()
        if id:
            eqrec = udb.Equipment.getUnique(id = id)
            if not eqrec['comment']:
                eqrec['comment'] = 'formerly ' + target
        udb.commit()

    def query(self, args):
        search = Search.CdbSearch(udb.getConnection())
        result = search.run(args[0])
        if not result:
            return
        print result
        
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
        for field in args[1:]:
            if field == 'hostname':
                l.append(netrec.getHostname() or '')
            elif field == 'ipaddr' or field == 'ip_addr':
                l.append(netrec.getIP() or '')
            elif field == 'os' or field == 'os_type':
                val = netrec.getOses()
                l.append(','.join(val))
            elif field == 'alias' or field == 'aliases':
                val = netrec.getAliases()
                l.append(','.join(val))
            elif field == 'comment':
                l.append(netrec.getComment() or '')
            elif field == 'ether' or field == 'ethernet' or field == 'mac':
                l.append( netrec.getEthernet() or '')
            elif field == 'arch' or field == 'hw_arch':
                l.append( netrec.getArch() or '' )
            elif field == 'lid':
                val = netrec.getEquipmentRec().getLid()
                l.append( val or '' )
            elif field == 'nid':
                l.append(str(netrec.getNid()))
            elif field == 'id':
                eqrec = netrec.getEquipmentRec()
                if eqrec:
                    val = str(eqrec.getId())
                else:
                    val = None
                l.append(val or '')
            else:
                self.warn("Unrecognized field: %s" % field)
        print '\t'.join(l)
    
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
        if not netrec:
            self.warn('No record for "%s" found in database' % target)
        return netrec
