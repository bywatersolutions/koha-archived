#!/usr/bin/perl
use C4::Context;
my $dbh = C4::Context->dbh;

$dbh->do(
"ALTER TABLE `branches` ADD `itembarcodeprefix` VARCHAR( 10 ) NULL AFTER `branchnotes`"
);
$dbh->do(
"ALTER TABLE `branches` ADD `patronbarcodeprefix` VARCHAR( 10 ) NULL AFTER `itembarcodeprefix`"
);
$dbh->do(
"INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('itembarcodelength','','Number of characters in system-wide barcode schema (item barcodes).','','Integer')"
);
$dbh->do(
"INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('patronbarcodelength','','Number of characters in system-wide barcode schema (patron cardnumbers).','','Integer')"
);
print
"Upgrade to done (Add barcode prefix feature. Add fields itembarcodeprefix and patronbarcodeprefix to table branches, add sysprefs itembarcodelength and patronbarcodelength)\n";
