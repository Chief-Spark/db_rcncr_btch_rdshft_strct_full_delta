-- ============================================================
-- 12_ddl_ord_control.sql
-- Tablas de control del Ordenamiento (FULL/DELTA + observabilidad)
-- Cluster: dba_rncr_batch. UTF-8 sin BOM. Nunca GRANT TO PUBLIC.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

CREATE TABLE IF NOT EXISTS bdm_datos.ord_control (
  corrida_id           BIGINT IDENTITY(1,1) NOT NULL,
  lote                 INTEGER      NOT NULL,
  modo                 VARCHAR(10)  NOT NULL,
  bootstrap            BOOLEAN      DEFAULT FALSE,
  fecha_proceso        DATE,
  watermark_anterior   DATE,
  watermark_nuevo      DATE,
  estado               VARCHAR(12)  NOT NULL,
  personas_entrada     BIGINT,
  contactos_entrada    BIGINT,
  scores_generados     BIGINT,
  fecha_hora_inicio    TIMESTAMP    NOT NULL,
  fecha_hora_fin       TIMESTAMP,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id);

CREATE TABLE IF NOT EXISTS bdm_datos.ord_control_etapa (
  corrida_id           BIGINT       NOT NULL,
  lote                 INTEGER      NOT NULL,
  etapa                VARCHAR(30)  NOT NULL,
  estado               VARCHAR(12)  NOT NULL,
  fecha_hora_inicio    TIMESTAMP    NOT NULL,
  fecha_hora_fin       TIMESTAMP,
  filas_entrada        BIGINT,
  filas_salida         BIGINT,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id, etapa);

CREATE SCHEMA IF NOT EXISTS bdm_stage;

CREATE TABLE IF NOT EXISTS bdm_stage.mock_ord_control (
  corrida_id           BIGINT IDENTITY(1,1) NOT NULL,
  lote                 INTEGER      NOT NULL,
  modo                 VARCHAR(10)  NOT NULL,
  bootstrap            BOOLEAN      DEFAULT FALSE,
  fecha_proceso        DATE,
  watermark_anterior   DATE,
  watermark_nuevo      DATE,
  estado               VARCHAR(12)  NOT NULL,
  personas_entrada     BIGINT,
  contactos_entrada    BIGINT,
  scores_generados     BIGINT,
  fecha_hora_inicio    TIMESTAMP    NOT NULL,
  fecha_hora_fin       TIMESTAMP,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id);

CREATE TABLE IF NOT EXISTS bdm_stage.mock_ord_control_etapa (
  corrida_id           BIGINT       NOT NULL,
  lote                 INTEGER      NOT NULL,
  etapa                VARCHAR(30)  NOT NULL,
  estado               VARCHAR(12)  NOT NULL,
  fecha_hora_inicio    TIMESTAMP    NOT NULL,
  fecha_hora_fin       TIMESTAMP,
  filas_entrada        BIGINT,
  filas_salida         BIGINT,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id, etapa);
