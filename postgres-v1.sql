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

# Postgresql Long Pending connections
SELECT pid, now() - pg_stat_activity.query_start AS duration, state, query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes' AND state = 'active';

SELECT pid, query, now() - pg_stat_activity.query_start AS duration, state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes' AND pid = 22401;

SELECT pg_cancel_backend(6260);
