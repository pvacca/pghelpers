-- vacuum.sql

--
 - depesz says:

autovacuum_max_workers = 10
autovacuum_vacuum_cost_delay = 2
autovacuum_vacuum_cost_limit = 500

"""
This gives me 2ms pause every 500 units in cost, which is from 25 to 500 pages, depending on their state (hit/miss/dirty). 
Which means that the sleep happens every 200kB..4MB worth of data vacuumed.
"""
ALTER TABLE a SET ( autovacuum_vacuum_cost_delay = 1, autovacuum_vacuum_cost_limit = 1000 );
ALTER TABLE b SET ( autovacuum_vacuum_cost_delay = 50, autovacuum_vacuum_cost_limit = 100 );

--

"""
Sometimes, for one reason or another, PostgreSQL has been unable to completely “freeze” a table, and 
the database can get dangerously close to the point that the wraparound data corruption can occur. 
Since vacuuming the indexes takes most of the time, sometimes, you want to tell PostgreSQL to skip 
that step, and just vacuum the heap so that the wraparound danger has passed. Thus, the INDEX_CLEANUP option.

But you still have to do a regular VACUUM on the table.
"""

VACUUM (ANALYZE, VERBOSE, INDEX_CLEANUP ON) ;

-- vacuum most bloated
SELECT 'VACUUM VERBOSE ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname) || ';'
  as vacuum_cmd 
FROM pg_class c 
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname NOT IN ('pg_catalog') AND c.relkind = 'r' 
 AND pg_stat_get_live_tuples(c.oid) > 0 
 AND (pg_stat_get_dead_tuples(c.oid)::numeric / NULLIF(pg_stat_get_live_tuples(c.oid), 0)) * 100 > 10
;

-- autovac activity
SELECT pid, query 
 FROM pg_stat_activity 
WHERE backend_type = 'autovacuum worker'
;

SHOW autovacuum_max_workers ;
SELECT CURRENT_TIMESTAMP, count(*) as autovacuum_workers 
 from pg_stat_activity WHERE backend_type = 'autovacuum worker' ;

-- VACUUM Progress
select v.*, a.query_start, age(now(), a.query_start), a.query
from pg_stat_progress_vacuum v
join pg_stat_activity a
on v.pid=a.pid
and v.pid=2136882
;

with max_age AS (
  SELECT setting as autovacuum_freeze_max_age
    from pg_catalog.pg_settings WHERE name = 'autovacuum_freeze_max_age'
)
SELECT datname, age(datfrozenxid)
 , round((2147483000-age(datfrozenxid))/2147483000.0, 2)
 , round((max_age.autovacuum_freeze_max_age-age(datfrozenxid))/max_age.autovacuum_freeze_max_age::float, 2)
FROM pg_database 
CROSS JOIN max_age
ORDER BY 2 DESC ;
;



SELECT c.oid::regclass
 , age(c.relfrozenxid)
 , pg_size_pretty(pg_total_relation_size(c.oid))
FROM pg_class as c
WHERE relkind = IN ('r','t','m')
  and NOT EXISTS (SELECT from pg_namespace WHERE oid = c.relnamespace
    AND nspname IN ('pg_toast')
)
ORDER BY 2 DESC
;

-- \c postgres, template1
VACUUM (VERBOSE,FREEZE) ;

ALTER DATABASE template0 with ALLOW_CONNECTIONS true ;
\c template0
VACUUM (VERBOSE, FREEZE) ;
\c postgres
ALTER DATABASE template0 with ALLOW_CONNECTIONS false ;

-- https://www.crunchydata.com/blog/managing-transaction-id-wraparound-in-postgresql
WITH max_age AS (
    SELECT 2000000000 as max_old_xid
        , setting AS autovacuum_freeze_max_age
        FROM pg_catalog.pg_settings
        WHERE name = 'autovacuum_freeze_max_age' )
, per_database_stats AS (
    SELECT datname
        , m.max_old_xid::int
        , m.autovacuum_freeze_max_age::int
        , age(d.datfrozenxid) AS oldest_current_xid
    FROM pg_catalog.pg_database d
    JOIN max_age m ON (true)
    WHERE d.datallowconn )
SELECT max(oldest_current_xid) AS oldest_current_xid
    , max(ROUND(100*(oldest_current_xid/max_old_xid::float))) AS percent_towards_wraparound
    , max(ROUND(100*(oldest_current_xid/autovacuum_freeze_max_age::float))) AS percent_towards_emergency_autovac
FROM per_database_stats
;
