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

-- SLCOPRBA-1354: se anaden municipio y departamento. Los necesitan dos
-- consumidores: el Insumo_GEO mock (columnas MUNICIPIO / DEPARTAMENTO del
-- UNLOAD, Req 2.3) y la vista v_mock_contacto_direccion, espejo de
-- v_xpm_contacto_direccion, que las expone para el Ordenamiento mock.
-- DROP + CREATE porque CREATE TABLE IF NOT EXISTS no anade columnas a una tabla
-- ya existente y Redshift no admite ALTER TABLE ADD COLUMN IF NOT EXISTS. Es
-- una tabla de semillas mock: no hay dato productivo que perder.
DROP TABLE IF EXISTS bdm_stage.ubicacion_estandarizada;
CREATE TABLE IF NOT EXISTS bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic       BIGINT,
  texto_ubicacion   VARCHAR(500),
  cod_dw_ciudad     INTEGER,
  municipio         VARCHAR(100),
  departamento      VARCHAR(100),
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

-- SLCOPRBA-1355: contactos de canal TEL / CEL / EMA para el Ordenamiento mock.
-- Espejo de la fuente de bdm_tempo.v_xpm_contacto_canal. Sin esta tabla el
-- Ordenamiento mock solo podria puntuar el canal DIR y los criterios de
-- aceptacion que exigen scores en TEL/CEL/EMA no tendrian como cumplirse.
-- contact_type sigue la codificacion del datashare: '4','5','8' = telefono fijo,
-- '9' = celular; el resto se interpreta como correo en el insumo EMA.
CREATE TABLE IF NOT EXISTS bdm_stage.contacto_canal (
  cod_dw_persona_ubic     BIGINT,
  id_buro_persona         BIGINT,
  cod_pin_persona         BIGINT,
  contact_type            VARCHAR(10),
  valor_contacto          VARCHAR(200),
  texto_ubicacion_vinculo VARCHAR(500),
  cod_dane_ciudad         INTEGER,
  fecha_contacto          DATE,
  id_buro_suscriptor      INTEGER
)
DISTSTYLE KEY DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona, contact_type);

-- Catalogo minimo tipos RES/LAB/CRR (ids tipicos de suite mock)
DELETE FROM bdm_stage.tipo_ubicacion_dir
 WHERE cod_dw_tipo_ubicacion_dir IN (1, 2, 3);

INSERT INTO bdm_stage.tipo_ubicacion_dir (cod_dw_tipo_ubicacion_dir, descripcion_tipo_ubicacion_dir)
VALUES
  (1, 'RES'),
  (2, 'LAB'),
  (3, 'CRR');
