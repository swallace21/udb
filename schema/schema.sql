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

create or replace function fqdn_brown(hostname text, domain text) returns text as
$$
begin
  if domain = 'cs.brown.edu' then
    return hostname;
  else
    return hostname || '.' || domain;
  end if;
end;
$$ language plpgsql;

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

create table management_types (
  name                      text primary key
) ;

create table equip_status_types (
  name                      text primary key
) ;

create table equipment (
  name                      text primary key,
  parent_equip_id           text references equipment
                              on update cascade
                              on delete cascade,
  place_id                  integer references places
                              on update cascade
                              on delete cascade,
  equip_status              text not null references equip_status_types
                              on update cascade
                              on delete restrict,
  managed_by                text not null references management_types
                              on update cascade
                              on delete restrict,
  brown_inv_num             text,
  serial_num                text,
  po_num                    text,
  purchased_on              date,
  installed_on              date,
  owner                     text,
  contact                   text,
  protected                 boolean not null default false
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

create sequence dns_serial_num_seq;

create table routing_types (
  name                      text primary key
) ;

create table dns_regions (
  name                      text primary key
) ;

create or replace function num_ports(text) returns integer as 'select 0' language 'sql';
create or replace function vlan_zone(integer) returns text as 'select cast('''' as text)' language 'sql';

create table net_zones (
  name                      text primary key,
  zone_manager              text not null references management_types
                              on update cascade
                              on delete restrict,
  equip_manager             text not null references management_types
                              on update cascade
                              on delete restrict,
  routing_type              text not null references routing_types
                              on update cascade
                              on delete restrict,
  dynamic_dhcp              boolean not null default true
) ;

create table net_vlans (
  vlan_num                  integer primary key,
  zone                      text not null references net_zones
                              on update cascade
                              on delete cascade,
  network                   cidr not null,
  gateway                   inet not null,
  dhcp                      boolean not null default true,
  dynamic_dhcp_start        inet,
  dynamic_dhcp_end          inet
) ;

create or replace function update_zone_by_vlan() returns trigger as
$$
declare
  new_vlan_zone             text;
begin
  select (zone) into strict new_vlan_zone from net_vlans
    where vlan_num = new.vlan_num;
  new.zone := new_vlan_zone;
  return new;
end;
$$ language plpgsql;

create or replace function non_dynamic_ip(integer, inet)
returns boolean as $$
  select (
    (nv.dynamic_dhcp_start is null) or
    (nv.dynamic_dhcp_end is null) or
    ($2 < nv.dynamic_dhcp_start) or
    ($2 > nv.dynamic_dhcp_end)
  ) from net_vlans nv
  where
    nv.vlan_num = $1
$$ language sql;

create table net_addresses (
  id                        serial primary key,
  zone                      text not null references net_zones
                              on update cascade
                              on delete cascade,
  vlan_num                  integer not null references net_vlans
                              on update cascade
                              on delete cascade,
  ipaddr                    inet,
  enabled                   boolean not null default true,
  monitored                 boolean not null,
  last_changed              timestamp not null default now(),
  check (
    ipaddr is null or (
      masklen(ipaddr) = 32 and
      non_dynamic_ip(vlan_num, ipaddr)
    )
  )
) ;

create unique index idx_net_addresses_vlan_ip on net_addresses (
  vlan_num,
  ipaddr
) where ipaddr is not null;

create trigger vlan_zone_trigger before insert or update on net_addresses
  for each row execute procedure update_zone_by_vlan();

create table net_switches (
  name                      text not null references equipment
                              on update cascade
                              on delete cascade,
  primary key (name),
  fqdn                      text not null,
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
  wall_plate                text not null,
  last_changed              timestamp not null default now(),
  blade_num                 integer,
  unique (switch, port_num, blade_num),
  check (port_num >= 0 and port_num <= num_ports(switch))
) ;

create unique index idx_wall_ports on net_ports (
  wall_plate
) where wall_plate != 'MR';

create table net_interfaces (
  id                        serial primary key,
  equip_name                text not null references equipment
                              on update cascade
                              on delete cascade,
  port_id                   integer references net_ports
                              on update cascade
                              on delete set null,
  ethernet                  macaddr not null,
  primary_address           integer references net_addresses
                              on update cascade
                              on delete set null,
  last_changed              timestamp not null default now()
) ;

create table net_services (
  service                   text primary key
) ;

create table net_dns_entries (
  dns_name                  text not null,
  domain                    text not null,
  dns_region                text not null references dns_regions
                              on update cascade
                              on delete restrict,
  address                   integer not null references net_addresses
                              on update cascade
                              on delete cascade,
  authoritative             boolean not null,
  last_changed              timestamp not null default now(),
  primary key               (dns_name, domain, dns_region)
) ;

create unique index authoritative_dns_entries_index on net_dns_entries (
  dns_name,
  domain,
  dns_region
) where authoritative = true;

-- join tables {{{
create table net_ports_net_vlans (
  net_ports_id              integer not null references net_ports
                              on update cascade
                              on delete cascade,
  vlan_num                  integer not null references net_vlans
                              on update cascade
                              on delete cascade,
  primary key               (net_ports_id, vlan_num)
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

create table user_status_types (
  name                      text primary key
) ;

create sequence uid_seq;

create sequence gid_seq;

create table people (
  id                        serial primary key,
  user_status               text not null references user_status_types
                              on update cascade
                              on delete restrict,
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
  student_id                integer not null references people
                              on update cascade
                              on delete cascade,
  course_id                 integer not null references courses
                              on update cascade
                              on delete cascade,
  primary key               (student_id, course_id),
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

create table os_types (
  name                      text primary key,
  pxe_boot                  boolean not null default false
) ;

create table computers (
  name                      text not null references equipment
                              on update cascade
                              on delete cascade,
  primary key (name),
  os                        text references os_types
                              on update cascade
                              on delete restrict,
  pxelink                   text,
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
  os_name                   text,
  os_version                text,
  os_dist                   text,
  info_time                 timestamp,
  boot_time                 timestamp
) ;

create table comp_classes (
  id                        serial primary key,
  name                      text not null,
  os                        text references os_types
                              on update cascade
                              on delete cascade,
  unique (name, os)
) ;

-- join tables {{{
create table comp_classes_computers (
  comp_class                integer not null references comp_classes
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

