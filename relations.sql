-- relations.sql

-- databases + size
SELECT datname
 , datallowconn, age(datfrozenxid)
 , pg_database_size(datname) as size_bytes
 , round(pg_database_size(datname) / (1024*1024*1024.0),1) as size_gib
 --, encoding
from pg_database
WHERE datname NOT IN ('postgres','template0','template1','rdsadmin')
ORDER BY 1
;

-- 
SELECT oid, nspname as namespace from pg_namespace ORDER BY nspname;
-- or \dn

-- tablespace info
SELECT ts.oid, ts.spcname as tablespace 
  , pg_tablespace_location(ts.oid)
	, pg_tablespace_size(ts.oid) as tablespace_size_bytes
	, pg_size_pretty(pg_tablespace_size(ts.oid)) as tablespace_size
  , ts.spcowner::regrole AS owner
  , ts.spcacl AS access_privileges
from pg_tablespace as ts
ORDER BY CASE
    WHEN ts.spcname = 'pg_default' THEN 1
    WHEN ts.spcname = 'pg_global' THEN 2
    ELSE 3
  END, ts.spcname
;

-- relation size by namespace, tablespace
SELECT n.nspname
 , CASE c.relkind
    WHEN 'r' THEN 'table'
    WHEN 'i' THEN 'index'
    WHEN 'S' THEN 'sequence'
    WHEN 't' THEN 'toast'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'materialized view'
    WHEN 'p' THEN 'partitioned table'
    ELSE c.relkind::text
  END as relation_type
 , COALESCE(t.spcname, 'pg_default') as tablespace
 , count(*) as relation_count
 , pg_size_pretty(sum(pg_relation_size(c.oid))) as total_relation_size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_tablespace t ON c.reltablespace = t.oid
WHERE c.relkind IN ('r', 'i', 'S', 't', 'm', 'p')  -- tables, indexes, sequences, toast, materialized views, partitioned tables
    AND n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
GROUP BY n.nspname
 , CASE c.relkind
    WHEN 'r' THEN 'table'
    WHEN 'i' THEN 'index'
    WHEN 'S' THEN 'sequence'
    WHEN 't' THEN 'toast'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'materialized view'
    WHEN 'p' THEN 'partitioned table'
    ELSE c.relkind::text
  END
 , COALESCE(t.spcname, 'pg_default')
ORDER BY 1, 3, 2, 5 DESC
;

-- relation size
SELECT
  n.nspname AS schema_name
 , c.relname AS relation_name
 , CASE c.relkind 
    WHEN 'r' THEN 'table'
    WHEN 'i' THEN 'index'
    WHEN 'S' THEN 'sequence'
    WHEN 't' THEN 'toast'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'materialized view'
    WHEN 'p' THEN 'partitioned table'
    ELSE c.relkind::text
  END AS relation_type
 , COALESCE(t.spcname, 'pg_default') AS tablespace_name
 , pg_size_pretty(pg_relation_size(c.oid)) AS relation_size
--  , pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size
--  , pg_size_pretty(pg_indexes_size(c.oid)) AS indexes_size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_tablespace t ON c.reltablespace = t.oid
WHERE c.relkind IN ('r', 'i', 'S', 't', 'm', 'p')  -- tables, indexes, sequences, toast, materialized views, partitioned tables
    AND n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
ORDER BY
  pg_total_relation_size(c.oid) DESC
 , n.nspname, c.relname
;

-- table summary
with tables as (
	SELECT pg_total_relation_size(t.relid) as total
		, pg_relation_size(relid) as relsize 	-- size of raw relation data in main data fork
		, pg_table_size(relid) as tablesize 	-- includes TOAST space, free space map, and visibility map
		, sum(pg_relation_size(i.indexrelid)) as indexsize
		, t.schemaname, t.relname, t.seq_scan
		, t.relid, t.seq_tup_read, t.idx_scan, t.idx_tup_fetch
		, t.n_live_tup, t.n_dead_tup, t.autovacuum_count, t.autoanalyze_count
	from pg_stat_all_tables as t join pg_stat_all_indexes as i USING (relid)
	GROUP BY total, relsize, tablesize, t.schemaname, t.relname, t.seq_scan
		, t.relid, t.seq_tup_read, t.idx_scan, t.idx_tup_fetch
		, t.n_live_tup, t.n_dead_tup, t.autovacuum_count, t.autoanalyze_count
	--ORDER BY t.seq_scan desc
)
SELECT t.relid
	, t.total as total_bytes
	, round(t.total / (1024*1024*1024.0),1) as total_gib
	, t.indexsize as indexsize_bytes
	, t.tablesize as tablesize_bytes
	, t.relsize as relsize_bytes
	, t.tablesize-t.relsize as toastsize_bytes
	, CASE WHEN t.total = 0 THEN 0.0 else round(100*t.tablesize / t.total, 1) END as pcnt_tbl
	, CASE WHEN t.total = 0 THEN 0.0 else round(100*t.indexsize / t.total, 1) END as pcnt_idx
	, CASE WHEN t.total = 0 THEN 0.0 else round(100*t.relsize / t.total, 1) END as tbl_pcnt_rel
	, CASE WHEN t.total = 0 THEN 0.0 else round(100*(t.tablesize-t.relsize) / t.total, 1) END as tbl_pcnt_toast
	, c.reltablespace as tablespaceid
	, CASE when c.reltablespace = 0 then 'pg_default' ELSE ts.spcname END as tablespace
	, t.schemaname, t.relname
	-- , t.seq_scan, t.seq_tup_read, t.idx_scan, t.idx_tup_fetch
	-- , t.n_live_tup, t.n_dead_tup, t.autovacuum_count, t.autoanalyze_count
	-- , it.heap_blks_read, it.heap_blks_hit, it.idx_blks_read, it.idx_blks_hit
	-- , it.toast_blks_read, it.toast_blks_hit, it.tidx_blks_read, it.tidx_blks_hit
FROM tables as t
	LEFT join pg_statio_all_tables as it USING (relid)
	LEFT join pg_class as c on t.relid = c.oid
	LEFT join pg_tablespace as ts on c.reltablespace = ts.oid
WHERE t.schemaname NOT IN (
	'pg_toast'
, 'pg_catalog'
, 'information_schema'
)
  and t.schemaname NOT LIKE 'pg_temp_%'
  and t.schemaname NOT LIKE 'pg_toast_temp_%'
ORDER BY t.schemaname, t.relname
;


-- relations simple
with tables as (
	SELECT relid, schemaname, relname
	 , pg_total_relation_size(relid) as total_bytes
	 , pg_relation_size(relid) as relsize 	-- size of raw relation data in main data fork
	 , pg_table_size(relid) as tablesize 	-- includes TOAST space, free space map, and visibility map
	 , pg_indexes_size(relid) as indexsize
	 , coalesce(last_vacuum, '-infinity') as last_vacuum
	 , coalesce(last_autovacuum, '-infinity') as last_autovacuum
	 , coalesce(last_analyze, '-infinity') as last_analyze
	 , coalesce(last_autoanalyze, '-infinity') as last_autoanalyze
	from pg_stat_all_tables
	ORDER BY schemaname, relname
)
SELECT t.relid, t.schemaname, t.relname
	--, pg_size_pretty(t.total_bytes) as total_size
	, round(t.total_bytes/(1024*1024*1024.0), 2) as total_gib
	, CASE WHEN t.total_bytes = 0 THEN 0.0 else round(100*t.tablesize / t.total_bytes, 1) END as pcnt_tbl
	, CASE WHEN t.total_bytes = 0 THEN 0.0 else round(100*t.indexsize / t.total_bytes, 1) END as pcnt_idx
	, round((t.tablesize-t.relsize)/(1024*1024*1024), 0) as toast_gib
	, now()-NULLIF(GREATEST(last_vacuum, last_autovacuum), '-infinity') as any_vacuum
	, now()-NULLIF(GREATEST(last_analyze, last_autoanalyze), '-infinity') as any_analyze
from tables as t
WHERE t.schemaname NOT IN (
	'pg_toast'
, 'pg_catalog'
, 'information_schema'
)
  and t.schemaname NOT LIKE 'pg_temp_%'
  and t.schemaname NOT LIKE 'pg_toast_temp_%'
-- ORDER BY t.schemaname, t.total_bytes DESC
ORDER BY t.total_bytes DESC
;

