SELECT * from timescaledb_information.hypertables
WHERE num_chunks > 0
ORDER BY 1, 2
;

SELECT * from timescaledb_information.hypertables
WHERE num_chunks = 0
ORDER BY 1, 2
;

-- hypertable compression definition
SELECT hypertable_schema, hypertable_name
 , tablespaces
 , num_dimensions, num_chunks
 , hcs.segmentby, hcs.orderby
FROM timescaledb_information.hypertables as h
FULL OUTER JOIN timescaledb_information.hypertable_compression_settings as hcs
  on (h.hypertable_schema || '.' || h.hypertable_name)::regclass = hcs.hypertable
WHERE num_chunks > 0
ORDER BY 1, 2
;

-- hypertable dimensions
SELECT hypertable_schema, hypertable_name
 , dimension_number, dimension_type
 , column_name, time_interval
 , num_partitions
FROM timescaledb_information.dimensions
ORDER BY 1, 2, 3
;


SELECT id as hypertable_id
 , schema_name, table_name
 , compression_state
 , compressed_hypertable_id
 , associated_table_prefix
from _timescaledb_catalog.hypertable as h
LIMIT 10
;

SELECT job_id, owner, application_name
 , schedule_interval, proc_schema, proc_name
 --, scheduled
 , next_start-now() as to_next_run
FROM timescaledb_information.jobs
WHERE hypertable_schema is NULL
;

SELECT hypertable_schema, proc_name, config, count(*)
FROM timescaledb_information.jobs
WHERE hypertable_schema is NOT NULL
GROUP BY 1, 2, 3 ORDER BY 1, 2, 3
;




 hypertable_schema |     proc_name      |                       config                        | count
-------------------+--------------------+-----------------------------------------------------+-------
 sample_ht_schema          | policy_compression | {"hypertable_id": 39, "compress_after": "14 days"}  |     1
 sample_ht_schema          | policy_compression | {"hypertable_id": 41, "compress_after": "14 days"}  |     1
 sample_ht_schema          | policy_compression | {"hypertable_id": 43, "compress_after": "14 days"}  |     1
 sample_ht_schema          | policy_compression | {"hypertable_id": 45, "compress_after": "14 days"}  |     1

 hypertable_id |      schema_name      |         table_name         | compression_state | compressed_hypertable_id | associated_table_prefix
---------------+-----------------------+----------------------------+-------------------+--------------------------+-------------------------
            63 | sample_ht_schema              | ht_1560                   |                 1 |                       64 | _hyper_63
            64 | _timescaledb_internal | _compressed_hypertable_64  |                 2 |                   (null) | _hyper_64
           488 | sample_ht_schema              | ht_2322                   |                 1 |                      489 | _hyper_488
           489 | _timescaledb_internal | _compressed_hypertable_489 |                 2 |                   (null) | _hyper_489

---
SELECT schema_name, compression_state, count(*) FROM _timescaledb_catalog.hypertable GROUP BY 1, 2 ORDER BY 1 ;
      schema_name      | compression_state | count
-----------------------+-------------------+-------
 _timescaledb_internal |                 2 |   257
 sample_ht_schema              |                 1 |   249
 timeseries            |                 1 |     8

-- count(*) where chunks = 0
  162
-- where chunks > 0
  90

--
SELECT hypertable_schema, count(*) from timescaledb_information.hypertables
GROUP BY 1 ;

 hypertable_schema | count
-------------------+-------
 sample_ht_schema          |   244
 timeseries        |     8

 hypertable_schema | hypertable_name | dimension_number | dimension_type | column_name | time_interval | num_partitions
-------------------+-----------------+------------------+----------------+-------------+---------------+----------------
 sample_ht_schema          | ht_1001        |                1 | Time           | event_ts    | 1 day         |         (null)
 sample_ht_schema          | ht_1001        |                2 | Space          | tag_id      | (null)        |             10
. . .
 sample_ht_schema          | ht_999999      |                1 | Time           | event_ts    | 1 day         |         (null)
 sample_ht_schema          | ht_999999      |                2 | Space          | tag_id      | (null)        |             10
 timeseries        | ht_1511        |                1 | Time           | event_ts    | 1 day         |         (null)
 timeseries        | ht_1656        |                1 | Time           | event_ts    | 1 day         |         (null)
 timeseries        | ht_1658        |                1 | Time           | event_ts    | 1 day         |         (null)
 timeseries        | ht_2374        |                1 | Time           | event_ts    | 1 day         |         (null)
 timeseries        | ht_2642        |                1 | Time           | event_ts    | 1 day         |         (null)
 timeseries        | ht_2882        |                1 | Time           | event_ts    | 1 day         |         (null)
 timeseries        | ht_740         |                1 | Time           | event_ts    | 1 day         |         (null)
 timeseries        | ht_742         |                1 | Time           | event_ts    | 1 day         |         (null)

--
SELECT create_hypertable('tbl', by_range('time', INTERVAL '1 day'));
create_default_indexes
migrate_data

SELECT add_dimension('tbl', by_hash('tag_id', 10));

SELECT create_hypertable('sample_ht_schema.ht_1554', by_range('event_ts', INTERVAL '1 day'));
SELECT add_dimension('sample_ht_schema.ht_1554', by_hash('tag_id', 10));

SELECT * 
from timescaledb_information.hypertables as h
WHERE h.num_chunks > 0
  and h.hypertable_schema = 'sample_ht_schema'
;


SELECT hypertable_name, count(*) from timescaledb_information.hypertables
GROUP BY hypertable_name HAVING count(*) > 1
 hypertable_name | count
-----------------+-------
 ht_2374        |     2


PERFORM create_hypertable('sample_ht_schema.ht_2322', by_range('event_ts', INTERVAL '1 day'));
PERFORM add_dimension('sample_ht_schema.ht_2322', by_hash('tag_id', 10));

CREATE INDEX "ht_2322_event_ts_idx" ON sample_ht_schema.ht_2322 btree (event_ts DESC), tablespace "ixsp02"

CREATE UNIQUE INDEX "ux1_ht_2322_ts_tag" ON sample_ht_schema.ht_2322 (event_ts, tag_id DESC) 
 INCLUDE (bool_val) WITH (fillfactor='95') TABLESPACE "ixsp02" ;

CREATE UNIQUE INDEX "ux2_ht_2322_tag_ts" ON sample_ht_schema.ht_2322 (tag_id DESC, event_ts)
 WITH (fillfactor='95') TABLESPACE "ixsp02" ;

CREATE UNIQUE INDEX "ux3_ht_2322_float" ON sample_ht_schema.ht_2322 (event_ts, tag_id DESC)
 INCLUDE (float_val) WITH (fillfactor='95') TABLESPACE "ixsp02" ;

CREATE UNIQUE INDEX "ux4_ht_2322_int" ON sample_ht_schema.ht_2322 (event_ts, tag_id DESC)
 INCLUDE (int_val) WITH (fillfactor='95') TABLESPACE "ixsp02" ;




SET default_tablespace = tbsp02;

--
-- Name: nx2_fdm_ftn; Type: INDEX; Schema: sample_ht_schema; Owner: postgres; Tablespace: tbsp02
--

CREATE INDEX nx2_fdm_ftn ON sample_ht_schema.fdm_uq_full_tag USING btree ((((((device_id || '.'::text) || (source_name)::text) || '.'::text) || (tag_name)::text)));


ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA sample_ht_schema GRANT SELECT ON TABLES TO sample_ht_schema_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA sample_ht_schema GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO sample_ht_schema_rw;


SELECT u.relname
 , seq_scan, idx_scan, n_tup_ins
 , n_live_tup, n_dead_tup
 , heap_blks_read, heap_blks_hit
from pg_stat_user_tables as u
join pg_statio_user_tables as io on u.relid = io.relid
WHERE u.schemaname = '_timescaledb_internal'
ORDER BY n_live_tup DESC
LIMIT 10
;

SELECT u.relname
 , greatest(coalesce(last_analyze, '-infinity'), coalesce(last_autoanalyze, '-infinity')) as any_analyze
 , greatest(coalesce(last_vacuum, '-infinity'), coalesce(last_autovacuum, '-infinity')) as any_vacuum
FROM pg_stat_user_tables as u
WHERE u.schemaname = '_timescaledb_internal'
--WHERE u.schemaname = 'sample_ht_schema'
ORDER BY 3 DESC
LIMIT 10
;
