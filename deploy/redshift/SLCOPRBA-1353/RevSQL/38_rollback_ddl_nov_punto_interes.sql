-- ============================================================
-- 38_rollback_ddl_nov_punto_interes.sql
-- Reverso exacto de 38_ddl_nov_punto_interes.sql.
-- UTF-8 sin BOM, sin acentos.
--
-- NO se tocan los esquemas: bdm_datos es compartido y un
-- DROP SCHEMA ... CASCADE desde strct es el incidente DEV #256.
-- ============================================================
DROP TABLE IF EXISTS bdm_datos.mat_info_punto_interes;
