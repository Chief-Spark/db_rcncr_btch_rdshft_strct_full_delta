-- Rollback 02_carga_betas_ritm5226589.sql
-- Revierte la carga de coeficientes. Idempotente: no-op si la tabla no existe
-- (primer deploy / RLLBCK_PRECHECK limpio). El DROP de DDL lo cubre
-- 01_rollback_ddl_ordenamiento.sql (DROP TABLE IF EXISTS beta_ordenamiento).
-- Evita TRUNCATE sobre relacion inexistente (42P01) que marcaba REDSHIFT:112.
SELECT 1;
