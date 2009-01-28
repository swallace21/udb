#!/bin/sh
cd `/usr/bin/dirname $0`

./create_vlans_and_zones.pl $@
./import_accounts.pl $@
./import_automounts.pl $@
./import_cdb.pl $@
