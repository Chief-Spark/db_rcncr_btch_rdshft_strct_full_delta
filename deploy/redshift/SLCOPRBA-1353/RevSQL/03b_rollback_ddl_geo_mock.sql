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

-- SLCOPRBA-1355: el ciclo GEO mock se amplio a carga y reenganche, de modo
-- que el rollback arrastra tambien el "archivo" de vuelta y el interruptor
-- de S3. El DELETE lleva WHERE explicito (politica REDSHIFT:232) y toca solo
-- el parametro que 03b anadio, nunca el resto del catalogo.

-- GUARDA DE ESQUEMA, Y SI, EN UN ROLLBACK: DROP TABLE IF EXISTS
-- bdm_stage.x NO tolera que falte el ESQUEMA -- el IF EXISTS cubre la tabla,
-- no el esquema -- y en un ambiente primerizo el RLLBCK_PRECHECK muere con
-- 3F000 schema bdm_stage does not exist (job QA/DATABASE #122).
-- ESTE ARCHIVO CORRE ANTES DE 02a EN rollback.par, de modo que no puede
-- apoyarse en la guarda de aquel: Jenkins los ejecuta uno a uno y cada uno
-- tiene que sobrevivir solo. Crearlo vacio es inocuo -- el DPLY lo crea
-- igual -- y nadie lo borra nunca (DEV #422: bdm_stage es compartido).
CREATE SCHEMA IF NOT EXISTS bdm_stage;

DELETE FROM bdm_datos.geo_config_mock WHERE parametro = 's3_enabled';
DROP TABLE IF EXISTS bdm_stage.mock_geo_respuesta;

DROP TABLE IF EXISTS bdm_datos.geo_atributos_mock;
DROP TABLE IF EXISTS bdm_datos.geo_lote_control_mock;
DROP TABLE IF EXISTS bdm_datos.geo_config_mock;
