SHOW FULL TABLES;
SET work_mem = 64;
RESET search_path;
USE analytics;
EXPLAIN SELECT id FROM users;
