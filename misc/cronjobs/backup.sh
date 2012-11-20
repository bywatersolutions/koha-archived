#!/bin/sh
# Script to create daily backups of the Koha database.
# Based on a script by John Pennington
KOHA_DATE=`date '+%y%m%d'`
KOHA_DUMP=/home/koha/koha-$KOHA_DATE.dump.gz
KOHA_BACKUP=/home/koha/koha-$KOHA_DATE.dump.gz

mysqldump --single-transaction -h169.151.6.240 -ukoha -ppwdSecure12 koha_pisd |gzip -9 > $KOHA_DUMP &&
# Creates the dump file and compresses it;
# -u is the Koha user, -p is the password for that user.
# The -f switch on gzip forces it to overwrite the file if one exists.

#chown koha.users /home/koha/koha-$KOHA_DATE.dump.gz &&
#chmod 600 /home/koha/koha-$KOHA_DATE.dump.gz &&
# Makes the compressed dump file property of the kohaadmin user.
# Make sure that you replace kohaadmin with a real user.

# Notifies kohaadmin of (un)successful backup creation
# EOF
