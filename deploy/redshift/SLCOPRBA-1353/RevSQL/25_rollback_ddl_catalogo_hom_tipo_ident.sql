-- ============================================================
-- 25_rollback_ddl_catalogo_hom_tipo_ident.sql
-- Reverso exacto de 25_ddl_catalogo_hom_tipo_ident.sql.
-- UTF-8 sin BOM, sin acentos.
--
-- NO se tocan los esquemas: bdm_datos es compartido y un
-- DROP SCHEMA ... CASCADE desde strct es el incidente DEV #256.
-- ============================================================
DROP TABLE IF EXISTS bdm_datos.catalogo_hom_tipo_ident;
