#!/bin/bash

PGDATA=${PGDATA:-"/var/lib/postgresql/9.4"}
PGLOG=${PGLOG:-"$PGDATA/pg_log"}
PGPORT=${PGPORT:-5432}

DATE=$(date +'%Y%m%d')
LOGFILE=$PGLOG/tablemaint_${DATE}.log

# exclude tables in the special system schema "pg_toast"
SELECT_ALL="SELECT quote_ident(t.schemaname) || '.' || quote_ident(t.relname)\
 FROM pg_stat_all_tables as t\
 WHERE t.schemaname NOT IN ('pg_toast');"

# SELECT all tables that haven't been autovacuumed in at least 1 day.
SELECT="SELECT quote_ident(t.schemaname) || '.' || quote_ident(t.relname)\
 FROM pg_stat_all_tables as t\
WHERE t.schemaname NOT IN ('pg_toast')\
  AND (CURRENT_TIMESTAMP - coalesce(t.last_autovacuum, '1900-01-01')) > '1 days'::interval;"

for db in postgres; do
  EXEC_SQL="psql -U postgres -p $PGPORT -d $db -qt --no-psqlrc"

  echo "Starting analyze on $db at $(date)" >>$LOGFILE
  echo $SELECT_ALL |$EXEC_SQL \
    |xargs -n1 printf "ANALYZE VERBOSE %s;" \
    |$EXEC_SQL >>$LOGFILE 2>&1

  echo "Starting vacuum on $db at $(date)" >>$LOGFILE
  echo $SELECT |$EXEC_SQL \
    |xargs -n1 printf "VACUUM VERBOSE %s" \
    |$EXEC_SQL >>$LOGFILE 2>&1
done

echo "Completed maintenance at $(date)" >>$LOGFILE
