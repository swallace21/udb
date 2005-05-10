#!/bin/sh
cd `/usr/bin/dirname $0`

./import_accounts.pl $@
./import_automounts.pl $@
./import_cdb.pl $@
