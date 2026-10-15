-- ============================================================
-- 03b_rollback_ddl_geo_mock.sql
-- Rollback: elimina los objetos GEO de la via MOCK.
-- Contrapartida de 03b_ddl_geo_mock.sql, en orden inverso a la creacion.
-- Codificacion: UTF-8 sin BOM.
-- ------------------------------------------------------------
-- No hay DROP FUNCTION: 03b no crea funciones (las SQL UDF de Redshift no
-- admiten SELECT ... FROM, error 0A000; los SP leen la config con SELECT INTO).
-- DROP TABLE IF EXISTS es valido en Redshift (directriz 5 del pipeline).
-- ============================================================

DROP TABLE IF EXISTS bdm_datos.geo_atributos_mock;
DROP TABLE IF EXISTS bdm_datos.geo_lote_control_mock;
DROP TABLE IF EXISTS bdm_datos.geo_config_mock;
