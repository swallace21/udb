-- ================================================================================
--   postgres SQL DDL Script File
-- ================================================================================


-- ===============================================================================
-- 
--   Generated by:      tedia2sql -- v1.2.12
--                      See http://tedia2sql.tigris.org/AUTHORS.html for tedia2sql author information
-- 
--   Target Database:   postgres
--   Generated at:      Mon Nov 17 23:10:44 2008
--   Input Files:       schema.dia
-- 
-- ================================================================================



-- Generated SQL Constraints Drop statements
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.12
--     Generated at:      Mon Nov 17 23:10:42 2008
--     Input Files:       schema.dia



-- Generated Permissions Drops
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.12
--     Generated at:      Mon Nov 17 23:10:42 2008
--     Input Files:       schema.dia



-- Special statements for postgres:pre databases
-- sequence variables
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
VALUE = 'remote' OR
VALUE = 'disabled');

DROP DOMAIN NETDOMAIN CASCADE;
CREATE DOMAIN NETDOMAIN TEXT NOT NULL CHECK(
VALUE = 'intranet' OR
VALUE = 'ilab' OR
VALUE = 'wan' OR
VALUE = 'dmz');

DROP DOMAIN EQUIPSTATUS CASCADE;
CREATE DOMAIN EQUIPSTATUS TEXT NOT NULL CHECK(
VALUE = 'deployed' OR
VALUE = 'spare' OR
VALUE = 'surplus');

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
--     SQL Generator:     tedia2sql -- v1.2.12
--     Generated at:      Mon Nov 17 23:10:42 2008
--     Input Files:       schema.dia



-- Generated SQL Schema Drop statements
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.12
--     Generated at:      Mon Nov 17 23:10:42 2008
--     Input Files:       schema.dia



-- Generated SQL Schema
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.12
--     Generated at:      Mon Nov 17 23:10:42 2008
--     Input Files:       schema.dia


-- equipment
create table equipment (
  id                        serial not null,
  parent_equip_id           int4,
  cs_id                     int4 unique default nextval ('cs_id_seq'),
  equip_name                text unique,
  descr                     text not null,
  install_date              date,
  po_num                    text,
  owner                     text,
  contact                   text,
  usage                     usage,
  building                  text,
  floor                     text,
  room                      text,
  comments                  text,
  serial_num                text,
  brown_inv_num             text,
  equip_status              equipstatus not null,
  purchase_orders_id        serial not null,
  constraint pk_equipment primary key (id)
) ;

-- net_objects
create table net_objects (
  id                        serial not null,
  dns_name                  text,
  domain                    netdomain,
  ipaddr                    inet check(ipaddr isnull or masklen(ipaddr) = 32),
  ethernet                  macaddr check (ethernet notnull or ipaddr notnull),
  wall_plate                text,
  ssh_hostkey               text,
  status                    netstatus not null,
  comments                  text,
  netboot                   text,
  monitored                 boolean,
  last_changed              timestamp default now(),
  net_ports_id              serial not null,
  constraint pk_net_objects primary key (id)
) ;

-- net_switches
create table net_switches (
  id                        serial not null,
  switch_name               text,
  type                      text not null,	-- type of switch
  port_prefix               text not null,
  connection                text not null default 'ssh',
  username                  text not null default 'CS_Admin2',
  num_ports                 int not null,
  pass                      text not null default 'Or10N99',
  equipment_id              serial not null,
  constraint pk_net_switches primary key (id)
) ;

-- net_ports
create table net_ports (
  id                        serial not null,
  switch_name               text,
  port_num                  int check (port_num >= 0 and port_num <= num_ports(switch_name)),
  wall_plate                text unique not null,
  vlan                      int4 check(check_vlan(vlan) notnull) default 36,
  last_changed              timestamp default now(),
  net_switches_id           serial not null,
  constraint pk_net_ports primary key (id)
) ;

-- computers
create table computers (
  id                        serial not null,
  machine_name              text,
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
  equipment_id              serial not null,
  comp_classes_id           serial not null,
  constraint pk_computers primary key (id)
) ;

-- purchase_orders
create table purchase_orders (
  id                        serial not null,
  po_num                    text,
  req_num                   text,
  date                      date,
  for_by                    text,
  vendor                    text,
  product                   text,
  account1                  text,
  account2                  text,
  account3                  text,
  account4                  text,
  cost1                     float4,
  cost2                     float4,
  cost3                     float4,
  cost4                     float4,
  comments                  text,
  constraint pk_purchase_orders primary key (id)
) ;

-- surplus_equipment
create table surplus_equipment (
  surplus_date              date,
  sale_date                 date,
  buyer                     text,
  CHECK (surplus_date NOTNULL OR sale_date NOTNULL) ,
  equipment_id              serial not null
) ;

-- net_aliases
create table net_aliases (
  alias                     text,
  dns_name                  text,
  domain                    text,
  comments                  text,
  status                    netstatus not null,
  last_changed              timestamp default now(),
  net_objects_id            serial not null
) ;

-- comp_class_pairs
create table comp_class_pairs (
  machine_name              text not null,
  class                     text not null not null,
  comp_classes_id           serial not null,
  constraint pk_comp_class_pairs primary key (machine_name,class)
) ;

-- os
create table os (
  machine_name              text,
  os_name                   text,
  version                   text,
  dist                      text,
  computers_id              serial not null
) ;

-- log_dhcp
create table log_dhcp (
  ethernet                  macaddr,
  ipaddr                    inet not null,
  date                      date not null
) ;

-- log_macaddr
create table log_macaddr (
  switch_name               text,
  port                      int4,
  macaddr                   text,
  date                      date not null
) ;

-- log_db_export
create table log_db_export (
  script_name               text,
  last_run                  timestamp default now()
) ;

-- accounts
create table accounts (
  id                        serial not null,
  uid                       int4  default nextval('uid_seq'),
  person_id                 int4 not null,
  login                     text unique not null,
  gid                       int4,
  shell                     text,
  home_dir                  text,
  created                   date,
  expiration                date,
  comments                  text,
  last_changed              timestamp default now(),
  people_id                 serial not null,
  constraint pk_accounts primary key (id)
) ;

-- group_list
create table group_list (
  group_name                text,
  login                     text,
  accounts_id               serial not null,
  groups_id                 serial not null
) ;

-- mail_aliases
create table mail_aliases (
  alias                     text not null,
  target                    text not null,
  type                      text not null
) ;

-- groups
create table groups (
  id                        serial not null,
  gid                       int4,
  group_name                text unique not null,
  created                   date,
  comments                  text,
  space                     int4 not null,
  constraint pk_groups primary key (id)
) ;

-- net_relations
create table net_relations (
  equip_name                text ,
  dns_name                  text,
  domain                    text,
  net_objects_id            serial not null,
  equipment_id              serial not null
) ;

-- equip_users
create table equip_users (
  equipment_id              serial not null
) ;

-- people
create table people (
  id                        serial not null,
  full_name                 text,
  common_name               text,
  family_name               text,
  alternate_email           text,
  auth_id                   text,
  username                  text,
  brown_card_id             text,
  gender                    text,
  ethnicity                 text,
  citizenship               text,
  office                    text,
  office_phone              text,
  home_phone                text,
  cell_phone                text,
  comments                  text,
  banner_id                 text,
  sponsor                   serial not null,
  constraint pk_people primary key (id)
) ;

-- faculty
create table faculty (
  comments                  text,
  people_id                 serial not null
) ;

-- staff
create table staff (
  comments                  text,
  people_id                 serial not null
) ;

-- ugrads
create table ugrads (
  comments                  text,
  people_id                 serial not null
) ;

-- comp_classes
create table comp_classes (
  id                        serial not null,
  class                     text not null,
  comments                  text,
  constraint pk_comp_classes primary key (id)
) ;

-- fs_exports
create table fs_exports (
  server                    text,
  path                      text,
  fs_class                  text not null,
  quota                     int4,
  flags                     text,
  backup_policy             text,
  fs_classes_id             serial not null
) ;

-- fs_classes
create table fs_classes (
  id                        serial not null,
  fs_class                  text,
  perms                     text,
  constraint pk_fs_classes primary key (id)
) ;

-- fs_automounts
create table fs_automounts (
  client_path               text,
  server                    text,
  server_path               text,
  flags                     text
) ;

-- grads
create table grads (
  id                        serial not null,
  program                   text,
  year_entered              text,
  advisor                   text,
  thesis_advisor1           text,
  thesis_advisor2           text,
  thesis_advisor3           text,
  prog_comp1                text,
  prog_comp2                text,
  res_prop                  text,
  res_prop_date             date,
  res_pres                  text,
  res_pres_date             date,
  entered_candidacy         date,
  thesis_prop_date          date,
  thesis_def_date           date,
  thesis_submit_date        date,
  comments                  text,
  people_id                 serial not null,
  constraint pk_grads primary key (id)
) ;

-- courses
create table courses (
  course                    text,
  year                      text,
  name                      text,
  description               text,
  instructor                text,
  level_100                 text default 'N',
  level_200                 text default 'N',
  phd_area1                 text,
  phd_area2                 text,
  ugrad_area                text,
  scm_theory                text default 'N',
  scm_practice              text default 'N',
  scm_prog                  text default 'N',
  scm_research              text default 'N',
  comments                  text
) ;

-- enrollment
create table enrollment (
  course                    text,
  year                      text,
  grade                     text,
  level_100                 boolean,
  level_200                 boolean,
  phd_seq                   text,
  phd_area                  text,
  ugrad_area                text,
  scm_theory                boolean,
  scm_practice              boolean,
  scm_prog                  boolean,
  scm_research              boolean,
  comments                  text,
  people_id                 serial not null
) ;

-- grad_funding
create table grad_funding (
  year                      text,
  semester                  text,
  source                    text,
  comments                  text,
  grads_id                  serial not null
) ;

-- grad_reports
create table grad_reports (
  name                      text,
  description               text,
  fields                    text,
  query                     text
) ;

-- grad_standing
create table grad_standing (
  date                      date,
  standing                  text,
  comments                  text,
  grads_id                  serial not null
) ;

-- net_services
create table net_services (
  dns_name                  text,
  domain                    text,
  service                   text,
  comments                  text,
  net_objects_id            serial not null
) ;


comment on column net_switches.type is 'type of switch';


































-- Generated SQL Views
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.12
--     Generated at:      Mon Nov 17 23:10:42 2008
--     Input Files:       schema.dia



-- Special statements for postgres:post databases
-- functions which need to be redeclared
CREATE OR REPLACE FUNCTION num_ports(TEXT)
  RETURNS INT
  AS 'SELECT num_ports FROM switch WHERE switch_name = $1'
  LANGUAGE 'sql';

GRANT UPDATE ON person_id_seq TO GROUP graddb;


-- Generated Permissions
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.12
--     Generated at:      Mon Nov 17 23:10:42 2008
--     Input Files:       schema.dia

grant select on accounts to GROUP graddb ;
grant all on people to GROUP graddb ;
grant all on grads to GROUP graddb ;
grant all on courses to GROUP graddb ;
grant all on enrollment to GROUP graddb ;
grant all on grad_funding to GROUP graddb ;
grant select on grad_reports to GROUP graddb ;
grant insert,update on grad_reports to GROUP graddb_admin ;
grant all on grad_standing to GROUP graddb ;


-- Generated SQL Insert statements
-- --------------------------------------------------------------------
--     Target Database:   postgres
--     SQL Generator:     tedia2sql -- v1.2.12
--     Generated at:      Mon Nov 17 23:10:42 2008
--     Input Files:       schema.dia


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
--     SQL Generator:     tedia2sql -- v1.2.12
--     Generated at:      Mon Nov 17 23:10:42 2008
--     Input Files:       schema.dia

create index idx_accounts_personid on accounts  (person_id) ;
create index idx_people_family_name on people  (family_name) ;
alter table net_ports add constraint net_ports_fk_net_switches_id
  foreign key (net_switches_id)
  references net_switches (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table surplus_equipment add constraint surplus_equipment_fk_equipment_id
  foreign key (equipment_id)
  references equipment (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table equipment add constraint equipment_fk_purchase_orders_id
  foreign key (purchase_orders_id)
  references purchase_orders (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table os add constraint os_fk_computers_id
  foreign key (computers_id)
  references computers (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table net_aliases add constraint net_aliases_fk_net_objects_id
  foreign key (net_objects_id)
  references net_objects (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table group_list add constraint group_list_fk_accounts_id
  foreign key (accounts_id)
  references accounts (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table people add constraint people_fk_sponsor
  foreign key (sponsor)
  references accounts (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table group_list add constraint group_list_fk_groups_id
  foreign key (groups_id)
  references groups (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table net_relations add constraint net_relations_fk_net_objects_id
  foreign key (net_objects_id)
  references net_objects (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table net_relations add constraint net_relations_fk_equipment_id
  foreign key (equipment_id)
  references equipment (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table equip_users add constraint equip_users_fk_equipment_id
  foreign key (equipment_id)
  references equipment (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table accounts add constraint accounts_fk_people_id
  foreign key (people_id)
  references people (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table computers add constraint computers_fk_equipment_id
  foreign key (equipment_id)
  references equipment (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table net_switches add constraint net_switches_fk_equipment_id
  foreign key (equipment_id)
  references equipment (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table net_objects add constraint net_objects_fk_net_ports_id
  foreign key (net_ports_id)
  references net_ports (id) ON UPDATE CASCADE ;
alter table faculty add constraint faculty_fk_people_id
  foreign key (people_id)
  references people (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table grads add constraint grads_fk_people_id
  foreign key (people_id)
  references people (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table staff add constraint staff_fk_people_id
  foreign key (people_id)
  references people (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table ugrads add constraint ugrads_fk_people_id
  foreign key (people_id)
  references people (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table comp_class_pairs add constraint comp_class_pairs_fk_comp_classes_id
  foreign key (comp_classes_id)
  references comp_classes (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table computers add constraint computers_fk_comp_classes_id
  foreign key (comp_classes_id)
  references comp_classes (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table fs_exports add constraint fs_exports_fk_fs_classes_id
  foreign key (fs_classes_id)
  references fs_classes (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table equipment add constraint equipment_fk_parent_equip_id
  foreign key (parent_equip_id)
  references equipment (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table grad_funding add constraint grad_funding_fk_grads_id
  foreign key (grads_id)
  references grads (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table enrollment add constraint enrollment_fk_people_id
  foreign key (people_id)
  references people (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table grad_standing add constraint grad_standing_fk_grads_id
  foreign key (grads_id)
  references grads (id) ON DELETE CASCADE ON UPDATE CASCADE ;
alter table net_services add constraint net_services_fk_net_objects_id
  foreign key (net_objects_id)
  references net_objects (id) ON DELETE CASCADE ON UPDATE CASCADE ;

