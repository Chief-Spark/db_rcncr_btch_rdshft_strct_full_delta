-- ============================================================
-- 02c_rollback_ddl_mock_numeros.sql
-- Rollback: elimina la tabla auxiliar de numeros para semillas mock.
-- Contrapartida de 02c_ddl_mock_numeros.sql.
-- Codificacion: UTF-8 sin BOM.
-- ------------------------------------------------------------
-- DROP TABLE IF EXISTS es valido en Redshift (directriz 5 del pipeline).
-- NOTA: no se elimina el schema bdm_stage porque lo comparten las semillas
-- mock de Unificacion (02a) y de Ordenamiento (05).
-- ============================================================

-- GUARDA DE ESQUEMA, Y SI, EN UN ROLLBACK. 'DROP TABLE IF EXISTS
-- bdm_stage.x' NO tolera que falte el ESQUEMA: el IF EXISTS cubre la tabla,
-- no el esquema, y en un ambiente limpio el RLLBCK_PRECHECK muere con
-- 3F000 schema "bdm_stage" does not exist -- job QA/DATABASE #122. Crearlo
-- vacio es inocuo: el DPLY lo crea igual, y el reverso del 00 lo borra al
-- final cuando ya no queda nada dentro.
CREATE SCHEMA IF NOT EXISTS bdm_stage;

DROP TABLE IF EXISTS bdm_stage.mock_numeros;
