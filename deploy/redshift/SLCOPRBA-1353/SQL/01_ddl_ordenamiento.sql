-- ============================================================
-- 01_ddl_ordenamiento.sql — Reconocer DEV / datashare edf_views
-- id_buro_persona BIGINT (FNV_HASH real)
-- ============================================================

CREATE TABLE IF NOT EXISTS bdm_datos.beta_ordenamiento (
  canal              VARCHAR(10)    ENCODE ZSTD,
  cod_caracteristica VARCHAR(20)    ENCODE ZSTD,
  valor_beta         DECIMAL(18,8)  ENCODE AZ64
)
DISTSTYLE ALL;

CREATE TABLE IF NOT EXISTS bdm_datos.insumo_telefono (
  cod_dw_persona_ubic        BIGINT       ENCODE AZ64,
  cod_pin_persona            BIGINT       ENCODE AZ64,
  id_buro_persona            BIGINT       ENCODE AZ64,
  direccion_fisica           VARCHAR(200) ENCODE ZSTD,
  cod_dane_ciudad            INTEGER      ENCODE AZ64,
  descripcion_gestion        VARCHAR(50)  ENCODE ZSTD,
  id_buro_suscriptor         INTEGER      ENCODE AZ64,
  fecha_reporte              DATE         ENCODE AZ64,
  meses_reporte              INTEGER      ENCODE AZ64,
  coincidencia_geo           INTEGER      ENCODE AZ64,
  sector_financiero          INTEGER      ENCODE AZ64,
  tipo_cuenta                VARCHAR(20)  ENCODE ZSTD
)
DISTSTYLE KEY DISTKEY(id_buro_persona)
SORTKEY(id_buro_persona, cod_pin_persona);

CREATE TABLE IF NOT EXISTS bdm_datos.insumo_celular (
  cod_dw_persona_ubic        BIGINT       ENCODE AZ64,
  cod_pin_persona            BIGINT       ENCODE AZ64,
  id_buro_persona            BIGINT       ENCODE AZ64,
  celular                    VARCHAR(20)  ENCODE ZSTD,
  texto_ubicacion            VARCHAR(200) ENCODE ZSTD,
  id_buro_suscriptor         INTEGER      ENCODE AZ64,
  fecha_reporte              DATE         ENCODE AZ64,
  meses_reporte              INTEGER      ENCODE AZ64,
  operador                   VARCHAR(10)  ENCODE ZSTD,
  sector_financiero          INTEGER      ENCODE AZ64,
  tipo_cuenta                VARCHAR(20)  ENCODE ZSTD
)
DISTSTYLE KEY DISTKEY(id_buro_persona)
SORTKEY(id_buro_persona, cod_pin_persona);

CREATE TABLE IF NOT EXISTS bdm_datos.insumo_email (
  cod_dw_persona_ubic        BIGINT       ENCODE AZ64,
  cod_pin_persona            BIGINT       ENCODE AZ64,
  id_buro_persona            BIGINT       ENCODE AZ64,
  email                      VARCHAR(200) ENCODE ZSTD,
  dominio                    VARCHAR(100) ENCODE ZSTD,
  id_buro_suscriptor         INTEGER      ENCODE AZ64,
  fecha_reporte              DATE         ENCODE AZ64,
  meses_reporte              INTEGER      ENCODE AZ64,
  sector_financiero          INTEGER      ENCODE AZ64,
  tipo_cuenta                VARCHAR(20)  ENCODE ZSTD
)
DISTSTYLE KEY DISTKEY(id_buro_persona)
SORTKEY(id_buro_persona, cod_pin_persona);

CREATE TABLE IF NOT EXISTS bdm_datos.insumo_direccion (
  cod_dw_persona_ubic        BIGINT       ENCODE AZ64,
  cod_pin_persona            BIGINT       ENCODE AZ64,
  id_buro_persona            BIGINT       ENCODE AZ64,
  direccion_fisica           VARCHAR(200) ENCODE ZSTD,
  complemento                VARCHAR(100) ENCODE ZSTD,
  tipo_ubicacion             VARCHAR(10)  ENCODE ZSTD,
  cod_dane_ciudad            INTEGER      ENCODE AZ64,
  id_buro_suscriptor         INTEGER      ENCODE AZ64,
  fecha_reporte              DATE         ENCODE AZ64,
  meses_reporte              INTEGER      ENCODE AZ64,
  sector_financiero          INTEGER      ENCODE AZ64,
  conteo_direcciones         INTEGER      ENCODE AZ64
)
DISTSTYLE KEY DISTKEY(id_buro_persona)
SORTKEY(id_buro_persona, cod_pin_persona);

CREATE TABLE IF NOT EXISTS bdm_datos.score_ordenamiento (
  cod_dw_persona_ubic  BIGINT         ENCODE AZ64,
  cod_pin_persona      BIGINT         ENCODE AZ64,
  id_buro_persona      BIGINT         ENCODE AZ64,
  canal                VARCHAR(10)    ENCODE ZSTD,
  score                DECIMAL(18,4)  ENCODE AZ64,
  lugar                INTEGER        ENCODE AZ64
)
DISTSTYLE KEY DISTKEY(id_buro_persona)
SORTKEY(id_buro_persona, canal, lugar);

CREATE TABLE IF NOT EXISTS bdm_datos.relacion_persona_ubicacion (
  cod_dw_persona_ubic              BIGINT   ENCODE AZ64,
  cod_pin_persona                  BIGINT   ENCODE AZ64,
  id_buro_persona                  BIGINT   ENCODE AZ64,
  cod_dw_ubic                      BIGINT   ENCODE AZ64,
  orden_prioridad                  INTEGER  ENCODE AZ64,
  fecha_relacion_persona_ubicaci   DATE     ENCODE AZ64,
  ind_unificacion                  INTEGER  ENCODE AZ64
)
DISTSTYLE KEY DISTKEY(id_buro_persona)
SORTKEY(id_buro_persona, cod_dw_persona_ubic);
