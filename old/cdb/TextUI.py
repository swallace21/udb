import sys
import EquipmentRecord

class TextUI:
    def __init__(self, progname):
        self.prog = progname
        
    def main(self, args):
        if len(args) < 2:
            self.usage()
            sys.exit(1)
        command = args.pop(0)
        
        if command == 'insert':
            self.insert(args)
        elif command == 'delete':
            self.delete(args)
        elif command == 'modify':
            self.modify(args)
        elif command == 'profile':
            self.profile(args[0])
        else:
            self.warn("Unknown command: " + command + "\n")
            sys.exit(1)

    def profile(self, *args):
        raise NotImplementedError

    def modify(self, *args):
        raise NotImplementedError

    def delete(self, *args):
        raise NotImplementedError

    def insert(self, *args):
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

class edb ( TextUI ):
    def profile(self, target):
        try:
            id = int(target, 10)
            eqrec = EquipmentRecord.fetchEqById(id)
        except ValueError:
            eqrec = EquipmentRecord.fetchEqByHostname(target)

        if not eqrec:
            self.warn('No record for "%s" found in database' % target)
            return

        self.display("id", eqrec.getId())
        hostnames = eqrec.getHostnames()
        self.display("hostname", ','.join(hostnames))
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
        self.display("User(s)", eqrec.getUsers())
