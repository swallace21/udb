-- ================================================================================
--   postgres SQL DDL Script File
-- ================================================================================


-- ================================================================================
-- 
--   Generated by:      tedia2sql -- v1.2.9
--                      See http://tedia2sql.tigris.org/AUTHORS.html for tedia2sql author information
-- 
--   Target Database:   postgres
--   Generated at:      Mon Mar 28 12:58:06 2005
--   Input File:        schema.dia
-- 
-- ================================================================================



-- Generated SQL Constraints Drop statements
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.9
--     Generated at:      Mon Mar 28 12:58:06 2005
--     Input File:        schema.dia

-- alter table class_list drop constraint fk_os_class_list --(is implicitly done)
-- alter table switchport drop constraint fk_switch_switchport --(is implicitly done)
-- alter table surplus drop constraint fk_equip_surplus --(is implicitly done)
-- alter table purchase drop constraint fk_equip_purchase --(is implicitly done)
-- alter table os drop constraint fk_machine_os --(is implicitly done)
-- alter table aliases drop constraint fk_netobj_aliases --(is implicitly done)
-- alter table group_list drop constraint fk_accounts_group_list --(is implicitly done)
-- alter table identity_list drop constraint fk_accounts_identity_list --(is implicitly done)
-- alter table sponsors drop constraint fk_accounts_sponsor --(is implicitly done)
-- alter table sponsors drop constraint fk_accounts_sponsee --(is implicitly done)
-- alter table group_list drop constraint fk_groups_group_list --(is implicitly done)
-- alter table net_relation drop constraint fk_netobj_net_relation --(is implicitly done)
-- alter table net_relation drop constraint fk_equip_net_relation --(is implicitly done)
-- alter table equip_users drop constraint fk_equip_equip_users --(is implicitly done)
-- alter table passwords drop constraint fk_accounts_passwd --(is implicitly done)
-- alter table equip_users drop constraint fk_people_equip_users --(is implicitly done)
-- alter table accounts drop constraint fk_people_accounts --(is implicitly done)
-- alter table identity_list drop constraint fk_identities_identity_list --(is implicitly done)
-- alter table machine drop constraint fk_equip_machine --(is implicitly done)
-- alter table switch drop constraint fk_equip_switch --(is implicitly done)
-- alter table netobj drop constraint fk_switchport_netobj --(is implicitly done)
-- alter table faculty drop constraint fk_people_faculty --(is implicitly done)
-- alter table grads drop constraint fk_people_grads --(is implicitly done)
-- alter table staff drop constraint fk_people_staff --(is implicitly done)
-- alter table ugrads drop constraint fk_people_ugrads --(is implicitly done)
-- alter table net_service drop constraint fk_netobj_net_service --(is implicitly done)
-- alter table class_list drop constraint fk_classes_class_list --(is implicitly done)
-- alter table net_service drop constraint fk_classes_net_service --(is implicitly done)
-- alter table fs_exports drop constraint fk_fs_classes_fs_exports --(is implicitly done)


-- Generated Permissions Drops
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.9
--     Generated at:      Mon Mar 28 12:58:06 2005
--     Input File:        schema.dia



-- Special statements for postgres:pre databases
-- sequence variables
drop SEQUENCE equip_id_seq;
create SEQUENCE equip_id_seq;
drop SEQUENCE cs_id_seq;
create SEQUENCE cs_id_seq;
drop SEQUENCE person_id_seq;
create SEQUENCE person_id_seq;
drop SEQUENCE gid_seq;
create SEQUENCE gid_seq;
drop SEQUENCE uid_seq;
create SEQUENCE uid_seq;

-- Special statements for postgres:pre databases
-- dummy functions
drop FUNCTION num_ports(TEXT) CASCADE;
create FUNCTION num_ports(TEXT)
  returns INT
  AS 'select 0'
  LANGUAGE 'sql';

-- Special statements for postgres:pre databases
-- DOMAINS
DROP DOMAIN USAGE CASCADE;
CREATE DOMAIN USAGE TEXT NOT NULL CHECK(
VALUE = 'instructional' OR
VALUE = 'research' OR
VALUE = 'other');

DROP DOMAIN NETSTATUS CASCADE;
CREATE DOMAIN NETSTATUS TEXT NOT NULL CHECK(
VALUE = 'trusted' OR
VALUE = 'untrusted' OR
VALUE = 'dynamic' OR
VALUE = 'monitored' OR
VALUE = 'remote' OR
VALUE = 'disabled');

DROP DOMAIN NETDOMAIN CASCADE;
CREATE DOMAIN NETDOMAIN TEXT NOT NULL CHECK(
VALUE = 'intranet' OR
VALUE = 'ilab' OR
VALUE = 'wan' OR
VALUE = 'dmz');

DROP DOMAIN DIRTYSTATE CASCADE;
CREATE DOMAIN DIRTYSTATE TEXT NOT NULL CHECK(
VALUE = 'unchanged' OR
VALUE = 'changed' OR
VALUE = 'deleted');

drop FUNCTION check_vlan(INT) CASCADE;
drop TABLE vlan_list;
create TABLE vlan_list (
  vlan INT NOT NULL,
  network CIDR NOT NULL,
  descr TEXT NOT NULL,
  CONSTRAINT pk_vlan_list PRIMARY KEY (vlan)
);
create FUNCTION check_vlan(INT)
  RETURNS INT
  AS 'SELECT vlan from vlan_list WHERE vlan = $1'
  LANGUAGE 'sql';


-- Generated SQL View Drop Statements
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.9
--     Generated at:      Mon Mar 28 12:58:06 2005
--     Input File:        schema.dia



-- Generated SQL Schema Drop statements
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.9
--     Generated at:      Mon Mar 28 12:58:06 2005
--     Input File:        schema.dia

drop table equipment cascade ;
drop table netobj cascade ;
drop table switch cascade ;
drop table switchport cascade ;
drop table machine cascade ;
drop table purchase cascade ;
drop table surplus cascade ;
drop table aliases cascade ;
drop table class_list cascade ;
drop table os cascade ;
drop table dhcp_log cascade ;
drop table macaddr_log cascade ;
drop table dirty_files cascade ;
drop table accounts cascade ;
drop table group_list cascade ;
drop table identity_list cascade ;
drop table sponsors cascade ;
drop table mail_aliases cascade ;
drop table groups cascade ;
drop table identities cascade ;
drop table net_relation cascade ;
drop table equip_users cascade ;
drop table passwords cascade ;
drop table people cascade ;
drop table faculty cascade ;
drop table grads cascade ;
drop table staff cascade ;
drop table ugrads cascade ;
drop table net_service cascade ;
drop table classes cascade ;
drop table fs_exports cascade ;
drop table fs_classes cascade ;


-- Generated SQL Schema
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.9
--     Generated at:      Mon Mar 28 12:58:06 2005
--     Input File:        schema.dia


-- equipment
create table equipment (
  equip_id                  int4 default nextval('equip_id_seq') not null,
  cs_id                     int4 unique default nextval ('cs_id_seq'),
  equip_name                text unique,
  brown_inv_num             text,
  descr                     text not null,
  owner                     text,
  contact                   text,
  usage                     usage,
  building                  text,
  floor                     text,
  room                      text,
  comments                  text,
  constraint pk_equipment primary key (equip_id)
) ;

-- netobj
create table netobj (
  dns_name                  text not null,
  domain                    netdomain not null,
  ipaddr                    inet check(ipaddr isnull or masklen(ipaddr) = 32),
  ethernet                  macaddr check (ethernet notnull or ipaddr notnull),
  wall_plate                text,
  ssh_hostkey               text,
  status                    netstatus not null,
  comments                  text,
  mxhost                    text default 'mx.cs.brown.edu',
  netboot                   text,
  dirty                     dirtystate,
  constraint pk_netobj primary key (dns_name,domain)
) ;

-- switch
create table switch (
  switch_name               text not null,
  type                      text not null,
  port_prefix               text not null,
  connection                text not null default 'ssh',
  username                  text not null default 'compsci',
  num_ports                 int not null,
  pass                      text not null default 'dayvoL',
  constraint pk_switch primary key (switch_name)
) ;

-- switchport
create table switchport (
  switch_name               text not null,
  port_num                  int check (port_num >= 0 and port_num <= num_ports(switch_name)) not null,
  wall_plate                text unique not null,
  vlan                      int4 check(check_vlan(vlan) notnull) default 36,
  dirty                     dirtystate not null,
  constraint pk_switchport primary key (switch_name,port_num)
) ;

-- machine
create table machine (
  machine_name              text not null,
  system_model              text,
  num_cpus                  int,
  cpu_type                  text,
  cpu_speed                 text,
  memory                    text,
  hard_drives               text,
  total_disk                text,
  other_drives              text,
  network_cards             text,
  video_cards               text,
  info_time                 timestamp,
  boot_time                 timestamp,
  comments                  text,
  constraint pk_machine primary key (machine_name)
) ;

-- purchase
create table purchase (
  cs_id                     int4 not null,
  po_num                    text not null,
  serial_num                text,
  brown_inv_num             text,
  accounts                  text,
  date                      date not null,
  comments                  text
) ;

-- surplus
create table surplus (
  cs_id                     int4 not null,
  surplus_date              date,
  sale_date                 date,
  buyer                     text,
  CHECK (surplus_date NOTNULL OR sale_date NOTNULL) ,
  constraint pk_surplus primary key (cs_id)
) ;

-- aliases
create table aliases (
  alias                     text not null,
  dns_name                  text not null,
  domain                    text not null,
  comments                  text,
  mxhost                    text default 'mx.cs.brown.edu',
  status                    netstatus not null,
  dirty                     dirtystate not null,
  constraint pk_aliases primary key (alias,dns_name,domain)
) ;

-- class_list
create table class_list (
  machine_name              text not null,
  os_name                   text not null not null,
  class                     text not null not null,
  constraint pk_class_list primary key (machine_name,os_name,class)
) ;

-- os
create table os (
  machine_name              text not null,
  os_name                   text not null,
  version                   text,
  dist                      text,
  constraint pk_os primary key (machine_name,os_name)
) ;

-- dhcp_log
create table dhcp_log (
  ethernet                  macaddr not null,
  ipaddr                    inet not null,
  date                      date not null,
  constraint pk_dhcp_log primary key (ethernet)
) ;

-- macaddr_log
create table macaddr_log (
  switch_name               text not null,
  port                      int4 not null,
  macaddr                   text,
  date                      date not null,
  constraint pk_macaddr_log primary key (switch_name,port)
) ;

-- dirty_files
create table dirty_files (
  filename                  text not null,
  dirty                     bool default true,
  constraint pk_dirty_files primary key (filename)
) ;

-- accounts
create table accounts (
  uid                       int4  default nextval('uid_seq') not null,
  person_id                 int4 unique not null,
  login                     text unique not null,
  net_id                    text,
  gid                       text,
  shell                     text,
  home_dir                  text,
  created                   date,
  expiration                date,
  comments                  text,
  dirty                     dirtystate not null,
  constraint pk_accounts primary key (uid)
) ;

-- group_list
create table group_list (
  group_name                text not null,
  login                     text not null,
  constraint pk_group_list primary key (group_name,login)
) ;

-- identity_list
create table identity_list (
  identity                  text not null,
  login                     text not null,
  constraint pk_identity_list primary key (identity,login)
) ;

-- sponsors
create table sponsors (
  sponsor                   text not null not null,
  sponsee                   text not null not null,
  constraint pk_sponsors primary key (sponsor,sponsee)
) ;

-- mail_aliases
create table mail_aliases (
  alias                     text not null,
  target                    text not null,
  type                      text not null
) ;

-- groups
create table groups (
  gid                       int4 not null,
  group_name                text unique not null,
  created                   date,
  comments                  text,
  constraint pk_groups primary key (gid)
) ;

-- identities
create table identities (
  identity                  text not null,
  space                     int4 not null,
  constraint pk_identities primary key (identity)
) ;

-- net_relation
create table net_relation (
  equip_name                text  not null,
  dns_name                  text not null,
  domain                    text not null,
  constraint pk_net_relation primary key (equip_name,dns_name,domain)
) ;

-- equip_users
create table equip_users (
  equip_name                text not null,
  person_id                 int4 not null,
  constraint pk_equip_users primary key (equip_name,person_id)
) ;

-- passwords
create table passwords (
  login                     text not null,
  passwd                    text not null,
  sslpasswd                 text,
  pptppasswd                text,
  dirty                     dirtystate not null,
  constraint pk_passwords primary key (login)
) ;

-- people
create table people (
  person_id                 int4 default nextval('person_id_seq') not null,
  full_name                 text,
  net_id                    text,
  office                    text,
  office_phone              text,
  home_phone                text,
  comments                  text,
  constraint pk_people primary key (person_id)
) ;

-- faculty
create table faculty (
  person_id                 int4 not null,
  comments                  text,
  constraint pk_faculty primary key (person_id)
) ;

-- grads
create table grads (
  person_id                 int4 not null,
  comments                  text,
  constraint pk_grads primary key (person_id)
) ;

-- staff
create table staff (
  person_id                 int4 not null,
  comments                  text,
  constraint pk_staff primary key (person_id)
) ;

-- ugrads
create table ugrads (
  person_id                 int4 not null,
  comments                  text,
  constraint pk_ugrads primary key (person_id)
) ;

-- net_service
create table net_service (
  dns_name                  text not null,
  domain                    text not null,
  class                     text not null,
  comments                  text,
  constraint pk_net_service primary key (dns_name,domain,class)
) ;

-- classes
create table classes (
  class                     text not null not null,
  comments                  text,
  constraint pk_classes primary key (class)
) ;

-- fs_exports
create table fs_exports (
  fs_class                  text not null,
  host                      text,
  host_path                 text,
  mount_point               text,
  automount_point           text,
  quota                     int4,
  flags                     text
) ;

-- fs_classes
create table fs_classes (
  fs_class                  text not null,
  perms                     text,
  constraint pk_fs_classes primary key (fs_class)
) ;


-- Generated SQL Views
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.9
--     Generated at:      Mon Mar 28 12:58:06 2005
--     Input File:        schema.dia



-- Special statements for postgres:post databases
-- functions which need to be redeclared
CREATE OR REPLACE FUNCTION num_ports(TEXT)
  RETURNS INT
  AS 'SELECT num_ports FROM switch WHERE switch_name = $1'
  LANGUAGE 'sql';


-- Generated Permissions
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.9
--     Generated at:      Mon Mar 28 12:58:06 2005
--     Input File:        schema.dia



-- Generated SQL Insert statements
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.9
--     Generated at:      Mon Mar 28 12:58:06 2005
--     Input File:        schema.dia


-- inserts for vlan_list
insert into vlan_list values ( '31','128.148.31.0/24', 'trusted' ) ;
insert into vlan_list values ( '32','128.148.32.0/25', 'tstaff dmz' ) ;
insert into vlan_list values ( '33','128.148.33.0/24', 'trusted' ) ;
insert into vlan_list values ( '36','128.148.36.0/24', 'user managed' ) ;
insert into vlan_list values ( '37','128.148.37.0/24', 'trusted' ) ;
insert into vlan_list values ( '38','128.148.38.0/24', 'trusted' ) ;
insert into vlan_list values ( '192', '192.168.1.0/24', 'private for switch' ) ;
insert into vlan_list values ( '892', '128.148.32.128/25', 'user dmz' ) ;
insert into vlan_list values ( '893', '192.168.100.0/24', 'ilab private' ) ;
insert into vlan_list values ( '897', '192.168.10.0/24', 'ilab private for switches' ) ;
insert into vlan_list values ( '898', '10.116.0.0/16', 'ilab' ) ;


-- Generated SQL Constraints
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.9
--     Generated at:      Mon Mar 28 12:58:06 2005
--     Input File:        schema.dia

alter table class_list add constraint fk_os_class_list foreign key (machine_name,os_name) references os (machine_name,os_name) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table switchport add constraint fk_switch_switchport foreign key (switch_name) references switch (switch_name) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table surplus add constraint fk_equip_surplus foreign key (cs_id) references equipment (cs_id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table purchase add constraint fk_equip_purchase foreign key (cs_id) references equipment (cs_id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table os add constraint fk_machine_os foreign key (machine_name) references machine (machine_name) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table aliases add constraint fk_netobj_aliases foreign key (dns_name,domain) references netobj (dns_name,domain) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table group_list add constraint fk_accounts_group_list foreign key (login) references accounts (login) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table identity_list add constraint fk_accounts_identity_list foreign key (login) references accounts (login) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table sponsors add constraint fk_accounts_sponsor foreign key (sponsor) references accounts (login) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table sponsors add constraint fk_accounts_sponsee foreign key (sponsee) references accounts (login) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table group_list add constraint fk_groups_group_list foreign key (group_name) references groups (group_name) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table net_relation add constraint fk_netobj_net_relation foreign key (dns_name,domain) references netobj (dns_name,domain) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table net_relation add constraint fk_equip_net_relation foreign key (equip_name) references equipment (equip_name) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table equip_users add constraint fk_equip_equip_users foreign key (equip_name) references equipment (equip_name) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table passwords add constraint fk_accounts_passwd foreign key (login) references accounts (login) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table equip_users add constraint fk_people_equip_users foreign key (person_id) references people (person_id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table accounts add constraint fk_people_accounts foreign key (person_id) references people (person_id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table identity_list add constraint fk_identities_identity_list foreign key (identity) references identities (identity) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table machine add constraint fk_equip_machine foreign key (machine_name) references equipment (equip_name) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table switch add constraint fk_equip_switch foreign key (switch_name) references equipment (equip_name) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table netobj add constraint fk_switchport_netobj foreign key (wall_plate) references switchport (wall_plate) ON UPDATE CASCADE ;
alter table faculty add constraint fk_people_faculty foreign key (person_id) references people (person_id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table grads add constraint fk_people_grads foreign key (person_id) references people (person_id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table staff add constraint fk_people_staff foreign key (person_id) references people (person_id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table ugrads add constraint fk_people_ugrads foreign key (person_id) references people (person_id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table net_service add constraint fk_netobj_net_service foreign key (dns_name,domain) references netobj (dns_name,domain) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table class_list add constraint fk_classes_class_list foreign key (class) references classes (class) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table net_service add constraint fk_classes_net_service foreign key (class) references classes (class) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table fs_exports add constraint fk_fs_classes_fs_exports foreign key (fs_class) references fs_classes (fs_class) ON DELETE CASCADE ON UPDATE CASCADE ;
