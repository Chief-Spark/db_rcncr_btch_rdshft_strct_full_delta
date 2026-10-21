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
  usuario_bd           VARCHAR(100),
  -- G-06 (D-ORD-12, 2026-10-21): cada corrida registra QUE VERSION DE BETAS
  -- uso. Lo escribe sp_rcn_ctl_ord_abrir leyendo bdm_datos.beta_ordenamiento, de
  -- modo que el valor sale del dato cargado y no de un literal del SP.
  version_betas        VARCHAR(40)
)
DISTSTYLE ALL
SORTKEY (corrida_id);

CREATE TABLE IF NOT EXISTS bdm_datos.ord_control_etapa (
  corrida_id           BIGINT       NOT NULL,
  lote                 INTEGER      NOT NULL,
  etapa                VARCHAR(64)  NOT NULL,   -- 64 desde 2026-10-21: los nombres de etapa de Novedades y de la R2 no cabian en 30
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
  usuario_bd           VARCHAR(100),
  -- G-06 (D-ORD-12, 2026-10-21): cada corrida registra QUE VERSION DE BETAS
  -- uso. Lo escribe sp_rcn_ctl_ord_abrir leyendo bdm_datos.beta_ordenamiento, de
  -- modo que el valor sale del dato cargado y no de un literal del SP.
  version_betas        VARCHAR(40)
)
DISTSTYLE ALL
SORTKEY (corrida_id);

CREATE TABLE IF NOT EXISTS bdm_stage.mock_ord_control_etapa (
  corrida_id           BIGINT       NOT NULL,
  lote                 INTEGER      NOT NULL,
  etapa                VARCHAR(64)  NOT NULL,   -- 64 desde 2026-10-21: los nombres de etapa de Novedades y de la R2 no cabian en 30
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


-- ============================================================
-- SLCOPRBA-1355 -- UBICACION_ATRIBUTO_HASH (Fase 3 del Ordenamiento)
--
-- QUE ES. La deteccion de cambios por hash MD5 de la Fase 3: una fila por
-- (persona, ubicacion, hash) con la huella de los atributos de la direccion.
-- Legado: PRO_ORD_CONCAT_DIRECCIONES (arma el concatena) y
-- PRO_ORD_FINAL_UBIC_DIRECCIONES (persiste). Criterios F3-04..07.
--
-- LA LLAVE DE DETECCION ES DE TRES COLUMNAS -- cod_pin_persona,
-- id_buro_persona, cod_dw_persona_ubic -- y lo dice F3-07; el hash es el
-- CUARTO campo del anti-join que decide si una combinacion es nueva, no parte
-- de la llave de la entidad.
--
-- NO LLEVA RESTRICCION DE UNICIDAD, igual que el legado, donde el
-- PRIMARY INDEX (Cod_DW_Persona_Ubic) de Teradata es NO UNIQUE. Una direccion
-- que cambia deja DOS filas: la vieja con su hash y la nueva con el suyo. Eso
-- no es un descuido del DDL, es el historial que el AS-IS produce.
--
-- DISTSTYLE KEY por cod_dw_persona_ubic: es la columna por la que se une con
-- el staging de la corrida, y la que el legado usa de PRIMARY INDEX.
-- ============================================================

CREATE TABLE IF NOT EXISTS bdm_datos.ubicacion_atributo_hash (
  cod_pin_persona      BIGINT       NOT NULL,
  id_buro_persona      BIGINT       NOT NULL,
  cod_dw_persona_ubic  BIGINT       NOT NULL,
  cod_dw_hash          CHAR(32)     NOT NULL,   -- F3-04: MD5, 32 exactos
  fecha_nov            DATE         NOT NULL,
  -- Las tres de abajo NO estan en UBICACION_ATRIBUTO_HASH del legado, que
  -- tiene cinco columnas. tipo_persona esta porque F3-03 exige que no haya
  -- ninguna nula y sin guardarla no hay donde mirarlo; lote y usuario_bd son
  -- la traza que el resto de nuestras tablas lleva.
  tipo_persona         VARCHAR(10),
  lote                 INTEGER,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (cod_dw_persona_ubic)
SORTKEY (id_buro_persona, cod_dw_persona_ubic);

-- Espejo mock. Mismas columnas, misma semantica.
CREATE TABLE IF NOT EXISTS bdm_datos.ubicacion_atributo_hash_mock (
  cod_pin_persona      BIGINT       NOT NULL,
  id_buro_persona      BIGINT       NOT NULL,
  cod_dw_persona_ubic  BIGINT       NOT NULL,
  cod_dw_hash          CHAR(32)     NOT NULL,
  fecha_nov            DATE         NOT NULL,
  tipo_persona         VARCHAR(10),
  lote                 INTEGER,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (cod_dw_persona_ubic)
SORTKEY (id_buro_persona, cod_dw_persona_ubic);


-- ============================================================
-- SLCOPRBA-1355 -- CUENTA_ATRIBUTO_HASH (Fase 2 del Ordenamiento)
--
-- Gemela de ubicacion_atributo_hash, y por el mismo motivo: F2-07 pide un MD5
-- de 32 caracteres por registro para detectar cambios entre ejecuciones.
-- Legado: PRO_ORD_CONCAT_ATRIBUTOS (arma el concatena) y
-- PRO_ORD_FINAL_CTA_ATRIBUTOS (persiste).
--
-- INSERT-ONLY, igual que la de ubicaciones y por la MISMA razon escrita: el
-- UPDATE de PRO_ORD_FINAL_CTA_ATRIBUTOS.sql:200 esta comentado con
-- "Por solicitud de Experian... no se va a necesitar". Las dos tablas de hash
-- del legado llevan la misma frase, que es lo que convierte esa desactivacion
-- en una decision de negocio y no en basura de edicion.
--
-- DISTKEY por cod_dw_cta: es el grano de la Fase 2 y el PRIMARY INDEX del
-- legado.
-- ============================================================

CREATE TABLE IF NOT EXISTS bdm_datos.cuenta_atributo_hash (
  cod_pin_persona      BIGINT       NOT NULL,
  id_buro_persona      BIGINT       NOT NULL,
  cod_dw_cta           BIGINT       NOT NULL,
  cod_dw_hash          CHAR(32)     NOT NULL,   -- F2-07: MD5, 32 exactos
  fecha_nov            DATE         NOT NULL,
  -- portafolio se guarda para que F2-05 y F2-06 tengan donde mirar: el
  -- staging que lo calcula lo borra el cleanup.
  portafolio           VARCHAR(10),
  lote                 INTEGER,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (cod_dw_cta)
SORTKEY (id_buro_persona, cod_dw_cta);

CREATE TABLE IF NOT EXISTS bdm_datos.cuenta_atributo_hash_mock (
  cod_pin_persona      BIGINT       NOT NULL,
  id_buro_persona      BIGINT       NOT NULL,
  cod_dw_cta           BIGINT       NOT NULL,
  cod_dw_hash          CHAR(32)     NOT NULL,
  fecha_nov            DATE         NOT NULL,
  portafolio           VARCHAR(10),
  lote                 INTEGER,
  usuario_bd           VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (cod_dw_cta)
SORTKEY (id_buro_persona, cod_dw_cta);
