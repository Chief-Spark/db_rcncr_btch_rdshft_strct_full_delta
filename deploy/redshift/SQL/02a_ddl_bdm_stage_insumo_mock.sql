-- ============================================================
-- 02a_ddl_bdm_stage_insumo_mock.sql
-- Tablas base bdm_stage que alimentan v_mock_* (suite mock unif).
-- CREATE IF NOT EXISTS — no inventa datos; el seed opcional va en dt.
-- UTF-8 sin BOM. Nunca GRANT TO PUBLIC.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_stage;

CREATE TABLE IF NOT EXISTS bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic            BIGINT,
  id_buro_persona                BIGINT,
  cod_pin_persona                BIGINT,
  cod_dw_ubic                    BIGINT,
  cod_dw_direccion_fisica        BIGINT,
  cod_dw_tipo_ubicacion_dir      INTEGER,
  ind_unificacion                INTEGER,
  orden_prioridad                INTEGER,
  fecha_relacion_persona_ubicaci DATE,
  lote                           INTEGER,
  cod_tipo_ident_fte             VARCHAR(20)
)
DISTSTYLE KEY DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona, cod_dw_persona_ubic);

CREATE TABLE IF NOT EXISTS bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic       BIGINT,
  texto_ubicacion   VARCHAR(500),
  cod_dw_ciudad     INTEGER,
  latitud           DECIMAL(12,8),
  longitud          DECIMAL(12,8)
)
DISTSTYLE KEY DISTKEY (cod_dw_ubic)
SORTKEY (cod_dw_ubic);

CREATE TABLE IF NOT EXISTS bdm_stage.direccion_fisica (
  cod_dw_direccion_fisica BIGINT,
  complemento             VARCHAR(200),
  cod_dw_ubic             BIGINT,
  generada_enriquecida    INTEGER
)
DISTSTYLE KEY DISTKEY (cod_dw_direccion_fisica)
SORTKEY (cod_dw_direccion_fisica);

CREATE TABLE IF NOT EXISTS bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic BIGINT,
  id_buro_suscriptor  INTEGER,
  fecha_reporte       DATE
)
DISTSTYLE KEY DISTKEY (cod_dw_persona_ubic)
SORTKEY (cod_dw_persona_ubic);

CREATE TABLE IF NOT EXISTS bdm_stage.ciiu_persona (
  id_buro_persona         BIGINT,
  cod_act_econo_ciiu_fte  VARCHAR(20)
)
DISTSTYLE KEY DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

CREATE TABLE IF NOT EXISTS bdm_stage.tipo_ubicacion_dir (
  cod_dw_tipo_ubicacion_dir      INTEGER,
  descripcion_tipo_ubicacion_dir VARCHAR(20)
)
DISTSTYLE ALL;

CREATE TABLE IF NOT EXISTS bdm_stage.nomenclatura (
  nomenclatura      VARCHAR(100),
  nivel_complemento INTEGER
)
DISTSTYLE ALL;

CREATE TABLE IF NOT EXISTS bdm_stage.diccionario_complementos (
  id_buro_persona BIGINT,
  cod_dw_ubic     BIGINT,
  nomenclatura    VARCHAR(100),
  frecuencia      INTEGER
)
DISTSTYLE KEY DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona, cod_dw_ubic);

-- Catalogo minimo tipos RES/LAB/CRR (ids tipicos de suite mock)
DELETE FROM bdm_stage.tipo_ubicacion_dir
 WHERE cod_dw_tipo_ubicacion_dir IN (1, 2, 3);

INSERT INTO bdm_stage.tipo_ubicacion_dir (cod_dw_tipo_ubicacion_dir, descripcion_tipo_ubicacion_dir)
VALUES
  (1, 'RES'),
  (2, 'LAB'),
  (3, 'CRR');
