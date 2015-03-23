$DBversion = "XXX";
if ( CheckVersion($DBversion) ) {
    print "Upgrade to $DBversion done (Bug 13893 - Add ability to execute perl scripts in atomicupdates)\n";
    SetVersion($DBversion);
}
