-- ============================================================
-- 05_ddl_ordenamiento_mock.sql
-- Tablas lab bdm_stage.mock_ord_* (suite QA Modo B)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_stage;

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
