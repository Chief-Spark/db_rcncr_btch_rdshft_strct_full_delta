-- ============================================================
-- 31b_ddl_nov_control_mock.sql
-- ESPEJO MOCK de 31_ddl_nov_control.sql. Generado por sustitucion: las dos
-- tablas reciben el sufijo _mock y NADA MAS cambia.
-- Mismo patron que 11b_ddl_unif_control_mock.sql.
-- El diff contra el real debe salir vacio modulo ese sufijo, cabecera aparte.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ============================================================
-- bdm_datos.nov_control_mock -- PERMANENTE
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
CREATE TABLE IF NOT EXISTS bdm_datos.nov_control_mock (
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
-- bdm_datos.nov_control_etapa_mock -- PERMANENTE
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
CREATE TABLE IF NOT EXISTS bdm_datos.nov_control_etapa_mock (
  corrida_id                  BIGINT       NOT NULL,   -- FK logico a nov_control.corrida_id
  lote                        INTEGER      NOT NULL,
  etapa                       VARCHAR(20)  NOT NULL,   -- ver la lista de dominios de arriba
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
