CREATE TABLE stage_users (id INT, active INT)
GO
INSERT INTO stage_users (id, active) VALUES (1, 1)
/
EXPLAIN SELECT id FROM stage_users WHERE active = 1
GO
ALTER TABLE stage_users ADD CONSTRAINT stage_users_check CHECK (active IN (0, 1))
