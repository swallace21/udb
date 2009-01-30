begin;
update location set building = 'CIT', room = location.lid where lid ~* '^[0-9][0-9][0-9]$';
update location set floor = '1' where room ~* '^1[0-9][0-9]$';
update location set floor = '2' where room ~* '^2[0-9][0-9]$';
update location set floor = '3' where room ~* '^3[0-9][0-9]$';
update location set floor = '4' where room ~* '^4[0-9][0-9]$';
update location set floor = '5' where room ~* '^5[0-9][0-9]$';
commit;
