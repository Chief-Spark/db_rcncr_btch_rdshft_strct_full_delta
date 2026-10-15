-- ============================================================
-- 11b_rollback_ddl_unif_control_mock.sql
-- Rollback: elimina las tablas de control de la Unificacion MOCK
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- Contrapartida de 11b_ddl_unif_control_mock.sql.
-- Codificacion: UTF-8 sin BOM.
-- ------------------------------------------------------------
-- Orden INVERSO a la creacion: primero la tabla de traza por etapa y luego la
-- cabecera de corrida.
-- DROP TABLE IF EXISTS es valido en Redshift (directriz 5 del pipeline).
-- NOTA: no se elimina el schema bdm_datos porque es compartido; un
-- DROP SCHEMA ... CASCADE desde strct arrasa los SP de pgm (incidente
-- SLCOPRBA-1355 / DEV #256).
-- ============================================================

DROP TABLE IF EXISTS bdm_datos.unif_control_etapa_mock;
DROP TABLE IF EXISTS bdm_datos.unif_control_mock;
