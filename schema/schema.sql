--------------
-- Internal --
--------------

-- {{{

create language plpgsql;

create table log_db_export (
  script_name               text,
  last_run                  timestamp default now()
) ;

create or replace function commacat(acc text, instr text) returns text as
$$                                                                                        
begin                  
  if acc is null or acc = '' then
    return instr;
  else
    return acc || ', ' || instr;
  end if;
end;
$$ language plpgsql;

create aggregate textcat_all (
  basetype    = text,
  sfunc       = commacat,
  stype       = text,
  initcond    = ''
);

-- }}}

------------
-- Places --
------------

-- {{{

create table places (
  id                        serial primary key,
  city                      text,
  building                  text,
  room                      text
) ;

-- }}}

-----------------------------
-- Equipment documentation --
-----------------------------

-- {{{

create table equip_usage_types (
  name                      text primary key
) ;

create table management_types (
  name                      text primary key
) ;

create table equip_status_types (
  name                      text primary key
) ;

create sequence cs_id_seq;

create table purchase_orders (
  po_num                    numeric primary key,
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
  cost4                     numeric
) ;

create table equipment (
  name                      text primary key,
  parent_equip_id           text references equipment
                              on update cascade
                              on delete cascade,
  po_num                    integer references purchase_orders
                              on update cascade
                              on delete cascade,
  place_id                  integer references places
                              on update cascade
                              on delete cascade,
  cs_id                     integer unique default nextval('cs_id_seq'),
  equip_status              text not null references equip_status_types
                              on update cascade
                              on delete restrict,
  usage                     text not null references equip_usage_types
                              on update cascade
                              on delete restrict,
  managed_by                text not null references management_types
                              on update cascade
                              on delete restrict,
  installed_on              date,
  descr                     text,
  owner                     text,
  contact                   text,
  serial_num                text,
  brown_inv_num             text
) ;

create table surplus_equipment (
  name                      text not null references equipment
                              on update cascade
                              on delete cascade,
  primary key (name),
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

create domain routing_type text not null check (
value = 'standard' or
value = 'private' or
value = 'DMZ' or
value = 'special');

create domain dns_type text not null check (
value = 'internal' or
value = 'external' or
value = 'both');

create or replace function num_ports(text) returns integer as 'select 0' language 'sql';
create or replace function vlan_zone(integer) returns text as 'select cast('''' as text)' language 'sql';

create table net_switches (
  name                      text not null references equipment
                              on update cascade
                              on delete cascade,
  primary key (name),
  num_ports                 integer not null,
  num_blades                integer,
  switch_type               text not null,
  port_prefix               text not null,
  connection                text not null default 'ssh',
  username                  text not null,
  pass                      text not null
) ;

create table net_ports (
  id                        serial primary key,
  switch                    text not null references net_switches
                              on update cascade
                              on delete cascade,
  port_num                  integer not null,
  wall_plate                text unique not null,
  last_changed              timestamp not null default now(),
  blade_num                 integer,
  unique (switch, port_num, blade_num),
  check (port_num >= 0 and port_num <= num_ports(switch))
) ;

create table net_interfaces (
  id                        serial primary key,
  name                      text not null references equipment
                              on update cascade
                              on delete cascade,
  port_id                   integer references net_ports
                              on update cascade
                              on delete set null,
  ethernet                  macaddr not null,
  last_changed              timestamp not null default now()
) ;

create table net_services (
  service                   text primary key
) ;

create table net_zones (
  name                      text primary key,
  manager                   text not null references management_types
                              on update cascade
                              on delete restrict,
  routing                   routing_type,
  dynamic_dhcp              boolean not null default true
) ;

create table net_vlans (
  vlan_num                  integer primary key,
  zone                      text not null references net_zones
                              on update cascade
                              on delete cascade,
  network                   cidr not null
) ;

-- net_addresses
create table net_addresses (
  id                        serial primary key,
  zone                      text not null references net_zones
                              on update cascade
                              on delete cascade,
  vlan_num                  integer not null references net_vlans
                              on update cascade
                              on delete cascade,
  ipaddr                    inet,
  dns_name                  text not null,
  domain                    text not null,
  enabled                   boolean not null default true,
  monitored                 boolean not null,
  last_changed              timestamp not null default now(),
  check (ipaddr is null or masklen(ipaddr) = 32)
) ;

create or replace function update_zone_by_vlan() returns trigger as $update_zone_by_vlan$
declare
  new_vlan_zone             text;
begin
  select (zone) into strict new_vlan_zone from net_vlans
    where vlan_num = new.vlan_num;
  new.zone := new_vlan_zone;
  return new;
end;
$update_zone_by_vlan$ language plpgsql;

create trigger vlan_zone_trigger before insert or update on net_addresses
  for each row execute procedure update_zone_by_vlan();

create table net_dns_entries (
  name                      text not null,
  domain                    text not null,
  zone                      dns_type not null,
  net_address_id            integer not null references net_addresses
                              on update cascade
                              on delete cascade,
  last_changed              timestamp not null default now(),
  primary key               (name, domain, zone)
) ;

-- join tables {{{
create table net_ports_net_vlans (
  net_ports_id              integer not null references net_ports
                              on update cascade
                              on delete cascade,
  net_vlans_id              integer not null references net_vlans
                              on update cascade
                              on delete cascade,
  primary key               (net_ports_id, net_vlans_id)
) ;

create table net_addresses_net_interfaces (
  net_addresses_id          integer not null references net_addresses
                              on update cascade
                              on delete cascade,
  net_interfaces_id         integer not null references net_interfaces
                              on update cascade
                              on delete cascade,
  primary key               (net_addresses_id, net_interfaces_id)
) ;

create table net_addresses_net_services (
  net_addresses_id          integer not null references net_addresses
                              on update cascade
                              on delete cascade,
  net_services_id           text not null references net_services
                              on update cascade
                              on delete cascade,
  primary key               (net_addresses_id, net_services_id)
) ;
-- }}}

create or replace function vlan_zone(integer)
  returns text
  as 'select zone from net_vlans where vlan_num = $1'
  language 'sql';

create or replace function num_ports(text)
  returns integer
  as 'select num_ports from net_switches where name = $1'
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
  cell_phone                text
) ;

create index idx_people_family_name on people  (family_name) ;

create table user_accounts (
  id                        serial primary key,
  people_id                 integer not null references people
                              on update cascade
                              on delete cascade,
  uid                       integer unique not null default nextval('uid_seq'),
  gid                       integer unique not null default nextval('gid_seq'),
  login                     text unique not null,
  shell                     text not null,
  home_dir                  text not null,
  created                   date not null,
  expiration                date,
  enabled                   boolean,
  last_changed              timestamp not null default now()
) ;

create table mail_aliases (
  id                        serial primary key,
  user_accounts_id          integer not null references user_accounts
                              on update cascade
                              on delete cascade,
  alias                     text not null,
  target                    text not null,
  alias_type                text not null
) ;

create table user_groups (
  id                        serial primary key,
  gid                       integer unique not null,
  group_name                text unique not null default nextval('gid_seq'),
  created                   date,
  quota                     integer not null
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
  scm_research              boolean
) ;

create table enrollment (
  id                        serial primary key,
  student_id                integer not null references people
                              on update cascade
                              on delete cascade,
  course_id                 integer not null references courses
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
  scm_research              boolean
) ;

-- user_accounts_people
-- association between user_accounts and people
create table user_accounts_people (
  user_accounts_id          integer not null references user_accounts
                              on update cascade
                              on delete cascade,
  sponsor_id                integer not null references people
                              on update cascade
                              on delete cascade,
  primary key               (user_accounts_id, sponsor_id)
) ;

-- user_groups_user_accounts
-- association between user_groups and user_accounts
create table user_groups_user_accounts (
  user_groups_id            integer not null references user_groups
                              on update cascade
                              on delete cascade,
  user_accounts_id          integer not null references user_accounts
                              on update cascade
                              on delete cascade,
  primary key               (user_groups_id, user_accounts_id)
) ;

-- }}}

-----------------
-- Filesystems --
-----------------

-- {{{

-- create table fs_exports (
--   id                        serial primary key,
--   server                    text,
--   path                      text,
--   fs_class                  text not null,
--   quota                     integer,
--   flags                     text,
--   backup_policy             text
-- ) ;
-- 
-- create table fs_classes (
--   id                        serial primary key,
--   fs_exports_id             integer not null references fs_exports,
--   fs_class                  text,
--   perms                     text
-- ) ;

create table fs_automounts (
  id                        serial primary key,
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

create domain hw_arch_type text check (
value = 'amd64' or
value = 'linksys' or
value = 'mac' or
value = 'mac-ppc' or
value = 'sun4u' or
value = 'x86' or
value = 'xen');

create domain os_type text check (
value = 'dualboot' or
value = 'linux' or
value = 'linux-server' or
value = 'linux-xen' or
value = 'osx' or
value = 'solaris' or
value = 'vista' or
value = 'winxp');

create table computers (
  name                      text not null references equipment
                              on update cascade
                              on delete cascade,
  primary key (name),
  hw_arch                   hw_arch_type,
  os                        os_type,
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
  os_version                text,
  info_time                 timestamp,
  boot_time                 timestamp,
  pxelink                   text
) ;

create table comp_classes (
  class                     text primary key
) ;

-- join tables {{{
create table comp_classes_computers (
  comp_class                text not null references comp_classes
                              on update cascade
                              on delete cascade,
  computer                  text not null references computers
                              on update cascade
                              on delete cascade,
  primary key               (comp_class, computer)
) ;
-- }}}

-- }}}

-------------
-- General --
-------------

-- {{{

-- association between equipment and people
create table equipment_people (
  equipment_name            text not null references equipment
                              on update cascade
                              on delete cascade,
  equip_user_id             integer not null references people
                              on update cascade
                              on delete cascade,
  primary key               (equipment_name, equip_user_id)
) ;

-- }}}

