-- ============================================================
-- 02b_vistas_insumo_mock.sql
-- Insumo MOCK para SPs sp_unificacion_mock_*
-- Fuente: bdm_stage (seed / suite TC) — NO lee edf_views / DS real
-- Los SPs reales siguen en 02_vistas_insumo_edf_views.sql (v_xpm_*)
-- ============================================================

DROP VIEW IF EXISTS bdm_tempo.v_mock_contacto_canal;
DROP VIEW IF EXISTS bdm_tempo.v_mock_contacto_direccion;
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
  departamento,
  municipio,
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

-- ============================================================
-- SLCOPRBA-1355: espejos mock de las dos vistas base que consume el
-- Ordenamiento (sp_ordenamiento_preparar_insumos_*). Exponen EXACTAMENTE los
-- mismos nombres de columna que v_xpm_contacto_direccion y v_xpm_contacto_canal
-- para que el preparar mock materialice las mismas tablas de staging y los SP
-- de scoring / consolidacion REALES corran sobre datos mock sin modificacion.
-- Las columnas que el stage mock no almacena se exponen como NULL casteado, de
-- modo que el SELECT cd.* de stg_contacto_direccion_rpu conserve la forma.
-- ============================================================

CREATE OR REPLACE VIEW bdm_tempo.v_mock_contacto_direccion AS
SELECT
  CAST(rpu.cod_pin_persona AS VARCHAR(50))   AS pin,
  CAST(NULL AS BIGINT)                       AS relationalizelastupdate,
  rpu.cod_dw_ubic,
  rpu.cod_dw_persona_ubic,
  rpu.cod_dw_direccion_fisica,
  rpu.id_buro_persona,
  rpu.cod_pin_persona,
  rpu.cod_dw_tipo_ubicacion_dir,
  ubi.texto_ubicacion,
  ubi.texto_ubicacion                        AS texto_ubicacion_normalizado,
  ubi.texto_ubicacion                        AS texto_ubicacion_original,
  CAST(NULL AS DECIMAL(5,4))                 AS score_estandarizacion,
  ubi.cod_dw_ciudad,
  ubi.departamento,
  ubi.municipio,
  CAST(NULL AS VARCHAR(50))                  AS tipo_ubicacion,
  df.complemento,
  CAST(NULL AS VARCHAR(50))                  AS tipo_via_principal,
  CAST(NULL AS VARCHAR(100))                 AS via_principal,
  CAST(NULL AS VARCHAR(100))                 AS via_generadora,
  CAST(NULL AS VARCHAR(50))                  AS numero_puerta,
  rpu.fecha_relacion_persona_ubicaci,
  rpu.fecha_relacion_persona_ubicaci         AS fecha_primera_relacion,
  ubi.latitud,
  ubi.longitud,
  rpu.cod_tipo_ident_fte,
  rpu.lote
FROM bdm_stage.relacion_persona_ubicacion rpu
JOIN bdm_stage.ubicacion_estandarizada ubi
  ON rpu.cod_dw_ubic = ubi.cod_dw_ubic
LEFT JOIN bdm_stage.direccion_fisica df
  ON rpu.cod_dw_direccion_fisica = df.cod_dw_direccion_fisica
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_mock_contacto_canal AS
SELECT
  cod_dw_persona_ubic,
  id_buro_persona,
  cod_pin_persona,
  contact_type,
  valor_contacto,
  texto_ubicacion_vinculo,
  cod_dane_ciudad,
  fecha_contacto,
  id_buro_suscriptor
FROM bdm_stage.contacto_canal
WITH NO SCHEMA BINDING;
