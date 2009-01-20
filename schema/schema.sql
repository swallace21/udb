--------------
-- Internal --
--------------

-- {{{

create table log_db_export (
  script_name               text,
  last_run                  timestamp default now()
) ;

-- }}}

-----------------------------
-- Equipment documentation --
-----------------------------

-- {{{

create domain usage text not null check (
value = 'tstaff' or
value = 'research' or
value = 'personal');

create domain equipstatus text not null check (
value = 'deployed' or
value = 'spare' or
value = 'surplus');

create domain equipmanaged text not null check (
value = 'tstaff' or
value = 'cis' or
value = 'user');

create sequence cs_id_seq;

create table purchase_orders (
  id                        serial primary key,
  po_num                    numeric unique,
  req_num                   numeric unique,
  purchased_on              date,
  for_by                    text,
  vendor                    text,
  product                   text,
  account1                  text,
  account2                  text,
  account3                  text,
  account4                  text,
  cost1                     numeric,
  cost2                     numeric,
  cost3                     numeric,
  cost4                     numeric,
  comments                  text
) ;

create table equipment (
  id                        serial primary key,
  parent_equip_id           integer references equipment
                              on update cascade
                              on delete cascade,
  po_num                    integer references purchase_orders
                              on update cascade
                              on delete cascade,
  cs_id                     integer unique default nextval('cs_id_seq'),
  equip_status              equipstatus not null,
  equip_name                text unique,
  usage                     usage,
  installed_on              date,
  descr                     text not null,
  po_num                    text,
  owner                     text,
  contact                   text,
  building                  text,
  floor                     text,
  room                      text,
  comments                  text,
  serial_num                text,
  brown_inv_num             text
) ;

create table surplus_equipment (
  id                        serial primary key,
  equipment_id              integer references equipment
                              on update cascade
                              on delete cascade,
  surplus_date              date,
  sale_date                 date,
  buyer                     text,
  check (surplus_date is not null or sale_date is not null)
) ;

-- }}}

-------------
-- Network --
-------------

-- {{{

create or replace function num_ports(integer) returns integer as 'select 0' language 'sql';

create table net_switches (
  id                        serial primary key,
  equipment_id              integer references equipment
                              on update cascade
                              on delete cascade,
  num_ports                 integer not null,
  num_blades                integer,
  switch_type               text not null,
  port_prefix               text not null,
  connection                text not null default 'ssh',
  username                  text not null,
  pass                      text not null,
  comments                  text,
) ;

create table net_ports (
  id                        serial primary key,
  switch_id                 integer references net_switches
                              on update cascade
                              on delete cascade,
  port_num                  integer not null,
  wall_plate                text unique not null,
  last_changed              timestamp not null default now(),
  blade_num                 integer,
  -- check that port is unique in switch
  check (port_num >= 0 and port_num <= num_ports(net_switches_id))
) ;

create table net_interfaces (
  id                        serial primary key,
  equipment_id              integer references equipment
                              on update cascade
                              on delete cascade,
  net_ports_id              integer references net_ports
                              on update cascade
                              on delete set null,
  ethernet                  macaddr not null,
  last_changed              timestamp not null default now(),
  comments                  text
) ;

create table net_services (
  id                        serial primary key,
  service                   text not null,
  comments                  text,
) ;

create table net_zones (
  id                        serial primary key,
  comments                  text,
) ;

create table net_vlans (
  id                        serial primary key,
  net_zones_id              integer references net_zones
                              on update cascade
                              on delete cascade,
  vlan_num                  integer unique not null,
  network                   cidr not null,
  comments                  text
) ;

-- net_addresses
create table net_addresses (
  id                        serial primary key,
  net_vlans_id              integer references net_vlans
                              on update cascade
                              on delete cascade,
  dns_name                  text not null,
  ipaddr                    inet,
  enabled                   boolean not null default true,
  monitored                 boolean not null,
  last_changed              timestamp not null default now(),
  comments                  text,
  -- each dns name should be unique in a zone
  unique (dns_name, zone),
  check (ipaddr is null or masklen(ipaddr) = 32)
) ;

create table net_aliases (
  alias                     text primary key,
  net_addresses_id          integer references net_addresses
                              on update cascade
                              on delete cascade,
  last_changed              timestamp not null default now(),
  comments                  text,
) ;

-- join tables {{{
create table net_ports_net_vlans (
  net_ports_id              integer references net_ports
                              on update cascade
                              on delete cascade,
  net_vlans_id              integer references net_vlans
                              on update cascade
                              on delete cascade,
  primary key               (net_ports_id, net_vlans_id)
) ;

create table net_addresses_net_interfaces (
  net_addresses_id          integer references net_addresses
                              on update cascade
                              on delete cascade,
  net_interfaces_id         integer references net_interfaces
                              on update cascade
                              on delete cascade,
  primary key               (net_addresses_id, net_interfaces_id)
) ;

create table net_addresses_net_services (
  net_addresses_id          integer references net_addresses
                              on update cascade
                              on delete cascade,
  net_services_id           integer references net_services
                              on update cascade
                              on delete cascade,
  primary key               (net_addresses_id, net_services_id)
) ;
-- }}}

create or replace function num_ports(integer)
  returns integer
  as 'select num_ports from switch where id = $1'
  language 'sql';

create table log_dhcp (
  id                        serial primary key,
  entry_time                timestamp not null default now(),
  ethernet                  macaddr not null,
  ipaddr                    inet not null,
  data                      text
) ;

create table log_macaddr (
  id                        serial primary key,
  entry_time                timestamp not null default now(),
  switch_name               text,
  port                      integer,
  macaddr                   text,
  data                      text
) ;

-- }}}

----------------------------
-- People, Users, Courses --
----------------------------

-- {{{

create domain userstatus text not null check (
value = 'ugrad' or
value = 'grad' or
value = 'fac' or
value = 'staff' or
value = 'guest');

create sequence uid_seq;
create sequence gid_seq;

create table people (
  id                        serial primary key,
  user_status               userstatus,
  full_name                 text,
  common_name               text,
  family_name               text,
  alternate_email           text,
  auth_id                   text,
  brown_card_id             text unique,
  gender                    text,
  office                    text,
  office_phone              text,
  home_phone                text,
  cell_phone                text,
  comments                  text,
) ;

create index idx_people_family_name on people  (family_name) ;

create table user_accounts (
  id                        serial primary key,
  people_id                 integer references people
                              on update cascade
                              on delete cascade,
  uid                       integer unique not null default nextval('uid_seq'),
  gid                       integer unique not null default nextval('gid_seq'),
  login                     text unique not null,
  shell                     text not null,
  home_dir                  text not null,
  created                   date not null,
  expiration                date,
  comments                  text,
  last_changed              timestamp not null default now()
) ;

create table mail_aliases (
  id                        serial primary key,
  user_accounts_id          integer references user_accounts
                              on update cascade
                              on delete cascade,
  alias                     text not null,
  target                    text not null,
  alias_type                text not null,
  comments                  text
) ;

create table user_groups (
  id                        serial primary key,
  gid                       integer unique not null,
  group_name                text unique not null default nextval('gid_seq'),
  created                   date,
  quota                     integer not null,
  comments                  text
) ;

create table courses (
  id                        serial primary key,
  course                    text,
  year                      text,
  name                      text,
  description               text,
  instructor                text,
  level_100                 boolean,
  level_200                 boolean,
  phd_area1                 text,
  phd_area2                 text,
  ugrad_area                text,
  scm_theory                boolean,
  scm_practice              boolean,
  scm_prog                  boolean,
  scm_research              boolean,
  comments                  text
) ;

create table enrollment (
  id                        serial primary key,
  student_id                integer references people
                              on update cascade
                              on delete cascade,
  course_id                 integer references courses
                              on update cascade
                              on delete cascade,
  year                      text,
  grade                     text,
  phd_seq                   text,
  phd_area                  text,
  ugrad_area                text,
  level_100                 boolean,
  level_200                 boolean,
  scm_theory                boolean,
  scm_practice              boolean,
  scm_prog                  boolean,
  scm_research              boolean,
  comments                  text
) ;

-- user_accounts_people
-- association between user_accounts and people
create table user_accounts_people (
  user_accounts_id          integer references user_accounts
                              on update cascade
                              on delete cascade,
  sponsor_id                integer references people
                              on update cascade
                              on delete cascade,
  primary key               (user_accounts_id, sponsor_id)
) ;

-- user_groups_user_accounts
-- association between user_groups and user_accounts
create table user_groups_user_accounts (
  user_groups_id            integer references user_groups
                              on update cascade
                              on delete cascade,
  user_accounts_id          integer references user_accounts
                              on update cascade
                              on delete cascade,
  primary key               (user_groups_id, user_accounts_id)
) ;

-- }}}

-----------------
-- Filesystems --
-----------------

-- {{{

create table fs_exports (
  id                        serial primary key,
  server                    text,
  path                      text,
  fs_class                  text not null,
  quota                     integer,
  flags                     text,
  backup_policy             text,
) ;

create table fs_classes (
  fs_class                  text,
  perms                     text,
  fs_exports_id             serial not null
) ;

create table fs_automounts (
  client_path               text,
  server                    text,
  server_path               text,
  flags                     text
) ;

-- }}}

---------------------
-- Computers (CDB) --
---------------------

-- {{{

create table computers (
  id                        serial primary key,
  equipment_id              integer references equipment
                              on update cascade
                              on delete cascade,
  machine_name              text unique not null,
  system_model              text,
  num_cpus                  integer,
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
  pxelink                   text,
  comments                  text
) ;

create table comp_os (
  id                        serial primary key,
  computer_id               integer references computers
                              on update cascade
                              on delete cascade,
  os_name                   text,
  version                   text,
  dist                      text,
  comments                  text
) ;

create table comp_classes (
  id                        serial primary key,
  class                     text unique not null,
  comments                  text,
) ;

-- join tables {{{
create table comp_classes_computers (
  comp_classes_id           integer references comp_classes,
                              on update cascade
                              on delete cascade,
  computers_id              integer references computers
                              on update cascade
                              on delete cascade,
  primary key               (comp_classes_id, computers_id)
) ;
-- }}}

-- }}}

-------------
-- General --
-------------

-- {{{

-- association between equipment and people
create table equipment_people (
  equipment_id              integer references equipment
                              on update cascade
                              on delete cascade,
  equip_user_id             integer references people
                              on update cascade
                              on delete cascade,
  primary key               (equipment_id, equip_user_id)
) ;

-- }}}

