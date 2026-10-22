-- ============================================================
-- 26_rollback_ddl_catalogo_movilidad.sql
-- Reverso exacto de 26_ddl_catalogo_movilidad.sql.
-- UTF-8 sin BOM, sin acentos.
--
-- NO se tocan los esquemas: bdm_datos es compartido y un
-- DROP SCHEMA ... CASCADE desde strct es el incidente DEV #256.
-- ============================================================
DROP TABLE IF EXISTS bdm_datos.catalogo_indicador_movilidad;
DROP TABLE IF EXISTS bdm_datos.catalogo_hom_ind_mov;
