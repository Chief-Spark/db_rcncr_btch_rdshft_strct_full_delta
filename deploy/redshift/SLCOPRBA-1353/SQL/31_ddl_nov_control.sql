-- ============================================================
-- 31_ddl_nov_control.sql
-- Tablas de control de NOVEDADES (repo strct / db_rcncr_btch_rdshft_strct)
-- Cluster consumidor: reconocerbatch / dba_rncr_batch
-- DDL idempotente (CREATE TABLE IF NOT EXISTS). Objetos permanentes en bdm_datos.
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Gemelo de 11_ddl_unif_control.sql.
-- ============================================================
-- ESTO NO ES UN PORT. ES DISENO NUEVO, Y HAY QUE DECIRLO.
--
-- El control de lote del legado es REC_MTDAT.LOG_TD. Esta inoperativo, y se
-- comprueba sin lectura alternativa:
--
--   1) P0035_Extractor_Novedades_111.BTQ:64-65 ejecuta
--      DELETE FROM LOG_TD WHERE Nombre_Proceso = 'P0035_Extractor_Novedades'
--      AL INICIO de cada corrida.
--   2) El watermark que leen los nueve SPs es MAX(FECHA_HORA_FIN) de esa misma
--      tabla, filtrando por (NOMBRE_PROCESO, TABLA_ORIGEN_STAGE,
--      ESTADO_EJECUCION = 'Finalizado OK')  --  Novedad.sql:242-247.
--   3) Por tanto el watermark se autodestruye y la lectura devuelve NULL, que
--      es justo la condicion de carga FULL: Novedad.sql:8392 emite el literal
--      'I' cuando V_CARGA_FULL IS NULL. TODAS las corridas son FULL.
--   4) Y el cierre de lote tampoco ocurre: P0035_Extractor_Novedades_140.BTQ
--      declara FncUpdate_LogTD en :47-61 y NUNCA la llama (:853-858); la
--      variable CMDSQL que ese bloque ejecutaria no se asigna en el script.
--
-- CONSECUENCIA: la logica DELTA del legado es codigo latente nunca
-- ejercitado. No hay comportamiento de referencia contra el que certificar un
-- port, de modo que aqui se construye el control sobre el patron unif_control,
-- que si funciona y si esta certificado, y la divergencia queda escrita.
--
-- SEGUNDA CONSECUENCIA, sobre las tres columnas del delta: el legado deriva
-- las altas y los cambios de LOTE, LOTE_ACTUALIZACION y FECHA_MODIFICACION de
-- RELACION_PERSONA_UBICACION (Novedad.sql:7394-7401 y :7455-7462). Ninguna de
-- las tres existe en edf_views. El watermark propio las sustituye por
-- fecha_relacion_persona_ubicaci, que es la misma ventana por persona que ya
-- usa la Unificacion.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ============================================================
-- bdm_datos.nov_control -- PERMANENTE
-- Cabecera por corrida de Novedades: watermark, modo aplicado, lote, estado,
-- marcas de tiempo y conteos globales.
-- Historico acumulativo: una fila por corrida, nunca se sobrescribe.
-- ------------------------------------------------------------
-- Nota Redshift (IDENTITY): la unicidad de corrida_id la garantiza la columna
-- IDENTITY(1,1); el orquestador NO la asigna. IDENTITY garantiza unicidad
-- monotonica creciente pero NO consecutividad. Sin PK forzada: Redshift no
-- fuerza constraints.
-- DISTSTYLE ALL: tabla pequena que todos los SPs consultan para leer el ultimo
-- watermark 'completado'; replicarla en cada nodo abarata los lookups.
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.nov_control (
  corrida_id           BIGINT IDENTITY(1,1) NOT NULL,   -- identidad autoincremental de la corrida
  lote                 INTEGER      NOT NULL,   -- Lote_Corrida externo
  modo                 VARCHAR(10)  NOT NULL,   -- FULL | DELTA (modo efectivamente aplicado)
  bootstrap            BOOLEAN      DEFAULT FALSE, -- TRUE si fue Bootstrap FULL forzado
  fecha_proceso        DATE,
  watermark_anterior   DATE,                    -- watermark de partida
  watermark_nuevo      DATE,                    -- watermark resultante (solo si completado)
  estado               VARCHAR(12)  NOT NULL,   -- en proceso | completado | fallido
  relaciones_entrada   BIGINT,                  -- metricas globales de la corrida
  personas_distintas   BIGINT,                  -- distinct id_buro_persona
  filas_mat_escritas   BIGINT,                  -- filas aplicadas a las tablas MAT_*
  fecha_hora_inicio    TIMESTAMP    NOT NULL,
  fecha_hora_fin       TIMESTAMP,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id);

-- ============================================================
-- bdm_datos.nov_control_etapa -- PERMANENTE
-- Detalle por dominio de Novedades, para observabilidad.
-- Ligada a la corrida por corrida_id (FK logico a nov_control.corrida_id).
-- Historico acumulativo: nunca sobrescribe filas de corridas previas.
-- ------------------------------------------------------------
-- Nota Redshift (FK logico): corrida_id NO se declara como FOREIGN KEY
-- forzada (Redshift no fuerza constraints); la relacion es por convencion.
-- DISTSTYLE ALL: pocas filas por corrida, consultada para monitoreo en vivo.
-- SORTKEY (corrida_id, etapa): favorece "en que dominio va la corrida N".
-- ------------------------------------------------------------
-- El dominio 'ubicacion' es el unico portado en esta entrega. Los otros siete
-- se nombran aqui para que el catalogo de etapas no cambie al portarlos:
--   catalogo | info_basica | ubicacion | contact | punto_interes |
--   historial | indic_movilidad | ubi_agregada
-- 'mosaic' NO esta: queda fuera de alcance por decision legal.
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.nov_control_etapa (
  corrida_id                  BIGINT       NOT NULL,   -- FK logico a nov_control.corrida_id
  lote                        INTEGER      NOT NULL,
  etapa                       VARCHAR(64)  NOT NULL,   -- ver la lista de dominios de arriba
  estado                      VARCHAR(12)  NOT NULL,   -- en proceso | completado | fallido
  fecha_hora_inicio           TIMESTAMP    NOT NULL,
  fecha_hora_fin              TIMESTAMP,
  relaciones_entrada          BIGINT,                  -- metricas por dominio
  personas_distintas          BIGINT,                  -- distinct id_buro_persona
  filas_altas                 BIGINT,                  -- flag_op = I
  filas_cambios               BIGINT,                  -- flag_op = A
  filas_bajas                 BIGINT,                  -- flag_op = E
  usuario_bd                  VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id, etapa);
