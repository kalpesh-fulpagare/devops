## Tables & Database
#### Table Size
```sql
SELECT pg_size_pretty(pg_total_relation_size('products'));  // Including Indices

SELECT pg_size_pretty(pg_relation_size('products'));

SELECT pg_size_pretty(hypertable_size('product_usages')); // Hypertable of Timescale
```
#### Sort Tables by Size
```sql
SELECT relname, pg_size_pretty(pg_total_relation_size(C.oid))
FROM pg_class C
LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
WHERE nspname NOT IN ('pg_catalog', 'information_schema') AND C.relkind <> 'i' AND nspname !~ '^pg_toast'
ORDER BY pg_total_relation_size(C.oid) DESC LIMIT 120;
```
#### Database Size
```sql
SELECT pg_size_pretty(pg_database_size(current_database()));
```

## Partitioning
#### Table Size including all Partitions & indices
```sql
SELECT pg_size_pretty(sum(pg_total_relation_size(inhrelid::regclass))) as total_size
FROM pg_inherits
WHERE inhparent = 'products'::regclass;
```
#### All partitions - Sorted by partition name
```sql
SELECT pg_size_pretty(sum(pg_total_relation_size(inhrelid::regclass))) as total_size
FROM pg_inherits
WHERE inhparent = 'products'::regclass;
```
#### All partitions - Sorted by partition size
```sql
SELECT inhrelid::regclass as partition_name, pg_size_pretty(pg_total_relation_size(inhrelid::regclass)) as partition_size
FROM pg_inherits
WHERE inhparent = 'products'::regclass AND pg_total_relation_size(inhrelid::regclass) > 1048576
ORDER BY pg_total_relation_size(inhrelid::regclass) DESC;
```
#### View Partition information
```sql
DO $$
DECLARE
    partition_name TEXT;
    total_size BIGINT := 0;
BEGIN
    FOR partition_name IN
        SELECT pg_class.relname
        FROM pg_inherits
        JOIN pg_class ON pg_inherits.inhrelid = pg_class.oid
        WHERE pg_inherits.inhparent = 'products'::regclass
    LOOP
        EXECUTE FORMAT('SELECT pg_total_relation_size(''%I'')', partition_name) INTO total_size;
        RAISE NOTICE 'Partition % size: %', partition_name, pg_size_pretty(total_size);
    END LOOP;
END $$;
```

## Indices
#### Big Indices
```sql
SELECT relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch, pg_size_pretty(pg_relation_size(indexrelname::regclass)) as size
FROM pg_stat_all_indexes
WHERE schemaname = 'public' AND indexrelname NOT LIKE 'pg_toast_%' 
ORDER BY pg_relation_size(indexrelname::regclass) DESC 
LIMIT 50; 
```
#### Unused Indices
```sql
SELECT relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch, pg_size_pretty(pg_relation_size(indexrelname::regclass)) as size
FROM pg_stat_all_indexes
WHERE schemaname = 'public' AND indexrelname NOT LIKE 'pg_toast_%' AND idx_scan = 0 AND idx_tup_read = 0 AND idx_tup_fetch = 0
ORDER BY pg_relation_size(indexrelname::regclass) DESC;

SELECT schemaname, relname AS table_name, indexrelname AS index_name, idx_scan AS index_scans
FROM pg_stat_user_indexes WHERE idx_scan = 0;
```
```sql
SELECT idx.schemaname, idx.relname AS table_name, idx.indexrelname AS index_name, idx.idx_scan AS index_scans,
idx.idx_tup_read AS index_tuples_read, idx.idx_tup_fetch AS index_tuples_fetched, db.stats_reset AS stats_last_reset
FROM pg_stat_user_indexes AS idx
JOIN pg_stat_database AS db
ON db.datid = (SELECT oid FROM pg_database WHERE datname = current_database())
WHERE db.datname = current_database() AND idx.idx_scan = 0;
```
#### Index Usage
```sql
SELECT
    idx.schemaname, idx.relname AS table_name, idx.indexrelname AS index_name,
    idx.idx_scan AS index_scans, idx.idx_tup_read AS index_tuples_read,
    idx.idx_tup_fetch AS index_tuples_fetched, db.stats_reset AS stats_last_reset
FROM pg_stat_user_indexes AS idx
JOIN pg_stat_database AS db
ON db.datid = (SELECT oid FROM pg_database WHERE datname = current_database())
WHERE db.datname = current_database();
```
#### Last Stats reset time
```sql
SELECT datname, stats_reset FROM pg_stat_database;
```
#### Index Creation Progress
```sql
SELECT 
now()::TIME(0), p.phase, round(p.blocks_done / p.blocks_total::numeric * 100, 2) AS "% done", 
p.blocks_total, p.blocks_done, p.tuples_total, p.tuples_done, a.query, ai.schemaname, 
ai.relname, ai.indexrelname
FROM pg_stat_progress_create_index p
JOIN pg_stat_activity a ON p.pid = a.pid
LEFT JOIN pg_stat_all_indexes ai on ai.relid = p.relid AND ai.indexrelid = p.index_relid;
```

## Vaccum information
```sql
SELECT schemaname, relname, last_vacuum, last_autovacuum,n_live_tup, n_dead_tup, vacuum_count, autovacuum_count FROM pg_stat_user_tables WHERE relname='products';

SELECT schemaname, relname, last_vacuum, last_autovacuum, vacuum_count, autovacuum_count FROM pg_stat_user_tables;
```
```sql
SELECT
  p.pid, now() - a.xact_start AS duration,
  coalesce(wait_event_type ||'.'|| wait_event, 'f') AS waiting,
  CASE
    WHEN a.query ~*'^autovacuum.*to prevent wraparound' THEN 'wraparound'
    WHEN a.query ~*'^vacuum' THEN 'user'
  ELSE 
    'regular'
  END AS mode,
  p.datname AS database, p.relid::regclass AS table, p.phase, p.index_vacuum_count,
  pg_size_pretty(p.heap_blks_total * current_setting('block_size')::int) AS table_size,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
  pg_size_pretty(p.heap_blks_scanned * current_setting('block_size')::int) AS scanned,
  pg_size_pretty(p.heap_blks_vacuumed * current_setting('block_size')::int) AS vacuumed,
  round(100.0 * p.heap_blks_scanned / p.heap_blks_total, 1) AS scanned_pct,
  round(100.0 * p.heap_blks_vacuumed / p.heap_blks_total, 1) AS vacuumed_pct,
  round(100.0 * p.num_dead_tuples / p.max_dead_tuples,1) AS dead_pct
FROM pg_stat_progress_vacuum p
JOIN pg_stat_activity a using (pid)
ORDER BY now() - a.xact_start DESC;
```

## Deadlocks 
#### Blocking queries
```sql
SELECT pid, now() - pg_stat_activity.query_start AS duration, usename, pg_blocking_pids(pid) as blocked_by, query as blocked_query 
FROM pg_stat_activity 
WHERE cardinality(pg_blocking_pids(pid)) > 0;
```
#### DeadTuple count of top tables
```sql
SELECT n_live_tup, n_dead_tup, relname FROM pg_stat_all_tables ORDER BY n_dead_tup DESC LIMIT 25;

SELECT relname, n_live_tup, n_dead_tup, round((n_dead_tup/n_live_tup::float::numeric)*100, 2) perc_dead_tuple 
FROM pg_stat_all_tables WHERE n_live_tup > 1 
ORDER BY n_dead_tup DESC LIMIT 25;

SELECT relname, n_live_tup, n_dead_tup, round((n_dead_tup/n_live_tup::float::numeric)*100, 2) perc_dead_tuple 
FROM pg_stat_all_tables WHERE n_live_tup > 1 AND n_dead_tup > 25000 
ORDER BY perc_dead_tuple DESC LIMIT 25;
```

## PgStat Statments - Useful commands
#### Long Pending Queries / Slow queries
```sql
SELECT pid, now() - pg_stat_activity.query_start AS duration, state, query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes' AND state = 'active' AND query NOT LIKE 'START_REPLICATION%';

SELECT pid, now() - pg_stat_activity.query_start AS duration, state, query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '1 minutes' AND state = 'active' AND query NOT LIKE 'START_REPLICATION%';

SELECT pid, now() - pg_stat_activity.query_start AS duration, pg_stat_activity.query_start AS start_time, query, state 
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '1 minutes' AND state = 'active' AND pid = 22401 AND query NOT LIKE 'START_REPLICATION%';
```
#### View Query details from PID
```sql
SELECT pid, query, now() - pg_stat_activity.query_start AS duration, pg_stat_activity.query_start AS start_time, state 
FROM pg_stat_activity
WHERE pid = 22401;
```
#### Terminate a connection
```sql
SELECT pg_cancel_backend(22401);
SELECT pg_terminate_backend(22401); 
```
#### Terminate *ALL* Connections
```sql
SELECT pid, pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = current_database() AND pid <> pg_backend_pid();
```
#### Misc
```sql
SELECT * from pg_stat_statements order by shared_blks_hit + shared_blks_read desc limit 5;
```

## Connection
#### Connection Info
```sql
SELECT sum(numbackends) FROM pg_stat_database;
SELECT count(*), client_addr from pg_stat_activity group by client_addr;
SELECT client_addr, COUNT(client_addr) from pg_stat_activity  GROUP BY pg_stat_activity.client_addr;
SELECT application_name, client_addr, pid, usename from pg_stat_activity;
```
#### Connect psql Console with SSL Connection
```sql
psql "sslmode=disable hostaddr=0.0.0.0 port=5432 user=kalpesh dbname=sample_production"
psql "hostaddr=0.0.0.0 port=5432 user=kalpesh dbname=sample_production"
```

## TimescaleDB
#### Partition/Chunk Information of Hypertable
```sql
SELECT hypertable_name, chunk_name,primary_dimension,range_start,range_end FROM timescaledb_information.chunks WHERE hypertable_name='apps_and_usages' ORDER BY range_start;

SELECT * FROM timescaledb_information.chunks WHERE hypertable_name = 'product_usages';

SELECT * FROM timescaledb_information.chunks WHERE hypertable_name = 'product_usages' AND chunk_name = '_hyper_0_007_chunk';

SELECT show_chunks('product_usages', older_than => INTERVAL '3 months');

SELECT drop_chunks('product_usages', older_than => INTERVAL '3 months');
```
#### Continuous Aggregates
```sql
CREATE MATERIALIZED VIEW product_usage_daily_view WITH (timescaledb.continuous) AS
SELECT time_bucket('1 day', date) as product_data_bucket, product_id, SUM(product_sold) AS prod_sold, SUM(product_purchased) AS prod_buy FROM product_usages
GROUP BY product_id, product_data_bucket WITH NO DATA;

SELECT add_continuous_aggregate_policy('product_usage_daily_view', start_offset => INTERVAL '2 days', end_offset => INTERVAL '1 hour', schedule_interval => INTERVAL '1 hour');

CALL refresh_continuous_aggregate('product_usage_daily_view', NULL, localtimestamp - INTERVAL '2 day');

SELECT view_name, format('%I.%I', materialization_hypertable_schema, materialization_hypertable_name) AS materialization_hypertable FROM timescaledb_information.continuous_aggregates;

SELECT * FROM timescaledb_information.continuous_aggregates;

SELECT * FROM timescaledb_information.chunks WHERE hypertable_name = '_materialized_hypertable_35';

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_daily_data_usage_counts ON product_usage_daily_view(device_id, product_data_bucket);

SELECT schedule_interval, config FROM timescaledb_information.jobs WHERE hypertable_name = <table_name> AND timescaledb_information.jobs.proc_name = 'policy_retention';

SELECT schedule_interval, config FROM timescaledb_information.jobs WHERE hypertable_name = 'product_usages' AND timescaledb_information.jobs.proc_name = 'policy_retention';
```
