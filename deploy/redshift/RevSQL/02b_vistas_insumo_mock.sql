-- Rollback 02b: vistas insumo MOCK (bdm_stage)
-- Revierte 02b_vistas_insumo_mock.sql
DROP VIEW IF EXISTS bdm_tempo.v_mock_contacto_canal;
DROP VIEW IF EXISTS bdm_tempo.v_mock_contacto_direccion;
DROP VIEW IF EXISTS bdm_tempo.v_mock_ciiu_persona;
DROP VIEW IF EXISTS bdm_tempo.v_mock_reporte_relacion_persona_ubica;
DROP VIEW IF EXISTS bdm_tempo.v_mock_direccion_fisica;
DROP VIEW IF EXISTS bdm_tempo.v_mock_ubicacion_estandarizada;
DROP VIEW IF EXISTS bdm_tempo.v_mock_relacion_persona_ubicacion;
