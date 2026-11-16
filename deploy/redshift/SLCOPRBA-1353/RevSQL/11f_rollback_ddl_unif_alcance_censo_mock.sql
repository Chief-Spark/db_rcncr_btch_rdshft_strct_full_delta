-- ============================================================
-- 11f_rollback_ddl_unif_alcance_censo_mock.sql
-- Rollback: elimina el espejo mock del censo de ventana
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- Contrapartida de 11f_ddl_unif_alcance_censo_mock.sql.
-- Codificacion: UTF-8 sin BOM.
-- ------------------------------------------------------------
-- NOTA: no se elimina el schema bdm_datos porque es compartido.
-- ============================================================

DROP TABLE IF EXISTS bdm_datos.unif_alcance_censo_mock;
