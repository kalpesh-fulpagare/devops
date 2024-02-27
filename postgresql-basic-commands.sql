sudo -u postgres psql -d template1 -c "CREATE USER kalpesh WITH PASSWORD 'password' CREATEDB;"
sudo -u postgres psql -d template1 -c "CREATE DATABASE sample_db OWNER kalpesh;"
sudo -u postgres psql -d template1 -c "CREATE USER kalpesh CREATEDB;"
sudo -u postgres -H psql -d template1

/* =========================== Users =========================== */
/* Create User with password */
CREATE USER kalpesh WITH PASSWORD 'kalpesh1234';

/* Drop User */
DROP USER kalpesh;

/* =========================== Database =========================== */
/* Grant permission to create Database */
ALTER USER kalpesh CREATEDB;

/* Grant superuser permission to user */
ALTER USER kalpesh SUPERUSER;

/* Create Database */
CREATE DATABASE sample_db;

/* Create Database with Owner*/
CREATE DATABASE sample_db OWNER kalpesh;

/* Change Database Owner */
ALTER DATABASE sample_db OWNER TO kalpesh;

/* Rename Database */ 
ALTER DATABASE sample_db RENAME TO sample_db_new;

/* =========================== Table/Sequence =========================== */
/* Change Table Owner */
ALTER TABLE products OWNER TO kalpesh;

/* Change Sequence Owner */
ALTER SEQUENCE products_id_seq OWNER TO kalpesh;

/* Change Primary key sequence start value */ 
ALTER SEQUENCE products_id_seq1 RESTART WITH 1000000000;
SELECT last_value FROM products_id_seq1; 

/* =========================== MISC =========================== */
/* Grant privileges for a Database to User */
GRANT ALL PRIVILEGES ON DATABASE sample_db TO kalpesh;

/* Remove privileges for a Database from User */
REMOVE ALL PRIVILEGES ON DATABASE sample_db FROM kalpesh;

/* Create / Restore Custom format Dump */
pg_dump -Fc sample_db > sample_db.sql

/^ Create required user & Database on target machine & restore ^/
pg_restore -d sample_db sample_db.sql

/* Restore DB Dump */
psql -h localhost -U kalpesh -d sample_db < sample-db-2021-01-01.sql

/* Heroku Table Data as CSV */
heroku pg:psql --app APP_NAME

/* Copy data from one table to another */
INSERT INTO producst SELECT * FROM products_old WHERE id>54321 AND sold=false;

/* Copy data from table to CSV */
\copy (SELECT users.id, CONCAT(first_name, ' ', middle_name, ' ', last_name) AS full_name, username, dob, gender, address_line_1, address_line_2, province, zipcode, email, phone_number, minor, roles.name as role, avatar_url, email_frequency, sign_in_count, license_code, city, elise_points, used_points, contact_person, phone,  website, chamber_of_commerce_no, notes FROM users LEFT JOIN roles on role_id=roles.id) TO users-8feb-2016.csv CSV HEADER DELIMITER ',';

/* Readonly User Creation */
CREATE USER sample_readonly WITH PASSWORD 'sample1234';
GRANT CONNECT ON DATABASE sample_production TO sample_readonly;
\c sample_production
GRANT USAGE ON SCHEMA public TO sample_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO sample_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO sample_readonly;

/* Enable logging of SQL's */
vim /etc/postgresql/<POSTGRES_VERSION>/main/postgresql.conf
logging_collector = on
log_destination = 'stderr'
log_directory = '/var/log/postgresql'
log_filename = 'sql_%Y_%m_%d.log'
log_file_mode = 0776
log_min_duration_statement = 0
