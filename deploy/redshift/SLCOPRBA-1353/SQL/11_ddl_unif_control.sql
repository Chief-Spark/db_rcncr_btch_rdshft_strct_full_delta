-- ============================================================
-- 11_ddl_unif_control.sql
-- Tablas de control de la Unificacion (repo strct / db_rcncr_btch_rdshft_strct)
-- Cluster consumidor: reconocerbatch / dba_rncr_batch
-- DDL idempotente (CREATE TABLE IF NOT EXISTS). Objetos permanentes en bdm_datos.
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Spec: unificacion-full-delta (Task 1.1 / 1.2)
-- ============================================================

-- Schema permanente (idempotente; ya existe en el ambiente del cliente)
CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ============================================================
-- bdm_datos.unif_control (Tabla_Control_Unificacion) -- PERMANENTE
-- Cabecera por corrida: Watermark, modo aplicado, lote, fecha de proceso,
-- estado, marcas de tiempo y conteos globales.
-- Historico acumulativo: una fila por corrida, nunca se sobrescribe (Req 14.3).
-- Task 1.1 -- Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 12.5, 12.6, 14.1, 14.4
-- ------------------------------------------------------------
-- Nota Redshift (IDENTITY): la unicidad de corrida_id la garantiza la columna
-- IDENTITY(1,1); el orquestador NO asigna corrida_id manualmente. IDENTITY
-- garantiza unicidad monotonica creciente pero NO consecutividad (puede haber
-- huecos en la secuencia). Ningun consumidor debe asumir consecutividad.
-- Sin PK forzada: Redshift no fuerza constraints.
-- DISTSTYLE ALL: tabla pequena consultada por todos los SPs para leer el ultimo
-- Watermark 'completado'; replicarla en cada nodo abarata joins/lookups.
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.unif_control (
  corrida_id           BIGINT IDENTITY(1,1) NOT NULL,   -- identidad autoincremental de la corrida (Redshift IDENTITY)
  lote                 INTEGER      NOT NULL,   -- Lote_Corrida externo (Req 6)
  modo                 VARCHAR(10)  NOT NULL,   -- FULL | DELTA (modo efectivamente aplicado, Req 1.5)
  bootstrap            BOOLEAN      DEFAULT FALSE, -- TRUE si fue Bootstrap FULL forzado (Req 2.3)
  fecha_proceso        DATE,                    -- Fecha_Proceso (Req 14.1, 14.2)
  watermark_anterior   DATE,                    -- watermark de partida
  watermark_nuevo      DATE,                    -- watermark resultante (solo si completado, Req 4.3)
  estado               VARCHAR(12)  NOT NULL,   -- en proceso | completado | fallido (Req 4.2, 4.3, 4.4)
  relaciones_entrada   BIGINT,                  -- Metricas_Corrida globales (Req 14.4)
  personas_distintas   BIGINT,                  -- distinct id_buro_persona
  total_unificaciones  BIGINT,
  fecha_hora_inicio    TIMESTAMP    NOT NULL,
  fecha_hora_fin       TIMESTAMP,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id);

-- ============================================================
-- bdm_datos.unif_control_etapa (Tabla_Traza_Etapa) -- PERMANENTE
-- Detalle por etapa para observabilidad y monitoreo en vivo.
-- Ligada a la corrida por corrida_id (FK logico a unif_control.corrida_id).
-- Historico acumulativo: nunca sobrescribe filas de corridas previas (Req 13, 14.3).
-- Task 1.2 -- Requirements: 13.1, 13.2, 13.3, 13.6, 13.7, 13.10, 14.3
-- ------------------------------------------------------------
-- Nota Redshift (FK logico): corrida_id NO se declara como FOREIGN KEY forzada
-- (Redshift no fuerza constraints); la relacion con unif_control.corrida_id es
-- por convencion / logica de la aplicacion.
-- DISTSTYLE ALL: pocas filas por corrida, consultada para monitoreo en vivo
-- (Req 13.10, 13.11); replicarla en cada nodo abarata los lookups de estado.
-- SORTKEY (corrida_id, etapa): favorece la consulta "en que etapa va la corrida N".
-- Los conteos GEO pueden derivarse de bdm_datos.geo_lote_control (Req 13.7).
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.unif_control_etapa (
  corrida_id                  BIGINT       NOT NULL,   -- FK logico a unif_control.corrida_id
  lote                        INTEGER      NOT NULL,   -- Lote_Corrida (Req 13.1)
  etapa                       VARCHAR(20)  NOT NULL,   -- regla1 | regla2 | regla2_escN | geo | regla3 (Req 13.2, 13.3)
  estado                      VARCHAR(12)  NOT NULL,   -- en proceso | completado | fallido (Req 13.2)
  fecha_hora_inicio           TIMESTAMP    NOT NULL,
  fecha_hora_fin              TIMESTAMP,
  relaciones_entrada          BIGINT,                  -- Metricas_Corrida por etapa (Req 13.6)
  personas_distintas          BIGINT,                  -- distinct id_buro_persona
  unificaciones_producidas    BIGINT,
  candidatos_geo_exportados   BIGINT,                  -- solo etapa geo (Req 13.7)
  candidatos_geo_cargados     BIGINT,                  -- solo etapa geo (Req 13.7)
  usuario_bd                  VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id, etapa);

