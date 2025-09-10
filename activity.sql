-- activity.sql

-- count of blocked sessions
SELECT count(*)
from pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0
;

-- get some details
SELECT pid
 , usename
 , application_name
 , pg_blocking_pids(pid) as blocked_by
 , now()-xact_start as xact_duration
-- , query
from pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0
ORDER BY xact_start
;


-- Activity Summary
SELECT coalesce(state, wait_event) as state
	, count(*) as session_count
	, max(CASE WHEN backend_type = 'client backend' then now()-state_change else NULL END) as longest_in_state
from pg_stat_activity
GROUP BY coalesce(state, wait_event)
ORDER BY count(*) DESC, 1
;

-- SSL Activity Summary
SELECT coalesce(state, wait_event) as state
	, ssl.ssl, ssl.version
	, count(*) as session_count
	, max(CASE WHEN backend_type = 'client backend' then now()-state_change else NULL END) as longest_in_state
from pg_stat_activity as a 
LEFT JOIN pg_stat_ssl as ssl USING (pid)
GROUP BY coalesce(state, wait_event)
	, ssl.ssl, ssl.version
ORDER BY count(*) DESC, 1,2,3
;

-- Activity summary - Client
SELECT datname
	, state, wait_event_type, wait_event
	, count(*) as session_count
	, max(now()-state_change) as longest_in_state
from pg_stat_activity
WHERE backend_type = 'client backend'
  and state <> 'idle'
GROUP BY datname
	, state, wait_event_type, wait_event
ORDER BY datname, state, wait_event
;

-- Activity summary - System
SELECT wait_event_type
, wait_event
, backend_type
, count(*) as session_count
from pg_stat_activity
WHERE backend_type <> 'client backend'
GROUP BY wait_event_type
, wait_event
, backend_type
ORDER BY backend_type
;

-- system activity
SELECT datname, pid, wait_event, wait_event_type
 , backend_type, now()-backend_start as backend_duration
 , query
 from pg_stat_activity
WHERE backend_type <> 'client backend'
ORDER BY backend_start
;

-- 'parallel worker'
-- 'autovacuum worker'

-- current activity
SELECT datid
 , datname
 , pid
 , state
-- , backend_type
-- , backend_start
 , wait_event_type
 , wait_event
 , now()-xact_start as xact_duration
 , now()-state_change as state_duration
 , ssl.ssl, ssl.version
 , usename
 , application_name
 , left(query, 33) as query_start
from pg_stat_activity as a 
LEFT JOIN pg_stat_ssl as ssl USING (pid)
WHERE pid <> pg_backend_pid()
  and state <> 'idle'
ORDER BY backend_type, wait_event, xact_start
;

-- activity simple
SELECT pid, backend_type, datname, state, now()-xact_start as xact_duration
 , left(query, 33)
from pg_stat_activity
WHERE pid <> pg_backend_pid()
  and state <> 'idle'
ORDER BY CASE WHEN backend_type = 'client backend' then '' else backend_type END
 , xact_start
;

-- blocks
SELECT datname, pid, usename, now()-state_change as duration, cardinality(pg_blocking_pids(pid)) as block_count
from pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0
ORDER BY xact_start
LIMIT 15
;

SELECT datname
 , pid
 , usename
 , state
 , wait_event_type
 , wait_event
 , now()-state_change as duration
 , left(query, 33) as query_start
from pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0
ORDER BY xact_start
LIMIT 15
;

SELECT pid 
 , datname
 , usename
 , application_name
 , state
 , wait_event_type
 , wait_event
 , now()-state_change as duration
 , left(query, 80) as query_start
from pg_stat_activity
WHERE pid = ANY(pg_blocking_pids(NNN))
ORDER BY state_change
;

-- https://www.postgresql.org/docs/current/transaction-id.html
-- prepared transaction activity
SELECT pid, datname, state, backend_xid
 , now()-xact_start as xact_duration
 , pg_xact_status(px.xid::xid8) as xact_status
 , px.owner
 , left(query, 33) as query_start
 , px.gid as transaction_gid
 , now()-px.prepared as stmt_duration
from pg_stat_activity as a
LEFT JOIN pg_prepared_xacts as px 
  on a.backend_xid = px.xid
WHERE a.backend_type = 'client backend'
  AND a.state <> 'idle'
  AND a.pid <> pg_backend_pid()
ORDER BY xact_start
;

-- Full Query text by pid
\x\t

SELECT pid, datname, usename, application_name, query_start
 , now()-query_start as duration
 , query
from pg_stat_activity
WHERE pid = 

\g\x\t

-- system activity
SELECT pid
 , usename
 , application_name
 , wait_event_type
 , wait_event
 , backend_type
 , state
 , now()-state_change as time_in_state
 , left(query, 33)
from pg_stat_activity
WHERE backend_type <> 'client backend'
ORDER BY wait_event
;




;with recursive 
    find_the_source_blocker as (
        select  pid
               ,pid as blocker_id
        from pg_stat_activity pa
        where pa.state<>'idle'
              and array_length(pg_blocking_pids(pa.pid), 1) is null

        union all

        select              
                t.pid  as  pid
               ,f.blocker_id as blocker_id
        from find_the_source_blocker f 
        join (  SELECT
                    act.pid,
                    blc.pid AS blocker_id
                FROM pg_stat_activity AS act
                LEFT JOIN pg_stat_activity AS blc ON blc.pid = ANY(pg_blocking_pids(act.pid))
                where act.state<>'idle') t on f.pid=t.blocker_id
        )
    
select distinct 
       s.pid
      ,s.blocker_id
      ,pb.usename       as blocker_user
      ,pb.query_start   as blocker_start
      ,pb.query         as blocker_query
      ,pt.query_start   as trans_start
      ,pt.query         as trans_query
from find_the_source_blocker s
join pg_stat_activity pb on s.blocker_id=pb.pid
join pg_stat_activity pt on s.pid=pt.pid
where s.pid<>s.blocker_id
;

