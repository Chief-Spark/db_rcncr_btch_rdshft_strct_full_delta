-- ============================================================
-- 11b_ddl_unif_control_mock.sql
-- Tablas de control de la Unificacion MOCK (repo strct / db_rcncr_btch_rdshft_strct)
-- Cluster consumidor: reconocerbatch / dba_rncr_batch
-- DDL idempotente (CREATE TABLE IF NOT EXISTS). Objetos permanentes en bdm_datos.
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Spec: unificacion-full-delta -- certificacion con datos mock
-- ------------------------------------------------------------
-- SLCOPRBA-1354: espejo de 11_ddl_unif_control.sql para la via MOCK.
--
-- POR QUE TABLAS APARTE Y NO LAS REALES:
--   El Watermark efectivo se deriva de
--     SELECT MAX(watermark_nuevo) FROM unif_control WHERE estado = 'completado'
--   que es una lectura GLOBAL: no distingue corridas mock de corridas reales.
--   Si el ciclo mock escribiera en bdm_datos.unif_control, una corrida de
--   certificacion con fechas sembradas moveria el Watermark de las corridas
--   reales y la siguiente DELTA real procesaria la ventana equivocada.
--   Con tablas separadas, mock y real tienen watermarks independientes y las
--   baterias de prueba se pueden repetir sin contaminar el historico real.
--
-- ETAPAS EN MOCK: regla1 | regla2 | regla2_escN | geo
--   NO existe la etapa 'regla3': la Regla 3 depende de coordenadas
--   (geo_atributos.latitud/longitud) y en la certificacion mock no hay
--   enriquecimiento GEO, por lo que queda fuera de alcance por diseno.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ============================================================
-- bdm_datos.unif_control_mock -- PERMANENTE
-- Cabecera por corrida mock. Mismas columnas y semantica que unif_control.
-- Historico acumulativo: una fila por corrida, nunca se sobrescribe.
-- IDENTITY(1,1) garantiza unicidad monotonica creciente, NO consecutividad.
-- DISTSTYLE ALL: tabla pequena leida por el orquestador mock en cada corrida.
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.unif_control_mock (
  corrida_id           BIGINT IDENTITY(1,1) NOT NULL,   -- identidad autoincremental de la corrida
  lote                 INTEGER      NOT NULL,   -- Lote_Corrida externo
  modo                 VARCHAR(10)  NOT NULL,   -- FULL | DELTA (modo efectivamente aplicado)
  bootstrap            BOOLEAN      DEFAULT FALSE, -- TRUE si fue Bootstrap FULL forzado
  fecha_proceso        DATE,                    -- Fecha_Proceso
  watermark_anterior   DATE,                    -- watermark de partida
  watermark_nuevo      DATE,                    -- watermark resultante (solo si completado)
  estado               VARCHAR(12)  NOT NULL,   -- en proceso | completado | fallido
  relaciones_entrada   BIGINT,                  -- Metricas_Corrida globales
  personas_distintas   BIGINT,                  -- distinct id_buro_persona
  total_unificaciones  BIGINT,
  fecha_hora_inicio    TIMESTAMP    NOT NULL,
  fecha_hora_fin       TIMESTAMP,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id);

-- ============================================================
-- bdm_datos.unif_control_etapa_mock -- PERMANENTE
-- Detalle por etapa de la corrida mock. FK logico a unif_control_mock.corrida_id
-- (Redshift no fuerza constraints; la relacion es por convencion).
-- DISTSTYLE ALL: pocas filas por corrida, consultada para monitoreo.
-- SORTKEY (corrida_id, etapa): favorece "en que etapa va la corrida N".
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.unif_control_etapa_mock (
  corrida_id                  BIGINT       NOT NULL,   -- FK logico a unif_control_mock.corrida_id
  lote                        INTEGER      NOT NULL,   -- Lote_Corrida
  etapa                       VARCHAR(20)  NOT NULL,   -- regla1 | regla2 | regla2_escN | geo
  estado                      VARCHAR(12)  NOT NULL,   -- en proceso | completado | fallido
  fecha_hora_inicio           TIMESTAMP    NOT NULL,
  fecha_hora_fin              TIMESTAMP,
  relaciones_entrada          BIGINT,                  -- Metricas_Corrida por etapa
  personas_distintas          BIGINT,                  -- distinct id_buro_persona
  unificaciones_producidas    BIGINT,
  candidatos_geo_exportados   BIGINT,                  -- solo etapa geo
  candidatos_geo_cargados     BIGINT,                  -- solo etapa geo
  usuario_bd                  VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id, etapa);
