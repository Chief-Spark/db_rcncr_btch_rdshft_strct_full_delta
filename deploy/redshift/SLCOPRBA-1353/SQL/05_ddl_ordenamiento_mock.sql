-- ============================================================
-- 05_ddl_ordenamiento_mock.sql
-- Tablas lab bdm_stage.mock_ord_* (suite QA Modo B)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_stage;

CREATE TABLE IF NOT EXISTS bdm_stage.mock_ord_escenario (
  id_buro_persona   BIGINT       NOT NULL,
  cod_escenario     VARCHAR(32)  NOT NULL,
  criterio_ca       VARCHAR(16)  NOT NULL,
  descripcion       VARCHAR(256),
  es_html_ejemplo   SMALLINT     DEFAULT 1
);

CREATE TABLE IF NOT EXISTS bdm_stage.mock_ord_rpu (
  id_buro_persona      BIGINT   NOT NULL,
  cod_pin_persona      BIGINT,
  cod_dw_persona_ubic  BIGINT   NOT NULL,
  ind_unificacion      INTEGER,
  etiqueta             VARCHAR(64)
);

CREATE TABLE IF NOT EXISTS bdm_stage.mock_ord_score (
  id_buro_persona      BIGINT         NOT NULL,
  cod_dw_persona_ubic  BIGINT         NOT NULL,
  cod_pin_persona      BIGINT,
  canal                VARCHAR(10)    NOT NULL,
  score                DECIMAL(18,4)  NOT NULL,
  lugar                INTEGER        NOT NULL,
  nota                 VARCHAR(128)
);

CREATE TABLE IF NOT EXISTS bdm_stage.mock_ord_prioridad (
  id_buro_persona      BIGINT   NOT NULL,
  cod_dw_persona_ubic  BIGINT   NOT NULL,
  orden_prioridad      INTEGER  NOT NULL
);

CREATE TABLE IF NOT EXISTS bdm_stage.mock_ord_ca_result (
  criterio_ca   VARCHAR(16)  NOT NULL,
  estado        VARCHAR(16)  NOT NULL,
  detalle       VARCHAR(512),
  fecha_check   TIMESTAMP    DEFAULT GETDATE()
);
