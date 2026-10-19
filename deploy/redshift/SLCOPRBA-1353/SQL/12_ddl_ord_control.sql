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


-- ============================================================
-- SLCOPRBA-1355 -- CENSO DE ALCANCE (Fase 1 del Ordenamiento)
--
-- POR QUE EXISTE. Los ocho criterios F1-01..08 preguntan por el universo que
-- la corrida decidio (re)ordenar: cuantas personas entraron, por que rama,
-- si hay duplicados, si una persona fuera de ventana se quedo fuera y si el
-- staging se limpio. Ese universo vive en bdm_tempo.stg_ord_personas_alcance,
-- que sp_ordenamiento_drop_staging_edf BORRA al final de cada corrida: cuando
-- el evaluador corre ya no existe. Sin esta tabla los ocho criterios no se
-- pueden afirmar ni negar con dato.
--
-- UNA FILA POR CORRIDA, no una por rama. Es mas facil de leer en el tablero y
-- deja que las ramas sin senal se distingan de las que midieron cero: NULL
-- significa "nuestro modelo no tiene como detectar este cambio", 0 significa
-- "lo busque y no habia ninguno". Esa distincion ES la evidencia de F1-08.
--
-- LAS CUATRO COLUMNAS EN NULL NO SON UN DESCUIDO. El legado detecta seis
-- tipos de cambio (PRO_ORD_MATERIALIZA_REC lee V_UBICACION_ORIGINAL,
-- V_BLOQUEO, V_UNIFICACION_DIRECCION, V_UBICACION_ESTANDARIZADA,
-- V_LOG_UBIC_ESTANDARIZADA y V_RELACION_PERSONA_UBICACION;
-- PRO_ORD_MATERIALIZA_BTT lee V_CUENTA y V_COMPORTAMIENTO_CUENTA). Nuestro
-- alcance cubre DOS: la ventana por fecha_relacion_persona_ubicaci y la
-- unificacion por lote/fecha. Las otras cuatro no tienen senal de delta en
-- nuestro modelo -- bdm_stage.ubicacion_estandarizada no tiene fecha ni lote,
-- 'bloqueado' es una bandera sin fecha, y no hay tabla de cuentas -- de modo
-- que no es que no se hayan buscado: es que no se pueden buscar.
--
-- DISTSTYLE ALL: una fila por corrida de la bateria, cuatro corridas por
-- pasada. Cabe entera en cada nodo.
-- ============================================================

CREATE TABLE IF NOT EXISTS bdm_datos.ord_alcance_censo (
  corrida_id           BIGINT       NOT NULL,
  lote                 INTEGER      NOT NULL,
  modo                 VARCHAR(10)  NOT NULL,
  watermark_usado      DATE,
  watermark_origen     VARCHAR(20),   -- BOOTSTRAP | CONTROL | PARAMETRO
  alcance_filas        BIGINT,
  alcance_personas     BIGINT,        -- DISTINCT. F1-03 exige filas = personas
  por_ubicacion        BIGINT,        -- rama de fecha_relacion_persona_ubicaci
  por_unificacion      BIGINT,        -- rama de unificacion_direccion
  por_estandarizacion  BIGINT,        -- sin senal de delta: NULL
  por_bloqueo          BIGINT,        -- sin senal de delta: NULL
  por_cuenta           BIGINT,        -- sin tabla de cuentas: NULL
  por_comportamiento   BIGINT,        -- sin tabla de cuentas: NULL
  fuera_ventana_total  BIGINT,        -- sembradas fuera de la ventana (ARQ 96)
  fuera_ventana_dentro BIGINT,        -- de esas, cuantas entraron. F1-04: 0
  stg_residuales       INTEGER,       -- F1-05: tiene que quedar en 0
  fecha_hora           TIMESTAMP    NOT NULL,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id);

-- Espejo mock. Mismas columnas, misma semantica.
CREATE TABLE IF NOT EXISTS bdm_stage.mock_ord_alcance_censo (
  corrida_id           BIGINT       NOT NULL,
  lote                 INTEGER      NOT NULL,
  modo                 VARCHAR(10)  NOT NULL,
  watermark_usado      DATE,
  watermark_origen     VARCHAR(20),
  alcance_filas        BIGINT,
  alcance_personas     BIGINT,
  por_ubicacion        BIGINT,
  por_unificacion      BIGINT,
  por_estandarizacion  BIGINT,
  por_bloqueo          BIGINT,
  por_cuenta           BIGINT,
  por_comportamiento   BIGINT,
  fuera_ventana_total  BIGINT,
  fuera_ventana_dentro BIGINT,
  stg_residuales       INTEGER,
  fecha_hora           TIMESTAMP    NOT NULL,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id);
