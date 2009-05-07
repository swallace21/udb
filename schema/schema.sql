--------------
-- Internal --
--------------

-- {{{

drop language if exists plpgsql cascade;
create language plpgsql;

drop table if exists db_export_log_entries cascade;
create table db_export_log_entries (
  db_export_log_entry_id    serial primary key,
  script_name               text not null,
  last_run                  timestamp not null default now()
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

drop aggregate if exists textcat_all (text);
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

create or replace function set_last_updated() returns trigger as
$$
begin
  new.last_updated := now();
  return new;
end;
$$ language plpgsql;

drop domain if exists dns_safe_text cascade;
create domain dns_safe_text as text
check(
  value ~ '^[a-z0-9]([a-z0-9_-]){0,253}[a-z0-9]?$'
);

-- }}}

------------
-- Places --
------------

-- {{{

drop table if exists places cascade;
create table places (
  place_id                  serial primary key,
  city                      text,
  building                  text,
  room                      text
) ;

-- }}}

--------------------------
-- Device documentation --
--------------------------

-- {{{

drop table if exists management_types cascade;
create table management_types (
  management_type           text primary key
) ;

drop table if exists equip_status_types cascade;
create table equip_status_types (
  equip_status_type         text primary key
) ;

drop table if exists equip_usage_types cascade;
create table equip_usage_types (
  equip_usage_type          text primary key
) ;

drop table if exists devices cascade;
create table devices (
  device_name               dns_safe_text primary key,
  parent_device_name        dns_safe_text references devices
                              on update cascade
                              on delete cascade,
  place_id                  integer references places
                              on update cascade
                              on delete cascade,
  status                    text not null references equip_status_types
                              on update cascade
                              on delete restrict,
  usage                     text not null references equip_usage_types
                              on update cascade
                              on delete restrict,
  manager                   text not null references management_types
                              on update cascade
                              on delete restrict,
  protected                 boolean not null default false,
  purchased_on              date default now(),
  installed_on              date default now(),
  last_contacted_on         date default now(),
  brown_inv_num             text,
  serial_num                text,
  po_num                    text,
  owner                     text,
  contact                   text,
  comments                  text
) ;

drop table if exists surplus_devices cascade;
create table surplus_devices (
  surplus_device_id         serial primary key,
  parent_surplus_device_id  integer references surplus_devices
                              on update cascade
                              on delete cascade,
  surplus_date              date,
  purchased_on              date,
  installed_on              date,
  name                      text,
  buyer                     text,
  brown_inv_num             text,
  serial_num                text,
  po_num                    text,
  comments                  text
) ;

-- }}}

-------------
-- Network --
-------------

-- {{{

drop sequence if exists dns_serial_num_seq cascade;
create sequence dns_serial_num_seq;

drop table if exists routing_types cascade;
create table routing_types (
  routing_type              text primary key
) ;

drop table if exists dns_regions cascade;
create table dns_regions (
  dns_region                text primary key
) ;

create or replace function num_ports(text) returns integer as 'select 0' language 'sql';
create or replace function vlan_zone(integer) returns text as 'select cast('''' as text)' language 'sql';

drop table if exists net_zones cascade;
create table net_zones (
  zone_name                 text primary key,
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

drop table if exists net_vlans cascade;
create table net_vlans (
  vlan_num                  integer primary key,
  zone_name                 text not null references net_zones
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
  select (zone_name) into strict new_vlan_zone from net_vlans
    where vlan_num = new.vlan_num;
  new.zone_name := new_vlan_zone;
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

drop table if exists net_addresses cascade;
create table net_addresses (
  net_address_id            serial primary key,
  zone_name                 text not null references net_zones
                              on update cascade
                              on delete cascade,
  vlan_num                  integer not null references net_vlans
                              on update cascade
                              on delete cascade,
  ipaddr                    inet,
  enabled                   boolean not null default true,
  monitored                 boolean not null,
  last_updated              timestamp not null default now(),
  check (
    ipaddr is null or (
      masklen(ipaddr) = 32 and
      non_dynamic_ip(vlan_num, ipaddr)
    )
  )
) ;

drop trigger if exists last_updated_trigger on net_addresses;
create trigger last_updated_trigger before insert or update on net_addresses
  for each row execute procedure set_last_updated();

drop index if exists idx_net_addresses_vlan_ip;
create unique index idx_net_addresses_vlan_ip on net_addresses (
  vlan_num,
  ipaddr
) where ipaddr is not null;

drop trigger if exists vlan_zone_trigger on net_addresses;
create trigger vlan_zone_trigger before insert or update on net_addresses
  for each row execute procedure update_zone_by_vlan();

drop table if exists net_switches cascade;
create table net_switches (
  device_name               dns_safe_text not null references devices
                              on update cascade
                              on delete cascade,
  primary key (device_name),
  fqdn                      text not null,
  num_ports                 integer not null,
  num_blades                integer,
  switch_type               text not null,
  connection_type           text not null default 'ssh',
  username                  text not null,
  pass                      text not null
);

drop table if exists net_ports cascade;
create table net_ports (
  net_port_id               serial primary key,
  place_id                  integer references places
                              on update cascade
                              on delete cascade,
  switch_name               dns_safe_text not null references net_switches
                              on update cascade
                              on delete cascade,
  port_num                  integer not null,
  wall_plate                text not null,
  last_updated              timestamp not null default now(),
  blade_num                 integer,
  unique (switch_name, port_num, blade_num),
  check (port_num >= 0 and port_num <= num_ports(switch_name))
  --, check (wall_plate = 'MR' or place_id is not null)
) ;

drop trigger if exists last_updated_trigger on net_ports;
create trigger last_updated_trigger before insert or update on net_ports
  for each row execute procedure set_last_updated();

drop index if exists idx_wall_ports;
create unique index idx_wall_ports on net_ports (
  wall_plate
) where wall_plate != 'MR';

drop table if exists net_interfaces cascade;
create table net_interfaces (
  net_interface_id          serial primary key,
  device_name               dns_safe_text not null references devices
                              on update cascade
                              on delete cascade,
  net_port_id               integer references net_ports
                              on update cascade
                              on delete set null,
  ethernet                  macaddr unique,
  primary_address_id        integer references net_addresses
                              on update cascade
                              on delete set null,
  last_updated              timestamp not null default now()
) ;

drop trigger if exists last_updated_trigger on net_interfaces;
create trigger last_updated_trigger before insert or update on net_interfaces
  for each row execute procedure set_last_updated();

create or replace function delete_primary_address() returns trigger as
$$
begin
  delete from net_addresses na where na.net_address_id = old.primary_address_id;
  return old;
end;
$$ language plpgsql;

drop trigger if exists delete_primary_address_trigger on net_interfaces;
create trigger delete_primary_address_trigger after delete on net_interfaces
  for each row execute procedure delete_primary_address();

drop table if exists net_services cascade;
create table net_services (
  net_service               text primary key
) ;

drop table if exists net_dns_entries cascade;
create table net_dns_entries (
  net_dns_entry_id          serial primary key,
  dns_name                  dns_safe_text not null,
  domain                    text not null,
  dns_region                text not null references dns_regions
                              on update cascade
                              on delete restrict,
  net_address_id            integer not null references net_addresses
                              on update cascade
                              on delete cascade,
  authoritative             boolean not null,
  last_updated              timestamp not null default now()
) ;

drop trigger if exists last_updated_trigger on net_dns_entries;
create trigger last_updated_trigger before insert or update on net_dns_entries
  for each row execute procedure set_last_updated();

drop index if exists authoritative_dns_entries_index;
create unique index authoritative_dns_entries_index on net_dns_entries (
  dns_name,
  domain,
  dns_region
) where authoritative = true;

-- join tables {{{
drop table if exists net_ports_net_vlans cascade;
create table net_ports_net_vlans (
  net_port_id               integer not null references net_ports
                              on update cascade
                              on delete cascade,
  vlan_num                  integer not null references net_vlans
                              on update cascade
                              on delete cascade,
  native                    boolean not null default true,
  primary key               (net_port_id, vlan_num)
) ;

drop index if exists port_native_vlan_index;
create unique index port_native_vlan_index on net_ports_net_vlans (
  net_port_id
) where native = true;

drop table if exists net_addresses_net_interfaces cascade;
create table net_addresses_net_interfaces (
  net_address_id            integer not null references net_addresses
                              on update cascade
                              on delete cascade,
  net_interface_id          integer not null references net_interfaces
                              on update cascade
                              on delete cascade,
  primary key               (net_address_id, net_interface_id)
) ;

drop table if exists net_addresses_net_services cascade;
create table net_addresses_net_services (
  net_address_id            integer not null references net_addresses
                              on update cascade
                              on delete cascade,
  net_service               text not null references net_services
                              on update cascade
                              on delete cascade,
  primary key               (net_address_id, net_service)
) ;

-- }}}

create or replace function vlan_zone(integer)
  returns text
  as 'select zone_name from net_vlans where vlan_num = $1'
  language 'sql';

create or replace function num_ports(text)
  returns integer
  as 'select num_ports from net_switches where device_name = $1'
  language 'sql';

drop table if exists dhcp_log_entries cascade;
create table dhcp_log_entries (
  dhcp_log_entry_id         serial primary key,
  entry_time                timestamp not null default now(),
  ethernet                  macaddr not null,
  ipaddr                    inet not null,
  data                      text
) ;

drop table if exists macaddr_log_entries cascade;
create table macaddr_log_entries (
  macaddr_log_entry_id      serial primary key,
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

drop table if exists user_status_types cascade;
create table user_status_types (
  user_status_type          text primary key
) ;

drop sequence if exists uid_seq cascade;
create sequence uid_seq;

drop sequence if exists gid_seq cascade;
create sequence gid_seq;

drop table if exists people cascade;
create table people (
  person_id                 serial primary key,
  status                    text not null references user_status_types
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

drop index if exists idx_people_family_name;
create index idx_people_family_name on people  (family_name) ;

drop table if exists user_accounts cascade;
create table user_accounts (
  user_account_id           serial primary key,
  person_id                 integer not null references people
                              on update cascade
                              on delete cascade,
  sponsor_id                integer not null references people
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
  last_updated              timestamp not null default now()
) ;

drop trigger if exists last_updated_trigger on user_accounts;
create trigger last_updated_trigger before insert or update on user_accounts
  for each row execute procedure set_last_updated();

drop table if exists mail_aliases cascade;
create table mail_aliases (
  mail_alias_id             serial primary key,
  user_account_id           integer not null references user_accounts
                              on update cascade
                              on delete cascade,
  alias                     text not null,
  target                    text not null,
  alias_type                text not null
) ;

drop table if exists user_groups cascade;
create table user_groups (
  user_group_id             serial primary key,
  gid                       integer unique not null,
  group_name                text unique not null default nextval('gid_seq'),
  created                   date,
  quota                     integer not null
) ;

drop table if exists courses cascade;
create table courses (
  course_id                 serial primary key,
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

drop table if exists enrollment cascade;
create table enrollment (
  enrollment_id             serial primary key,
  person_id                 integer not null references people
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

drop table if exists user_accounts_people cascade;

-- user_groups_user_accounts
-- association between user_groups and user_accounts
drop table if exists user_groups_user_accounts cascade;
create table user_groups_user_accounts (
  user_group_id             integer not null references user_groups
                              on update cascade
                              on delete cascade,
  user_account_id           integer not null references user_accounts
                              on update cascade
                              on delete cascade,
  primary key               (user_group_id, user_account_id)
) ;

-- }}}

-----------------
-- Filesystems --
-----------------

-- {{{

-- create table fs_exports (
--   fs_export_id              serial primary key,
--   server                    text,
--   path                      text,
--   fs_class                  text not null,
--   quota                     integer,
--   flags                     text,
--   backup_policy             text
-- ) ;
-- 
-- create table fs_classes (
--   fs_class_id               serial primary key,
--   fs_exports_id             integer not null references fs_exports,
--   fs_class                  text,
--   perms                     text
-- ) ;

drop table if exists fs_automounts cascade;
create table fs_automounts (
  fs_automount_id           serial primary key,
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

drop table if exists os_types cascade;
create table os_types (
  os_type                   text primary key,
  pxe_boot                  boolean not null default false
) ;

drop table if exists computers cascade;
create table computers (
  device_name               dns_safe_text not null references devices
                              on update cascade
                              on delete cascade,
  primary key (device_name),
  os_type                   text references os_types
                              on update cascade
                              on delete restrict,
  pxelink                   text
);

drop table if exists comp_sysinfo cascade;
create table comp_sysinfo (
  device_name               dns_safe_text not null references devices
                              on update cascade
                              on delete cascade,
  primary key (device_name),
  num_cpus                  integer,
  cpu_type                  text,
  cpu_speed                 text,
  memory                    text,
  hard_drives               text,
  video_cards               text,
  last_updated              timestamp not null default now()
);

drop trigger if exists last_updated_trigger on comp_sysinfo;
create trigger last_updated_trigger before insert or update on comp_sysinfo
  for each row execute procedure set_last_updated();

drop table if exists comp_classes cascade;
create table comp_classes (
  comp_class_id             serial primary key,
  name                      text not null,
  os_type                   text references os_types
                              on update cascade
                              on delete cascade,
  unique (name, os_type)
) ;

-- join tables {{{
drop table if exists comp_classes_computers cascade;
create table comp_classes_computers (
  comp_class_id             integer not null references comp_classes
                              on update cascade
                              on delete cascade,
  device_name               dns_safe_text not null references computers
                              on update cascade
                              on delete cascade,
  primary key               (comp_class_id, device_name)
) ;
-- }}}

-- }}}

-------------
-- General --
-------------

-- {{{

-- association between devices and people
drop table if exists device_users cascade;
create table device_users (
  device_name               dns_safe_text not null references devices
                              on update cascade
                              on delete cascade,
  person_id                 integer not null references people
                              on update cascade
                              on delete cascade,
  primary key               (device_name, person_id)
) ;

-- }}}

