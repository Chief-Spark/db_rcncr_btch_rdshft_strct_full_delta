-- ============================================================
-- 30_ddl_novedades.sql
-- SLCOPRBA-1355: estructura del proceso de NOVEDADES (legado P0035
-- Extractor Novedades), primera entrega: el dominio UBICACION.
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- Cluster consumidor: reconocerbatch / dba_rncr_batch
-- Codificacion: UTF-8 sin BOM. Sin acentos a proposito.
-- DDL idempotente (CREATE TABLE IF NOT EXISTS). Nunca GRANT ... TO PUBLIC.
-- ------------------------------------------------------------
-- POR QUE LAS DOS TABLAS DE ETAPA SON DDL EXPLICITO Y NO UN CTAS:
--   en el legado son TMP_UBICA_ETAPA_9 y TMP_UBICA_ETAPA_2, y son CONTRATO
--   PUBLICO: cinco de los otros procedimientos de Novedades las leen.
--     PRO_Novedad_Linea_Catalogo             Novedad.sql:288, 358, 433
--     PRO_Novedad_Linea_Contact              Novedad.sql:615
--     PRO_Novedad_Linea_Historial            Novedad.sql:1721
--     PRO_Novedad_Linea_PICalculados_Ctls    Novedad.sql:4808
--     PRO_Novedad_Linea_Ubi_Agregada         Novedad.sql:5131..6457 (11 puntos)
--   Un CTAS deja que el tipo lo infiera la consulta, de modo que un cambio en
--   el SELECT cambia el contrato sin avisar. Con DDL explicito, el contrato
--   esta aqui y el SP solo hace TRUNCATE + INSERT.
--
-- POR QUE PERMANENTES Y NO TEMPORALES:
--   los cinco consumidores aun no existen en Redshift. Si las tablas murieran
--   con la sesion, no habria con que engancharlos cuando se porten.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;
CREATE SCHEMA IF NOT EXISTS bdm_tempo;

-- ------------------------------------------------------------
-- bdm_tempo.stg_nov_ubica_etapa_9  (legado TMP_UBICA_ETAPA_9)
-- Salida principal del SP de Ubicacion. 42 columnas.
-- Contrato tomado de P0035_Extractor_Novedades_130.TPT:28-71 (SCHEMA P0035_8),
-- menos IN_Severidad, que la calcula la vista de staging y no se persiste.
--
-- EQUIVALENCIAS DE TIPO Teradata -> Redshift:
--   BYTEINT -> SMALLINT  (Redshift no tiene entero de un byte)
-- DIVERGENCIA DELIBERADA, la unica:
--   numero_reportes y numero_entidades son BYTEINT en el legado y aqui son
--   INTEGER. Son el resultado de un COUNT(*): un BYTEINT desborda a las 128
--   filas. Por esta ruta llegan como 0 literal (ver mas abajo), de modo que
--   el legado nunca lo paga, pero el contrato tiene que soportar el valor
--   real para cuando Ubi_Agregada lo consuma desde la etapa 2.
--
-- LAS CINCO COLUMNAS QUE EL LEGADO DEJA EN BLANCO POR ESTA RUTA:
--   reportado_desde, ultimo_reporte, fuente, numero_reportes y
--   numero_entidades salen NULL y 0 LITERALES (Novedad.sql:8358-8363).
--   Sus valores reales se calculan en la etapa 2, que esta ruta no consume:
--   la etapa 2 existe solo para alimentar a Ubi_Agregada. Se porta literal --
--   el codigo manda -- y queda elevado como divergencia funcional.
--
-- DISTKEY por cod_dw_persona_ubic (la columna id): es la llave del UPSERT a
-- mat_info_ubicacion y la de union de la etapa 2. SORTKEY igual, por el
-- mismo predicado.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_tempo.stg_nov_ubica_etapa_9 (
  cod_tipo_ident_fte              VARCHAR(20),
  tipo_identificacion             VARCHAR(30),
  numero_identificacion           BIGINT,
  id                              BIGINT,       -- cod_dw_persona_ubic
  orden                           INTEGER,      -- rpu_orden_prioridad
  indicativo                      VARCHAR(20),
  dato                            VARCHAR(201),
  estrato                         VARCHAR(10),
  tipo                            VARCHAR(30),
  zona                            VARCHAR(30),
  ciudad                          VARCHAR(30),
  departamento                    VARCHAR(30),
  longitud                        VARCHAR(40),
  latitud                         VARCHAR(40),
  reportado_desde                 INTEGER,      -- NULL literal por esta ruta
  ultimo_reporte                  INTEGER,      -- NULL literal por esta ruta
  fuente                          INTEGER,      -- NULL literal por esta ruta
  numero_reportes                 INTEGER,      -- 0 literal por esta ruta
  numero_entidades                INTEGER,      -- 0 literal por esta ruta
  barrio                          VARCHAR(100),
  localidad                       VARCHAR(100),
  codigo_postal                   VARCHAR(20),
  clase                           VARCHAR(5),
  info_basica                     INTEGER,      -- id_buro_persona
  codigo_dane                     VARCHAR(20),
  es_tipo_crr                     VARCHAR(1),
  es_tipo_res                     VARCHAR(1),
  es_tipo_ppl                     VARCHAR(1),   -- NULL literal en el legado
  es_tipo_agn                     VARCHAR(1),   -- NULL literal en el legado
  es_tipo_suc                     VARCHAR(1),   -- NULL literal en el legado
  es_tipo_est                     VARCHAR(1),   -- NULL literal en el legado
  es_tipo_cdi                     VARCHAR(1),   -- NULL literal en el legado
  es_tipo_lab                     VARCHAR(1),
  tipo_cuenta                     VARCHAR(1),
  cod_dw_ubic                     BIGINT,
  cod_dw_direccion_fisica         BIGINT,
  cod_dw_telefono                 BIGINT,
  cod_dw_direccion_electronica    BIGINT,
  ind_unificacion                 INTEGER,
  cod_dw_tipo_ubicacion_dir       INTEGER,
  cod_pin_persona                 BIGINT,
  flag_op                         VARCHAR(1)    -- I | A | E
)
DISTSTYLE KEY DISTKEY (id)
SORTKEY (id);

-- ------------------------------------------------------------
-- bdm_tempo.stg_nov_ubica_etapa_2  (legado TMP_UBICA_ETAPA_2)
-- Segunda salida del SP de Ubicacion. 15 columnas.
-- Contrato tomado de Novedad.sql:8625-8639.
-- La consume UNICAMENTE PRO_Novedad_Linea_Ubi_Agregada; dentro de Ubicacion
-- se construye y no se vuelve a leer.
--
-- DIFERENCIA DE TIPO RESPECTO A LA ETAPA 9, y es del legado:
--   fuente es aqui la DESCRIPCION (VARCHAR) y en la etapa 9 es un INTEGER que
--   ademas siempre vale NULL. No es un error de transcripcion: son dos
--   columnas distintas con el mismo nombre.
--   reportado_desde y ultimo_reporte son aqui FECHAS (MIN/MAX de
--   fecha_reporte) y en la etapa 9 son INTEGER siempre NULL.
--
-- TRAMPA DEL LEGADO QUE SE PORTA LITERAL (Novedad.sql:8635):
--   COALESCE(COALESCE(VFT.DESCRIPCION_FUENTE,'CAM'), h2.Descripcion_Hom_...)
--   El COALESCE interno nunca devuelve NULL, de modo que la homologacion de
--   fuente JAMAS se aplica y toda fuente desconocida sale como 'CAM'.
--   Se porta tal cual y queda elevado.
--
-- SEGUNDA TRAMPA, tambien literal (Novedad.sql:8354, 8374 contra 8502-8504):
--   la etapa 9 usa '' para ciudad y departamento y '-1' para el DANE; las dos
--   agregaciones usan 'SV' para los tres. La etapa 2 une por igualdad en esas
--   tres columnas, asi que donde el valor original era NULL el join falla y
--   los dos contadores quedan NULL.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_tempo.stg_nov_ubica_etapa_2 (
  tipo_identificacion             VARCHAR(30),
  numero_identificacion           BIGINT,
  info_basica                     BIGINT,       -- id_buro_persona
  cod_pin_persona                 BIGINT,
  dato                            VARCHAR(201),
  cod_dw_fuente                   INTEGER,
  id                              BIGINT,       -- cod_dw_persona_ubic
  ciudad                          VARCHAR(30),
  departamento                    VARCHAR(30),
  codigo_dane                     VARCHAR(20),
  fuente                          VARCHAR(30),
  reportado_desde                 DATE,
  ultimo_reporte                  DATE,
  numero_entidades                INTEGER,
  numero_reportes                 INTEGER
)
DISTSTYLE KEY DISTKEY (id)
SORTKEY (id);

-- ------------------------------------------------------------
-- bdm_datos.mat_info_ubicacion
-- Tabla final del producto. Misma forma que la etapa 9: el UPSERT del legado
-- (P0035_Extractor_Novedades_130.TPT:606-695) copia columna a columna.
-- Permanente y acumulativa entre corridas: el delta se aplica por id.
--
-- flag_op NO se persiste como VARCHAR sino como el codigo numerico del
-- legado (120.TPT:169-173): I -> 1, A -> 2, E -> 3.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_ubicacion (
  cod_tipo_ident_fte              VARCHAR(20),
  tipo_identificacion             VARCHAR(30),
  numero_identificacion           BIGINT,
  id                              BIGINT,
  orden                           INTEGER,
  indicativo                      VARCHAR(20),
  dato                            VARCHAR(201),
  estrato                         VARCHAR(10),
  tipo                            VARCHAR(30),
  zona                            VARCHAR(30),
  ciudad                          VARCHAR(30),
  departamento                    VARCHAR(30),
  longitud                        VARCHAR(40),
  latitud                         VARCHAR(40),
  reportado_desde                 INTEGER,
  ultimo_reporte                  INTEGER,
  fuente                          INTEGER,
  numero_reportes                 INTEGER,
  numero_entidades                INTEGER,
  barrio                          VARCHAR(100),
  localidad                       VARCHAR(100),
  codigo_postal                   VARCHAR(20),
  clase                           VARCHAR(5),
  info_basica                     INTEGER,
  codigo_dane                     VARCHAR(20),
  es_tipo_crr                     VARCHAR(1),
  es_tipo_res                     VARCHAR(1),
  es_tipo_ppl                     VARCHAR(1),
  es_tipo_agn                     VARCHAR(1),
  es_tipo_suc                     VARCHAR(1),
  es_tipo_est                     VARCHAR(1),
  es_tipo_cdi                     VARCHAR(1),
  es_tipo_lab                     VARCHAR(1),
  tipo_cuenta                     VARCHAR(1),
  cod_dw_ubic                     BIGINT,
  cod_dw_direccion_fisica         BIGINT,
  cod_dw_telefono                 BIGINT,
  cod_dw_direccion_electronica    BIGINT,
  ind_unificacion                 INTEGER,
  cod_dw_tipo_ubicacion_dir       INTEGER,
  cod_pin_persona                 BIGINT,
  flag_op                         SMALLINT,     -- 1 = I, 2 = A, 3 = E
  lote                            INTEGER,
  fecha_actualizacion             TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                      VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (id)
SORTKEY (id);
