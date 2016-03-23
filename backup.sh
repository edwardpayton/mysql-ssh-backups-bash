#!/bin/sh

# BACKUP DATABASES ON SERVER
# Copy to local
# Remove old version (over 30 days old)
# Sends email with list of DBs
#
# Requires ssh user with key (or sshpass)

# Config
source config/config.sh

# Timings
NOW=`date +%Y-%m-%d`
DAYS=30

# SSH Info
SUSER=""
SHOST=""
# OR
SALIAS="ssh-alias" 

# MySql
MUSER="user"
MPASS="password"
MHOST='localhost'
DBS=$(ssh $SALIAS "mysql -q -u a$MUSER -h localhost -p$MPASS -P 3308 -e 'show databases;' | awk '{ print $1 }'")

# Local directory
LDIR="local-directory"

# Remote directory
RDIR="remote-directory"

# Email to send to
EMAIL="email-address"

# Clean list of DBs (remove dbs that error)
nDBS=$DBS
REMOVE=(Database information_schema)
for rem in ${REMOVE[@]}
do
   nDBS=(${nDBS[@]/$rem})
done
DBS=${nDBS[@]/$REMOVE}

# Create backup
ssh $SALIAS "mkdir $RDIR/$NOW"
ATTEMPT=0
for db in $DBS
do

  ATTEMPT=`expr $ATTEMPT + 1`
  FILE=$RDIR/$NOW/$db.$NOW.sql.gz

  ssh $SALIAS "mysqldump -q -u $MUSER -h $MHOST -p$MPASS -P 3308 $db | gzip -9 > $FILE"
done

# Transfer files to local
mkdir $LDIR/$NOW
scp $SALIAS:$RDIR/$NOW/* $LDIR/$NOW

# Remove old remote files
ssh $SALIAS "find $RDIR/* -type d -ctime +$DAYS -exec rm -r {} \;"

# Remove old local files
find $LDIR/* -type d -ctime +$DAYS -exec rm -r {} \;

# Email me
LFILES=`ls $LDIR/$NOW/*.$NOW.sql.gz`
COUNT=0
for file in $LFILES;
do
  COUNT=`expr $COUNT + 1`;
done

# Send mail
mail -s "MySql Backups Report" $EMAIL << EOF
$COUNT databases databases were backed up here on the server:
$RDIR/$NOW

Files stored locally:
$LFILES
EOF
