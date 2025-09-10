-- stats.sql

SELECT sum(heap_blks_read) as heap_read
 , sum(heap_blks_hit)  as heap_hit
 , CASE WHEN (sum(heap_blks_hit) + sum(heap_blks_read)) = 0 THEN 0
    ELSE sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) 
  END as ratio
FROM 
  pg_statio_user_tables
;

SELECT 
  relname, 
  100 * idx_scan / (seq_scan + idx_scan) percent_of_times_index_used, 
  n_live_tup rows_in_table
FROM 
  pg_stat_user_tables
WHERE 
    seq_scan + idx_scan > 0 
ORDER BY 
  n_live_tup DESC;


SELECT 
  sum(idx_blks_read) as idx_read,
  sum(idx_blks_hit)  as idx_hit,
  (sum(idx_blks_hit) - sum(idx_blks_read)) / sum(idx_blks_hit) as ratio
FROM 
  pg_statio_user_indexes;

