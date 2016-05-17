#!/bin/bash
# this script will clear postgresql & OS level file cache, which is useful for benchmarking read performance.
# It stops the postgresql instance, safely clears OS cache, & restarts postgresql

PGENGINE=${PGENGINE:-/usr/ppas-9.4/bin}
PGPORT=${PGPORT:-5444}
PGDATA=${PGDATA:-/var/lib/ppas/9.4/data}

$PGENGINE/pg_ctl -D $PGDATA shutdown -m fast
sync && echo 3 > /proc/sys/vm/drop_caches
$PGENGINE/pg_ctl -D $PGDATA start -w -o 