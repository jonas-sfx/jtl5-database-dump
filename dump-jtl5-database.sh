#!/bin/bash

## filename      dump-jtl-database.sh
## description:  read db-credentials from your jtl-5-config
##               and create a database-dump of the shop.
## author:       jonas@sfxonline.de
## =======================================================================

mydir=$(dirname $0)
cd "$mydir"

configfile="config.json"
name="$(jq -r '.name' $configfile)"
webroot="$(jq -r '.webroot' $configfile)"
host="$(jq -r '.host' $configfile)"
mysqldump="$(which mysqldump)"

echo "Dumping: $name"
echo "---------"

echo "- Get Config for MySQL-Data transfer"
remote_config=$(ssh "$host" "cat $webroot/includes/config.JTL-Shop.ini.php")
remote_mysql_host=$(echo "$remote_config" | grep -o 'DB_HOST", "[^"]*' | cut -d '"' -f 3)
remote_mysql_user=$(echo "$remote_config" | grep -o 'DB_USER", "[^"]*' | cut -d '"' -f 3)
remote_mysql_password=$(echo "$remote_config" | grep -o 'DB_PASS", "[^"]*' | cut -d '"' -f 3)
remote_mysql_database=$(echo "$remote_config" | grep -o 'DB_NAME", "[^"]*' | cut -d '"' -f 3)
remote_mysql_port=3306

echo "Host:     $remote_mysql_host"
echo "Database: $remote_mysql_database"
echo "User:     $remote_mysql_user"
echo "User:     $remote_mysql_password"

# thats for using tcp and not sock for sure
if [ "$remote_mysql_host" = "localhost" ]; then
    remote_mysql_host="127.0.0.1"
fi

tunnelport=$(shuf -i 10000-20000 -n 1)
echo "-- Choose random port for ssh-tunneling: $tunnelport"

ssh -4 -f -L $tunnelport:$remote_mysql_host:$remote_mysql_port $host sleep 10; \
  $mysqldump --opt --no-tablespaces --hex-blob -h 127.0.0.1 -P $tunnelport \
  -u $remote_mysql_user -p"$remote_mysql_password" $remote_mysql_database \
  --column-statistics=0 \
  --complete-insert \
  --add-drop-table \
  > tmp4dumps/$remote_mysql_database.sql

# OPTIONAL: if dumping into an existing environment you could work with IF NOT EXISTS and REPLACE INTO-Alternatives
# sed -i 's/CREATE TABLE /CREATE TABLE IF NOT EXISTS /g' tmp4dumps/$remote_mysql_database.sql
# sed -i 's/INSERT INTO /REPLACE INTO /g' tmp4dumps/$remote_mysql_database.sql

sed -i 's/\sDEFINER=`[^`]*`@`[^`]*`//g' tmp4dumps/$remote_mysql_database.sql

echo '... archiving the dumpfile.'
DATE=$(date +"%Y%m%d-%H%M")
zstd "tmp4dumps/$remote_mysql_database.sql" -o "tmp4dumps/$DATE-$remote_mysql_database.sql.zst"

# OPTIONAL: clean up the unarchived dump
# rm zstd "tmp4dumps/$remote_mysql_database.sql"