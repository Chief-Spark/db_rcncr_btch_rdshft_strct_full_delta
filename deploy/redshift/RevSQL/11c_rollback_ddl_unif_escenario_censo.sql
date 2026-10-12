-- ============================================================
-- 11c_rollback_ddl_unif_escenario_censo.sql
-- Rollback: elimina el censo de escenarios de la Regla 2
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- Contrapartida de 11c_ddl_unif_escenario_censo.sql.
-- Codificacion: UTF-8 sin BOM.
-- ------------------------------------------------------------
-- NOTA: no se elimina el schema bdm_datos porque es compartido.
-- ============================================================

DROP TABLE IF EXISTS bdm_datos.unif_escenario_censo;
