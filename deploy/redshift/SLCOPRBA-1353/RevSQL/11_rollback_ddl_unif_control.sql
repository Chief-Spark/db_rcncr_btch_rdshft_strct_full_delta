-- ============================================================
-- 11_rollback_ddl_unif_control.sql
-- Rollback: elimina las tablas de control de la Unificacion
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- Contrapartida de 11_ddl_unif_control.sql (Task 1.1 / 1.2).
-- Codificacion: UTF-8 sin BOM.
-- Spec: unificacion-full-delta (Task 1.3)
-- Requirements: 12.1, 12.4, 12.5
-- ------------------------------------------------------------
-- Orden INVERSO a la creacion (unif_control_etapa creada en 1.2, unif_control
-- en 1.1): se elimina primero la tabla de traza y luego la cabecera.
-- DROP TABLE IF EXISTS es valido en Redshift para tablas.
-- NOTA: no se elimina el schema bdm_datos porque es compartido.
-- La DDL de bdm_datos.unificacion_direccion NO cambia (fuera de este rollback).
-- ============================================================

DROP TABLE IF EXISTS bdm_datos.unif_control_etapa;
DROP TABLE IF EXISTS bdm_datos.unif_control;
