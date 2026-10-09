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

DROP TABLE IF EXISTS bdm_stage.mock_numeros;
