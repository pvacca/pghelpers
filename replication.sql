-- replication.sql

--
SELECT * FROM pg_hba_file_rules WHERE 'replication' = ANY (database) ;

-- replica lag
SELECT pg_is_in_recovery() AS is_replica,
  pg_last_wal_receive_lsn() AS receive,
  pg_last_wal_replay_lsn() AS replay,
  pg_last_wal_receive_lsn() - pg_last_wal_replay_lsn() AS replay_gap,
  EXTRACT(
    EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::int AS lag_seconds
;

SELECT pid, status, EXTRACT(EPOCH FROM (now() - last_msg_send_time))::int as replica_lag_seconds
 , (EXTRACT(EPOCH FROM (last_msg_receipt_time - last_msg_send_time)) *1000)::int as network_lag_ms
;

SELECT client_addr, usename as user, application_name
 , state, sync_state
 , pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)::bigint / 1024 as total_lag_kb
from pg_stat_replication
;

-- slots
SELECT slot_name, plugin, slot_type
 , datoid, database, active
 , restart_lsn
from pg_replication_slots
;


SELECT slot_name
 , pg_size_pretty( 
  	pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) 
  	  ) as retained_wal
 , active
 , restart_lsn 
FROM pg_replication_slots
;

-- replication identity
SELECT c.oid, nsp.nspname, c.relname
, CASE relreplident
    WHEN 'd' THEN 'default'
    WHEN 'n' THEN 'nothing'
    WHEN 'f' THEN 'full'
    WHEN 'i' THEN 'index'
  END AS replica_identity
from pg_class as c
JOIN pg_namespace as nsp on c.relnamespace = nsp.oid
WHERE c.relkind = 'r' -- r = relation/ordinary table
  AND nsp.nspname NOT IN (
	'pg_toast'
, 'pg_catalog'
, 'information_schema'
)
  and nsp.nspname NOT LIKE 'pg_temp_%'
  and nsp.nspname NOT LIKE 'pg_toast_temp_%'
ORDER BY 2, 3
;

-- Find Heaps
SELECT CURRENT_CATALOG, c.relnamespace::regnamespace, c.relname, c.reltuples
  from pg_class as c
 WHERE relkind = 'r'
   and c.relnamespace::regnamespace NOT IN ('pg_catalog', 'information_schema')
   and NOT EXISTS (
   	SELECT FROM pg_index WHERE indrelid = c.oid
   	  and indisunique is TRUE
   	)
ORDER BY 1, 2, 3
;
