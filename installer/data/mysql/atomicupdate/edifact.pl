#!/usr/bin/perl

use strict;
use warnings;

use C4::Context;

my $dbh = C4::Context->dbh;

$dbh->do("ALTER TABLE import_batches ADD is_order BOOLEAN NOT NULL DEFAULT '0' AFTER comments");
print "Upgrade done (Bug 10877 - Add 'Order Record' processing)\n";

my $sql1 = <<"END_EDI1";
CREATE TABLE IF NOT EXISTS vendor_edi_accounts (
  id int(11) NOT NULL auto_increment,
  description text NOT NULL,
  host text,
  username text,
  password text,
  last_activity date default NULL,
  provider int(11) default NULL,
  in_dir text,
  san varchar(32) default NULL,
  library_san varchar(32) default NULL,
  options TEXT default NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
END_EDI1

my $sql2 = <<"END_EDI2";
CREATE TABLE IF NOT EXISTS edifact_messages (
  id int(11) NOT NULL auto_increment,
  message_type text NOT NULL,
  date_sent date default NULL,
  provider int(11) default NULL,
  status text,
  basketno int(11) NOT NULL default '0',
  PRIMARY KEY  (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
END_EDI2

my $sql3 = <<"END_EDI3";
insert into permissions (module_bit, code, description) values (13, 'edi_manage', 'Manage EDIFACT transmissions');
END_EDI3

my $sql4 = <<"END_EDI4";
INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES
('EDIfactEAN', '56781234', '', 'EAN identifier for the library used in EDIfact messages', 'Textarea');
END_EDI4

$dbh->do($sql1);
$dbh->do($sql2);
$dbh->do($sql3);
$dbh->do($sql4);

print "Upgrade done (Bug 7736 - Edifact QUOTE and ORDER functionality)\n";
