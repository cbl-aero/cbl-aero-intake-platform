-- Extension: address_standardizer

-- DROP EXTENSION address_standardizer;

CREATE EXTENSION address_standardizer
	SCHEMA "extensions"
	VERSION 3.3.7;

-- Extension: address_standardizer_data_us

-- DROP EXTENSION address_standardizer_data_us;

CREATE EXTENSION address_standardizer_data_us
	SCHEMA "extensions"
	VERSION 3.3.7;

-- Extension: fuzzystrmatch

-- DROP EXTENSION fuzzystrmatch;

CREATE EXTENSION fuzzystrmatch
	SCHEMA "extensions"
	VERSION 1.2;

-- Extension: hstore

-- DROP EXTENSION hstore;

CREATE EXTENSION hstore
	SCHEMA "extensions"
	VERSION 1.8;

-- Extension: http

-- DROP EXTENSION http;

CREATE EXTENSION http
	SCHEMA "extensions"
	VERSION 1.6;

-- Extension: insert_username

-- DROP EXTENSION insert_username;

CREATE EXTENSION insert_username
	SCHEMA "extensions"
	VERSION 1.0;

-- Extension: pg_graphql

-- DROP EXTENSION pg_graphql;

CREATE EXTENSION pg_graphql
	SCHEMA "graphql"
	VERSION 1.5.11;

-- Extension: pg_stat_statements

-- DROP EXTENSION pg_stat_statements;

CREATE EXTENSION pg_stat_statements
	SCHEMA "extensions"
	VERSION 1.11;

-- Extension: pgcrypto

-- DROP EXTENSION pgcrypto;

CREATE EXTENSION pgcrypto
	SCHEMA "extensions"
	VERSION 1.3;

-- Extension: plpgsql

-- DROP EXTENSION plpgsql;

CREATE EXTENSION plpgsql
	SCHEMA "pg_catalog"
	VERSION 1.0;

-- Extension: postgis

-- DROP EXTENSION postgis;

CREATE EXTENSION postgis
	SCHEMA "extensions"
	VERSION 3.3.7;

-- Extension: supabase_vault

-- DROP EXTENSION supabase_vault;

CREATE EXTENSION supabase_vault
	SCHEMA "vault"
	VERSION 0.3.1;

-- Extension: uuid-ossp

-- DROP EXTENSION uuid-ossp;

CREATE EXTENSION uuid-ossp
	SCHEMA "extensions"
	VERSION 1.1;

-- Extension: vector

-- DROP EXTENSION vector;

CREATE EXTENSION vector
	SCHEMA "extensions"
	VERSION 0.8.0;