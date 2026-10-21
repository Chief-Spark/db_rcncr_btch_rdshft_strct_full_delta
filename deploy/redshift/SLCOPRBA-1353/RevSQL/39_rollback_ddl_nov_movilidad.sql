-- ============================================================
-- 39_rollback_ddl_nov_movilidad.sql
-- Reverso exacto de 39_ddl_nov_movilidad.sql.
-- UTF-8 sin BOM, sin acentos.
--
-- NO se tocan los esquemas: bdm_datos es compartido y un
-- DROP SCHEMA ... CASCADE desde strct es el incidente DEV #256.
-- ============================================================
DROP TABLE IF EXISTS bdm_datos.mat_info_movilidad;
DROP TABLE IF EXISTS bdm_datos.nov_movilidad_foto;
