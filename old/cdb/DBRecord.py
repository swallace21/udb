#!/usr/bin/python2.1

def quote(st):
    if not st:
        return None
    return "'%s'" % st
    
class DBRecord:
    def quote(self, st):
        return quote(st)
