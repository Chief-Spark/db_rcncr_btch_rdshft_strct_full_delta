-- ============================================================
-- 06_rollback_vistas_mock_post_unificacion.sql
-- Rollback: elimina la vista RPU post-unificacion de la via MOCK.
-- Contrapartida de 06_vistas_mock_post_unificacion.sql.
-- Codificacion: UTF-8 sin BOM.
-- ------------------------------------------------------------
-- DROP VIEW IF EXISTS es valido en Redshift (directriz 5 del pipeline).
-- NOTA: no se elimina el schema bdm_tempo porque lo comparten las vistas
-- v_xpm_* (reales) y v_mock_* (mock).
-- ============================================================

DROP VIEW IF EXISTS bdm_tempo.v_mock_rpu_post_unificacion;
