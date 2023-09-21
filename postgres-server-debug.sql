/* Partition/Chunk Information of Hypertable(TimescaleDB) */
SELECT hypertable_name, chunk_name,primary_dimension,range_start,range_end FROM timescaledb_information.chunks WHERE hypertable_name='apps_and_usages' ORDER BY range_start;

SELECT * from pg_stat_statements order by shared_blks_hit + shared_blks_read desc limit 5;

/* TimescaleDB SQL's */
CREATE MATERIALIZED VIEW product_usage_daily_view
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 day', date) as product_data_bucket, product_id, SUM(product_sold) AS prod_sold, SUM(product_purchased) AS prod_buy
FROM product_usages
GROUP BY product_id, product_data_bucket
WITH NO DATA;

SELECT add_continuous_aggregate_policy('product_usage_daily_view', start_offset => INTERVAL '2 days', end_offset => INTERVAL '1 hour', schedule_interval => INTERVAL '1 hour');

CALL refresh_continuous_aggregate('product_usage_daily_view', NULL, localtimestamp - INTERVAL '2 day');

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_daily_data_usage_counts ON product_usage_daily_view(device_id, product_data_bucket);

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

SELECT * FROM timescaledb_information.chunks WHERE hypertable_name = 'product_usages';
SELECT * FROM timescaledb_information.chunks WHERE hypertable_name = 'product_usages' AND chunk_name = '_hyper_0_007_chunk';

SELECT show_chunks('product_usages', older_than => INTERVAL '3 months');

SELECT drop_chunks('product_usages', older_than => INTERVAL '3 months');

SELECT pg_size_pretty(hypertable_size('product_usages'));

SELECT view_name, format('%I.%I', materialization_hypertable_schema, materialization_hypertable_name) AS materialization_hypertable FROM timescaledb_information.continuous_aggregates;
SELECT * FROM timescaledb_information.continuous_aggregates;
SELECT * FROM timescaledb_information.chunks WHERE hypertable_name = '_materialized_hypertable_35';


SELECT schedule_interval, config FROM timescaledb_information.jobs WHERE hypertable_name = <table_name> AND timescaledb_information.jobs.proc_name = 'policy_retention';
SELECT schedule_interval, config FROM timescaledb_information.jobs WHERE hypertable_name = 'product_usages' AND timescaledb_information.jobs.proc_name = 'policy_retention';

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

SELECT dev_id, COUNT(dev_id) AS most_used_device FROM product_usages
WHERE date > '2022-12-11 00:00:00' AND date < '2022-12-11 23:59:59'
GROUP BY dev_id ORDER BY most_used_device DESC
LIMIT 1;

SELECT dev_id, COUNT(dev_id) AS most_used_device FROM product_usages
WHERE date > '2022-12-11 00:00:00' AND date < '2022-12-11 23:59:59' AND dev_id NOT IN(2034107, 2504081)
GROUP BY dev_id ORDER BY most_used_device DESC
LIMIT 1;

SELECT dev_id, COUNT(dev_id) AS most_used_device FROM product_data_usages
WHERE date > '2022-12-11 00:00:00' AND date < '2022-12-11 23:59:59'
GROUP BY dev_id ORDER BY most_used_device DESC
LIMIT 1;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/* Vaccum information*/
SELECT schemaname, relname, last_vacuum, last_autovacuum,n_live_tup, n_dead_tup, vacuum_count, autovacuum_count FROM pg_stat_user_tables WHERE relname='products';
SELECT schemaname, relname, last_vacuum, last_autovacuum, vacuum_count, autovacuum_count FROM pg_stat_user_tables;

# Postgresql Deadlock - Blocking Queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, usename, pg_blocking_pids(pid) as blocked_by, query as blocked_query 
FROM pg_stat_activity 
WHERE cardinality(pg_blocking_pids(pid)) > 0;

# Postgresql DeadTuple count of top tables
SELECT n_live_tup, n_dead_tup, relname FROM pg_stat_all_tables ORDER BY n_dead_tup DESC LIMIT 25;

SELECT relname, n_live_tup, n_dead_tup, round((n_dead_tup/n_live_tup::float::numeric)*100, 2) perc_dead_tuple 
FROM pg_stat_all_tables WHERE n_live_tup > 1 
ORDER BY n_dead_tup DESC LIMIT 25;

SELECT relname, n_live_tup, n_dead_tup, round((n_dead_tup/n_live_tup::float::numeric)*100, 2) perc_dead_tuple 
FROM pg_stat_all_tables WHERE n_live_tup > 1 AND n_dead_tup > 25000 
ORDER BY perc_dead_tuple DESC LIMIT 25;

# View query details from PID
SELECT pid, query, now() - pg_stat_activity.query_start AS duration, pg_stat_activity.query_start AS start_time, state 
FROM pg_stat_activity
WHERE pid = 22401;

# Postgresql Big Tables
SELECT relname, pg_size_pretty(pg_total_relation_size(C.oid))
  FROM pg_class C
  LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
  WHERE nspname NOT IN ('pg_catalog', 'information_schema')
    AND C.relkind <> 'i'
    AND nspname !~ '^pg_toast'
  ORDER BY pg_total_relation_size(C.oid) DESC
  LIMIT 120;

# Postgresql Big Indices
SELECT relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch, pg_size_pretty(pg_relation_size(indexrelname::regclass)) as size
FROM pg_stat_all_indexes
WHERE schemaname = 'public' AND indexrelname NOT LIKE 'pg_toast_%' AND idx_scan = 0
    AND idx_tup_read = 0 AND idx_tup_fetch = 0
ORDER BY pg_relation_size(indexrelname::regclass) DESC;

# Unused PG Index
SELECT relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch, pg_size_pretty(pg_relation_size(indexrelname::regclass)) as size
FROM pg_stat_all_indexes
WHERE schemaname = 'public' AND indexrelname NOT LIKE 'pg_toast_%' AND idx_scan = 0 AND idx_tup_read = 0 AND idx_tup_fetch = 0
ORDER BY pg_relation_size(indexrelname::regclass) DESC;

# Postgresql Tablespace
# https://pgdash.io/blog/tablespaces-postgres.html
CREATE TABLESPACE db_table_space OWNER kalpesh LOCATION '/mnt/volume/postgresql_storage';
CREATE TABLE users_2021_05_23 PARTITION OF users FOR VALUES FROM ('2021-05-23') TO ('2021-05-24') TABLESPACE db_table_space;
ALTER INDEX users_2021_05_23_user_id_e_idx1 SET TABLESPACE db_table_space;

# Postgresql Connections
SELECT sum(numbackends) FROM pg_stat_database;
SELECT count(*), client_addr from pg_stat_activity group by client_addr;
SELECT client_addr, COUNT(client_addr) from pg_stat_activity  GROUP BY pg_stat_activity.client_addr;
SELECT application_name, client_addr, pid, usename from pg_stat_activity;

# Postgresql Terminate existing Connections
SELECT pid, pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = current_database() AND pid <> pg_backend_pid();

# Postgresql Long Pending connections
SELECT pid, now() - pg_stat_activity.query_start AS duration, state, query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes' AND state = 'active';

SELECT pid, now() - pg_stat_activity.query_start AS duration, state, query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '1 minutes' AND state = 'active';

SELECT pid, now() - pg_stat_activity.query_start AS duration, pg_stat_activity.query_start AS start_time, query, state 
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '1 minutes' AND state = 'active' AND pid = 22401;

SELECT pg_cancel_backend(6260);
SELECT pg_terminate_backend(6260);

# Postgresql SSL Connection
psql "sslmode=disable hostaddr=0.0.0.0 port=5432 user=kalpesh dbname=sample_production"
psql "hostaddr=0.0.0.0 port=5432 user=kalpesh dbname=sample_production"
