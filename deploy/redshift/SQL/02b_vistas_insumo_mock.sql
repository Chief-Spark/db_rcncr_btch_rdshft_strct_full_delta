-- ============================================================
-- 02b_vistas_insumo_mock.sql
-- Insumo MOCK para SPs sp_unificacion_mock_*
-- Fuente: bdm_stage (seed / suite TC) — NO lee edf_views / DS real
-- Los SPs reales siguen en 02_vistas_insumo_edf_views.sql (v_xpm_*)
-- ============================================================

DROP VIEW IF EXISTS bdm_tempo.v_mock_ciiu_persona;
DROP VIEW IF EXISTS bdm_tempo.v_mock_reporte_relacion_persona_ubica;
DROP VIEW IF EXISTS bdm_tempo.v_mock_direccion_fisica;
DROP VIEW IF EXISTS bdm_tempo.v_mock_ubicacion_estandarizada;
DROP VIEW IF EXISTS bdm_tempo.v_mock_relacion_persona_ubicacion;

CREATE OR REPLACE VIEW bdm_tempo.v_mock_relacion_persona_ubicacion AS
SELECT
  cod_dw_persona_ubic,
  id_buro_persona,
  cod_pin_persona,
  cod_dw_ubic,
  cod_dw_direccion_fisica,
  cod_dw_tipo_ubicacion_dir,
  ind_unificacion,
  orden_prioridad,
  fecha_relacion_persona_ubicaci,
  lote,
  cod_tipo_ident_fte,
  CAST(0 AS SMALLINT) AS bloqueado
FROM bdm_stage.relacion_persona_ubicacion
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_mock_ubicacion_estandarizada AS
SELECT
  cod_dw_ubic,
  texto_ubicacion,
  texto_ubicacion AS texto_ubicacion_normalizado,
  texto_ubicacion AS texto_ubicacion_original,
  CAST(NULL AS DECIMAL(5,4)) AS score_estandarizacion,
  cod_dw_ciudad,
  cod_dw_ciudad AS cod_dw_municipio,
  CAST(NULL AS VARCHAR(100)) AS departamento,
  CAST(NULL AS VARCHAR(100)) AS municipio,
  CAST(NULL AS VARCHAR(50)) AS tipo_ubicacion,
  CAST(NULL AS INTEGER) AS cod_dw_tipo_ubicacion,
  latitud,
  longitud
FROM bdm_stage.ubicacion_estandarizada
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_mock_direccion_fisica AS
SELECT
  cod_dw_direccion_fisica,
  complemento,
  CAST(NULL AS VARCHAR(50)) AS tipo_via_principal,
  CAST(NULL AS VARCHAR(100)) AS via_principal,
  CAST(NULL AS VARCHAR(100)) AS via_generadora,
  CAST(NULL AS VARCHAR(50)) AS numero_puerta,
  cod_dw_ubic,
  COALESCE(generada_enriquecida, 0) AS generada_enriquecida
FROM bdm_stage.direccion_fisica
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_mock_reporte_relacion_persona_ubica AS
SELECT
  cod_dw_persona_ubic,
  id_buro_suscriptor,
  fecha_reporte
FROM bdm_stage.reporte_relacion_persona_ubica
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_mock_ciiu_persona AS
SELECT
  id_buro_persona,
  cod_act_econo_ciiu_fte
FROM bdm_stage.ciiu_persona
WITH NO SCHEMA BINDING;
