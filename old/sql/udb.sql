/*
 ** UDB Schema
 ** $Id$
 */

/*
 * This table lists possible locations.
 */
DROP TABLE location CASCADE;
CREATE TABLE location (
	lid		TEXT	PRIMARY KEY CHECK (lid <> ''),
	building	TEXT,
	floor		TEXT,
	room		TEXT,
	descr		TEXT,
	UNIQUE(building, floor, room)
);
INSERT INTO location (lid) VALUES ('unknown');

/*
 * This table lists the valid values for equipment usage
 */
DROP TABLE usage CASCADE;
CREATE TABLE usage (
	usage		TEXT	PRIMARY KEY CHECK (usage <> '')
);
INSERT INTO usage (usage) VALUES ('Instructional');
INSERT INTO usage (usage) VALUES ('Research');
INSERT INTO usage (usage) VALUES ('Math');

DROP FUNCTION check_usage ( TEXT );
CREATE FUNCTION check_usage ( TEXT )
	RETURNS TEXT
	AS 'SELECT usage FROM usage WHERE usage = $1'
	LANGUAGE 'sql';

/*
 * Each piece of equipment should be listed in this table
 */
DROP SEQUENCE equipment_id_seq;
CREATE SEQUENCE equipment_id_seq;
DROP TABLE equipment CASCADE;
CREATE TABLE equipment (
	id		INT4	PRIMARY KEY
				DEFAULT NEXTVAL('equipment_id_seq'),
	descr		TEXT 	NOT NULL CHECK (descr <> ''),
	lid		TEXT	NOT NULL CHECK (lid <> ''),
	serial_num	TEXT	UNIQUE CHECK (serial_num ISNULL
					OR serial_num <> ''),
	inventory_num	TEXT	UNIQUE CHECK (inventory_num ISNULL
					OR inventory_num <> ''),
	usage		TEXT	CHECK (usage ISNULL
					OR check_usage(usage) NOTNULL),
	active		BOOLEAN	NOT NULL DEFAULT TRUE,
	owner		TEXT	CHECK (owner ISNULL OR owner <> ''),
	comment		TEXT	CHECK (comment ISNULL OR comment <> ''),
	FOREIGN KEY (lid) REFERENCES location (lid) ON UPDATE CASCADE,
	FOREIGN KEY (usage) REFERENCES usage (usage)
);

/*
 * Sometimes we have to track the components that make up a machine.  This
 * usually happens when we get a new disk drive and the Univ. wants to track
 * it.  Might also be useful for tracking the flat panels. This table show
 * the "parent" of the component.  (Both of the columns in this table refer
 * to the id column of equipment.)
 */
DROP TABLE component_of;
CREATE TABLE component_of (
	id	INT4	UNIQUE NOT NULL,
	parent	INT4	NOT NULL,	
	FOREIGN KEY (id) REFERENCES equipment (id) ON DELETE CASCADE,
	FOREIGN KEY (parent) REFERENCES equipment (id) ON DELETE CASCADE
);

/*
 * Create a dummy check_alias function so we can use it in defining the
 * network table.  This function will be over-ridden after both the network
 * table and the alias tables are defined.
 */
DROP FUNCTION check_alias ( TEXT ) CASCADE;
CREATE FUNCTION check_alias ( TEXT ) 
	RETURNS TEXT
	AS 'SELECT text(1)'
	LANGUAGE 'sql';


/*
 * Network Information.  Since it's legit. to have a network table entry
 * with no equipment, the id can be null.  This table tries to place as few
 * restrictions on the network info as possible, so nulls are accepted in
 * most columns.
 * The "nid" column has no "business value".  It's strictly to make it
 * easy for application programs (specifically *my* application
 * programs) to uniquely identify each row in the table;
 */
DROP SEQUENCE network_nid_seq;
CREATE SEQUENCE network_nid_seq;
DROP TABLE network CASCADE;
CREATE TABLE network (
	id		INT4,
	ipaddr		INET	UNIQUE CHECK (masklen(ipaddr) != 32),
	hostname	TEXT	UNIQUE CHECK (hostname ISNULL
				       OR ( hostname <> ''
					AND check_alias(hostname) ISNULL)),
	bcast		INET	CHECK (ipaddr ISNULL
					OR broadcast(ipaddr) = bcast),
	ethernet	MACADDR,
	mxhost		TEXT	CHECK (mxhost ISNULL OR mxhost <> ''),
	comment		TEXT,
	nid		INT4	PRIMARY KEY
				DEFAULT NEXTVAL('network_nid_seq'),
	UNIQUE(ethernet, bcast),
	FOREIGN KEY (id) REFERENCES equipment (id)
);

DROP FUNCTION id2hostname ( INT );
CREATE FUNCTION id2hostname ( INT ) 
       RETURNS TEXT
       AS 'SELECT hostname FROM network WHERE id = $1'
       LANGUAGE 'sql';

DROP FUNCTION check_hostname ( TEXT ) CASCADE;
CREATE FUNCTION check_hostname ( TEXT )
	RETURNS TEXT
	AS 'SELECT hostname FROM network WHERE hostname = $1'
	LANGUAGE 'sql';

/*
 * A hosts aliases
 */
DROP TABLE aliases;
CREATE TABLE aliases (
	nid	INT4	NOT NULL,
	alias	TEXT	NOT NULL UNIQUE CHECK (alias <> ''
					AND check_hostname(alias) ISNULL),
	FOREIGN KEY (nid) REFERENCES network (nid) ON DELETE CASCADE
);

CREATE OR REPLACE FUNCTION check_alias ( TEXT ) 
	RETURNS TEXT
	AS 'SELECT alias FROM aliases WHERE alias = $1'
	LANGUAGE 'sql';



/*
 * A function that returns the equipment id for a given hostname
 */
DROP FUNCTION get_id ( TEXT );
CREATE FUNCTION get_id ( TEXT )
	RETURNS INT4
	AS 'SELECT id FROM network WHERE hostname = $1;'
	LANGUAGE 'sql';

DROP FUNCTION name2ip ( TEXT );
CREATE FUNCTION name2ip ( TEXT )
	RETURNS INET
	AS 'SELECT ipaddr FROM network WHERE hostname = $1;'
	LANGUAGE 'sql';

DROP FUNCTION ip2name ( INET );
CREATE FUNCTION ip2name ( INET )
	RETURNS TEXT
	AS 'SELECT hostname FROM network WHERE host(ipaddr) = host($1);'
	LANGUAGE 'sql';

/*
 * List the possible values for status
 */
DROP TABLE status_list CASCADE;
CREATE TABLE status_list (
	status		TEXT	PRIMARY KEY CHECK(status <> '')
);
INSERT INTO status_list (status) VALUES ('active');
INSERT INTO status_list (status) VALUES ('monitoredPC');
INSERT INTO status_list (status) VALUES ('home');
INSERT INTO status_list (status) VALUES ('special');
INSERT INTO status_list (status) VALUES ('notCS');
INSERT INTO status_list (status) VALUES ('disabled');

DROP FUNCTION check_status ( TEXT ) CASCADE;
CREATE FUNCTION check_status ( TEXT )
	RETURNS TEXT
	AS 'SELECT status FROM status_list WHERE status = $1'
	LANGUAGE 'sql';

DROP TABLE status;
CREATE TABLE status (
	nid		INT4	NOT NULL,
	status		TEXT	NOT NULL CHECK (status <> ''
					AND check_status(status) NOTNULL),
	UNIQUE(nid, status),
	FOREIGN KEY (nid) REFERENCES network (nid) ON DELETE CASCADE,
	FOREIGN KEY (status) REFERENCES status_list (status)
);
	

/*
 * Netgroups the host is in
 */
DROP TABLE netgroups;
CREATE TABLE netgroups (
	nid	       INT4	NOT NULL,
	netgroup	TEXT	NOT NULL CHECK (netgroup <> ''),
	PRIMARY KEY (nid, netgroup),
	FOREIGN KEY (nid) REFERENCES network (nid) ON DELETE CASCADE
);


/*****************************************************************
 * CDB Information
 */

DROP TABLE arch_list CASCADE;
CREATE TABLE arch_list (
	arch	TEXT	PRIMARY KEY CHECK (arch <> '')
);
INSERT INTO arch_list (arch) VALUES ('sun4c');
INSERT INTO arch_list (arch) VALUES ('sun4m');
INSERT INTO arch_list (arch) VALUES ('sun4u');
INSERT INTO arch_list (arch) VALUES ('apple');
INSERT INTO arch_list (arch) VALUES ('x86');
INSERT INTO arch_list (arch) VALUES ('alpha');


DROP FUNCTION check_arch ( TEXT ) CASCADE;
CREATE FUNCTION check_arch ( TEXT )
	RETURNS TEXT
	AS 'SELECT arch FROM arch_list WHERE arch = $1'
	LANGUAGE 'sql';


DROP TABLE architecture;
CREATE TABLE architecture (
	id	INT4	UNIQUE NOT NULL,
	arch	TEXT	NOT NULL CHECK (arch <> ''
					AND check_arch(arch) NOTNULL),
	FOREIGN KEY (id) REFERENCES equipment (id) ON DELETE CASCADE,
	FOREIGN KEY (arch) REFERENCES arch_list (arch)
);

/*
 * The list of possible OSes
 */
DROP TABLE os_list CASCADE;
CREATE TABLE os_list (
	os	TEXT	PRIMARY KEY CHECK (os <> '')
);
INSERT INTO os_list (os) VALUES ('sunos5.6');
INSERT INTO os_list (os) VALUES ('sunos5.7');
INSERT INTO os_list (os) VALUES ('sunos5.7b');
INSERT INTO os_list (os) VALUES ('sunos5.8');
INSERT INTO os_list (os) VALUES ('linux');
INSERT INTO os_list (os) VALUES ('windows');
INSERT INTO os_list (os) VALUES ('win95');
INSERT INTO os_list (os) VALUES ('win98');
INSERT INTO os_list (os) VALUES ('winCE');
INSERT INTO os_list (os) VALUES ('win2k');
INSERT INTO os_list (os) VALUES ('winxp');
INSERT INTO os_list (os) VALUES ('nt');
INSERT INTO os_list (os) VALUES ('macos');
INSERT INTO os_list (os) VALUES ('hpux');


DROP FUNCTION check_os ( TEXT ) CASCADE;
CREATE FUNCTION check_os ( TEXT )
	RETURNS TEXT
	AS 'SELECT os FROM os_list WHERE os = $1'
	LANGUAGE 'sql';

/*
 * The OS running on a piece of equip.  Since a single host can dual boot,
 * it's possible for a host to be listed multiple times.
 */

DROP TABLE os_type;
CREATE TABLE os_type (
	id	INT4	NOT NULL,
	os	TEXT	NOT NULL CHECK (os <> ''
				AND check_os(os) NOTNULL),
	FOREIGN KEY (id) REFERENCES equipment (id) ON DELETE CASCADE,
	FOREIGN KEY (os) REFERENCES os_list (os),
	UNIQUE(id,os)
);


/*
 * Information needed by FAI during install.  This is still tentative until
 * Tweak is fully designed.
 */
DROP TABLE fai;
CREATE TABLE fai (
	nid	INT4	UNIQUE NOT NULL,
	config	TEXT	NOT NULL CHECK (config <> ''),
	FOREIGN KEY (nid) REFERENCES network (nid) ON DELETE CASCADE
);

/*
 * The directory paths used by Jumpstart
 */

DROP TABLE js_paths;
CREATE TABLE js_paths (
	os		TEXT	UNIQUE NOT NULL CHECK (os <> ''
					AND check_os(os) NOTNULL ),
	netboot		TEXT	NOT NULL CHECK (netboot <> ''),
	install		TEXT	NOT NULL CHECK (install <> ''),
	jumpstart	TEXT	NOT NULL CHECK (jumpstart <> ''),
	cache		TEXT	NOT NULL CHECK (cache <> ''),
	FOREIGN KEY (os) REFERENCES os_list (os)
);
INSERT INTO js_paths (os, netboot, install, jumpstart, cache)
	SELECT os,
		'Solaris_2.7/Tools/Boot',
		'bruford:/sol-dist/Solaris_2.7/install',
		'maytag:/sys0/Solaris_2.7b/jumpstart',
		'maytag:/sys0/Solaris_2.7/cachefs'
	FROM os_list where os = 'sunos5.7b';
INSERT INTO js_paths (os, netboot, install, jumpstart, cache)
	SELECT os,
		'Solaris_8/Tools/Boot',
		'bruford:/sol-dist/Solaris_8/install',
		'maytag:/sys0/Solaris_8/jumpstart',
		'maytag:/sys0/usr.local'
	FROM os_list where os = 'sunos5.8';


/***************************************************************************/

DROP TABLE dirty;
CREATE TABLE dirty (
	data	TEXT	UNIQUE NOT NULL,
	dirty	BOOLEAN	NOT NULL
);
INSERT INTO dirty ( data, dirty ) VALUES ( 'ethernet', 'f');
INSERT INTO dirty ( data, dirty ) VALUES ( 'hostname', 'f');
INSERT INTO dirty ( data, dirty ) VALUES ( 'ipaddr', 'f');
INSERT INTO dirty ( data, dirty ) VALUES ( 'aliases', 'f');
INSERT INTO dirty ( data, dirty ) VALUES ( 'mxhost', 'f');
INSERT INTO dirty ( data, dirty ) VALUES ( 'jspaths', 'f');
INSERT INTO dirty ( data, dirty ) VALUES ( 'arch', 'f');
INSERT INTO dirty ( data, dirty ) VALUES ( 'os_type', 'f');
INSERT INTO dirty ( data, dirty ) VALUES ( 'netgroup', 'f');

CREATE RULE mod_ethernet AS ON UPDATE
	TO network WHERE NEW.ethernet != OLD.ethernet
	DO UPDATE dirty SET dirty = 't' WHERE data = 'ethernet';
CREATE RULE ins_ethernet AS ON INSERT
	TO network WHERE NEW.ethernet NOTNULL
	DO UPDATE dirty SET dirty = 't' WHERE data = 'ethernet';
CREATE RULE del_ethernet AS ON DELETE
	TO network WHERE OLD.ethernet NOTNULL
	DO UPDATE dirty SET dirty = 't' WHERE data = 'ethernet';

CREATE RULE mod_hostname AS ON UPDATE
	TO network WHERE NEW.hostname != OLD.hostname
	DO UPDATE dirty SET dirty = 't' WHERE data = 'hostname';
CREATE RULE ins_hostname AS ON INSERT
	TO network WHERE NEW.hostname NOTNULL
	DO UPDATE dirty SET dirty = 't' WHERE data = 'hostname';
CREATE RULE del_hostname AS ON DELETE
	TO network WHERE OLD.hostname NOTNULL
	DO UPDATE dirty SET dirty = 't' WHERE data = 'hostname';

CREATE RULE mod_ipaddr AS ON UPDATE
	TO network WHERE NEW.ipaddr != OLD.ipaddr
	DO UPDATE dirty SET dirty = 't' WHERE data = 'ipaddr';
CREATE RULE ins_ipaddr AS ON INSERT
	TO network WHERE NEW.ipaddr NOTNULL
	DO UPDATE dirty SET dirty = 't' WHERE data = 'ipaddr';
CREATE RULE del_ipaddr AS ON DELETE
	TO network WHERE OLD.ipaddr NOTNULL
	DO UPDATE dirty SET dirty = 't' WHERE data = 'ipaddr';

CREATE RULE mod_mxhost AS ON UPDATE
	TO network WHERE NEW.mxhost != OLD.mxhost
	DO UPDATE dirty SET dirty = 't' WHERE data = 'mxhost';
CREATE RULE ins_mxhost AS ON INSERT
	TO network WHERE NEW.mxhost NOTNULL
	DO UPDATE dirty SET dirty = 't' WHERE data = 'mxhost';
CREATE RULE del_mxhost AS ON DELETE
	TO network WHERE OLD.mxhost NOTNULL
	DO UPDATE dirty SET dirty = 't' WHERE data = 'mxhost';
	
CREATE RULE mod_alias AS ON UPDATE
	TO aliases
	DO UPDATE dirty SET dirty = 't' WHERE data = 'aliases';
CREATE RULE ins_alias AS ON INSERT
	TO aliases
	DO UPDATE dirty SET dirty = 't' WHERE data = 'aliases';
CREATE RULE del_alias AS ON DELETE
	TO aliases
	DO UPDATE dirty SET dirty = 't' WHERE data = 'aliases';

CREATE RULE mod_supgroup AS ON UPDATE
	TO netgroups
	DO UPDATE dirty SET dirty = 't' WHERE data = 'netgroup';
CREATE RULE ins_supgroup AS ON INSERT
	TO netgroups
	DO UPDATE dirty SET dirty = 't' WHERE data = 'netgroup';

CREATE RULE del_supgroup AS ON DELETE
	TO netgroups
	DO UPDATE dirty SET dirty = 't' WHERE data = 'netgroup';

CREATE RULE mod_architecture AS ON UPDATE
	TO architecture
	DO UPDATE dirty SET dirty = 't' WHERE data = 'hw_arch';
CREATE RULE ins_architecture AS ON INSERT
	TO architecture
	DO UPDATE dirty SET dirty = 't' WHERE data = 'hw_arch';
CREATE RULE del_architecture AS ON DELETE
	TO architecture
	DO UPDATE dirty SET dirty = 't' WHERE data = 'hw_arch';

CREATE RULE mod_os_type AS ON UPDATE
	TO os_type
	DO UPDATE dirty SET dirty = 't' WHERE data = 'os_type';
CREATE RULE ins_os_type AS ON INSERT
	TO os_type
	DO UPDATE dirty SET dirty = 't' WHERE data = 'os_type';
CREATE RULE del_os_type AS ON DELETE
	TO os_type
	DO UPDATE dirty SET dirty = 't' WHERE data = 'os_type';

CREATE RULE mod_js_paths AS ON UPDATE
	TO js_paths
	DO UPDATE dirty SET dirty = 't' WHERE data = 'jspaths';
CREATE RULE ins_js_paths AS ON INSERT
	TO js_paths
	DO UPDATE dirty SET dirty = 't' WHERE data = 'jspaths';
CREATE RULE del_js_paths AS ON DELETE
	TO js_paths
	DO UPDATE dirty SET dirty = 't' WHERE data = 'jspaths';


/***************************************************************************/

/*
 * Inventory Information
 */

DROP TABLE purchase;
CREATE TABLE purchase (
	id	INT4	UNIQUE NOT NULL,
	po_num	TEXT	CHECK (po_num ISNULL OR po_num <> ''),
	date	DATE,
	price	DECIMAL(9,2),
	comment	TEXT	CHECK (comment ISNULL OR comment <> ''),
	FOREIGN KEY (id) REFERENCES equipment (id) ON DELETE CASCADE
);

/*
 * Keeps track of the accounts used to make purchase.  A single piece of
 * equipment can be purchased using multiple accounts.
 */

DROP TABLE account;
CREATE TABLE account (
	id	INT4	NOT NULL,
	acct	TEXT	NOT NULL CHECK (acct <> ''),
	percent	INT4	CHECK (percent NOTNULL
				OR (percent > 0 AND percent <= 100)),
	UNIQUE (id, acct),
	FOREIGN KEY (id) REFERENCES equipment (id) ON DELETE CASCADE
);

/*
 * How we got rid of the equipment.
 */

DROP TABLE dispose;
CREATE TABLE dispose (
	id		INT4	UNIQUE NOT NULL,
	surplus_date	DATE,
	sold_date	DATE,
	price		DECIMAL(9,2),
	comment		TEXT	CHECK (comment <> ''),
	FOREIGN KEY (id) REFERENCES equipment (id) ON DELETE CASCADE
);

/*
 * The date the equipment was installed.
 */

DROP TABLE installation;
CREATE TABLE installation (
	id	INT4	UNIQUE NOT NULL,
	date	DATE,
	comment	TEXT,
	FOREIGN KEY (id) REFERENCES equipment (id) ON DELETE CASCADE
);

/*
 * The users of a piece of equipment.  Each eq can have many users.  (This
 * could/should eventually tie in to a username/Real Name table).
 */

DROP TABLE users;
CREATE TABLE users (
	id	INT4	NOT NULL,
	users	TEXT	NOT NULL CHECK (users <> ''),
	UNIQUE (id, users),
	FOREIGN KEY (id) REFERENCES equipment (id) ON DELETE CASCADE
);

DROP TABLE config;
CREATE TABLE config (
       id	    INT4	UNIQUE NOT NULL,
       cpu	    TEXT	CHECK ( cpu <> '' ),
       memory	    TEXT	CHECK ( memory <> '' ),
       disk	    TEXT	CHECK ( disk <> '' ),
       graphics	    TEXT	CHECK ( graphics <> ''),
       comment	    TEXT	CHECK ( comment <> ''),
       FOREIGN KEY (id) REFERENCES equipment (id) ON DELETE CASCADE
);

DROP VIEW eq;
CREATE VIEW eq AS SELECT network.hostname, equipment.* FROM equipment LEFT OUTER JOIN network ON equipment.id = network.id;
