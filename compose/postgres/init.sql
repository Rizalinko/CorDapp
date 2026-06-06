-- Creates one database per node so each Corda node gets an isolated schema.
-- Runs automatically when the postgres container first starts.
CREATE DATABASE cordanotary OWNER corda;
CREATE DATABASE cordanode1  OWNER corda;
CREATE DATABASE cordanode2  OWNER corda;

