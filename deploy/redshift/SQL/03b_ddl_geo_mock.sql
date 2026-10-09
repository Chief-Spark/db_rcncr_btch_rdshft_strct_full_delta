-- ============================================================
-- 03b_ddl_geo_mock.sql  (Reconocer / GEO MOCK - generacion de candidatos)
-- DDL de tablas de control y config del ciclo GEO para la via MOCK.
-- Objetos en bdm_datos; idempotente (CREATE TABLE IF NOT EXISTS).
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Spec: unificacion-full-delta -- certificacion con datos mock
-- ------------------------------------------------------------
-- SLCOPRBA-1354: espejo de 03_ddl_geo.sql para la via MOCK.
--
-- POR QUE TABLAS APARTE Y NO LAS REALES:
--   sp_geo_exportar_insumo descarta candidatos con
--     NOT EXISTS (... JOIN geo_lote_control lc ON ... WHERE lc.estado <> 'cargado')
--   es decir, excluye toda ubicacion ya etiquetada en un Lote que aun no esta
--   'cargado'. En DEV el Lote 1 real quedo en estado 'fallido' (UNLOAD sin rol
--   IAM asociado al cluster) y tiene etiquetadas 139.604 ubicaciones. Si la via
--   mock compartiera geo_atributos / geo_lote_control, ese Lote fallido
--   excluiria el universo entero y el mock jamas generaria un solo candidato.
--   Con tablas separadas la certificacion GEO mock es independiente y repetible.
--
-- ALCANCE: solo generacion de candidatos (exportacion). NO hay
-- geo_distancias_mock porque las distancias alimentan la Regla 3, que queda
-- fuera del alcance de la certificacion mock (no hay enriquecimiento de
-- coordenadas disponible).
--
-- COMPORTAMIENTO ESPERADO DEL UNLOAD: debe FALLAR. El rol IAM
-- arn:aws:iam::<cuenta>:role/rcncr-batch-redshift-geo no esta asociado al
-- cluster DEV. El fallo de exportacion NO es bloqueante por diseno (Req 2.10,
-- 2.11): el Lote queda 'fallido' en geo_lote_control_mock y el flujo continua
-- con R1+R2 hacia Ordenamiento. Eso es resultado esperado de la prueba, no un
-- defecto.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- bdm_datos.geo_config_mock -- PERMANENTE (config por ambiente, via mock)
-- Estructura nombre->valor. Misma DDL en los 4 ambientes.
-- DISTSTYLE ALL: catalogo pequeno replicado en cada nodo.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.geo_config_mock (
  ambiente    VARCHAR(10)   NOT NULL,   -- PROD | UAT | TEST | DEV
  parametro   VARCHAR(60)   NOT NULL,
  valor       VARCHAR(500)  NOT NULL
)
DISTSTYLE ALL
SORTKEY (ambiente, parametro);

-- ------------------------------------------------------------
-- bdm_datos.geo_lote_control_mock -- PERMANENTE (control de Lote, via mock)
-- Maquina de estados y control de reintentos.
-- Estados de negocio:  exportado | procesado por ArcGIS_Externo | cargado
-- Estados operativos:  fallido | fallido definitivo
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.geo_lote_control_mock (
  lote                 INTEGER      NOT NULL,
  estado               VARCHAR(40)  NOT NULL,  -- exportado | procesado por ArcGIS_Externo | cargado | fallido | fallido definitivo
  fase_fallo           VARCHAR(40),            -- exportacion | georreferenciacion | distancias | reenganche_r3
  conteo_esperado      INTEGER,
  conteo_cargado       INTEGER,
  intentos             SMALLINT DEFAULT 0,
  max_reintentos       SMALLINT,               -- snapshot de max_retries al crear el Lote
  ambiente             VARCHAR(10),
  ultimo_error         VARCHAR(500),
  fecha_exportacion    TIMESTAMP,
  fecha_carga          TIMESTAMP,
  fecha_actualizacion  TIMESTAMP
)
DISTSTYLE ALL
SORTKEY (lote);

-- ------------------------------------------------------------
-- bdm_datos.geo_atributos_mock -- PERMANENTE
-- Etiquetado de las Ubicacion_Candidata del mock con su Lote y estado.
-- latitud/longitud quedan NULL: en la certificacion mock no hay
-- enriquecimiento, solo generacion de candidatos.
-- DISTSTYLE KEY + DISTKEY/SORTKEY(cod_dw_ubic) por clave de negocio.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.geo_atributos_mock (
  cod_dw_ubic         BIGINT       NOT NULL,
  latitud             DECIMAL(10,6),         -- NULL: sin enriquecimiento en mock
  longitud            DECIMAL(10,6),         -- NULL: sin enriquecimiento en mock
  barrio              VARCHAR(120),
  estrato             SMALLINT,
  status_match        CHAR(1),               -- 'M' | 'U'
  estado_geo          VARCHAR(30),           -- geocodificada | no geocodificada | pendiente de geocodificacion
  lote                INTEGER,
  fecha_actualizacion DATE,
  usuario_bd          VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (cod_dw_ubic)
SORTKEY (cod_dw_ubic);

-- ------------------------------------------------------------
-- Seed idempotente de bdm_datos.geo_config_mock para los 4 ambientes.
-- Valores identicos a geo_config EXCEPTO s3_prefix, que apunta a
-- 'reconocer_input_mock/' para que una exportacion de certificacion nunca
-- escriba en el prefijo que consume ArcGIS_Externo en produccion.
-- Idempotente: WHERE NOT EXISTS evita duplicar filas al re-desplegar.
--
-- Cuentas AWS por ambiente:
--   PROD 696708350333 | UAT 453645298399 | TEST 667397050561 | DEV 647096294147
-- ------------------------------------------------------------
INSERT INTO bdm_datos.geo_config_mock (ambiente, parametro, valor)
SELECT v.ambiente, v.parametro, v.valor
FROM (
  -- PROD (cuenta 696708350333)
  SELECT 'PROD' AS ambiente, 'max_records'           AS parametro, '850000'                                   AS valor UNION ALL
  SELECT 'PROD', 'maxfilesize_mb',       '128'                                                                          UNION ALL
  SELECT 'PROD', 's3_prefix',            'reconocer_input_mock/'                                                        UNION ALL
  SELECT 'PROD', 'delimiter',            '|'                                                                            UNION ALL
  SELECT 'PROD', 'compression',          'GZIP'                                                                         UNION ALL
  SELECT 'PROD', 'null_string',          '\N'                                                                           UNION ALL
  SELECT 'PROD', 'bucket',               'rcncr-batch-geo-prod-696708350333'                                            UNION ALL
  SELECT 'PROD', 'iam_role',             'arn:aws:iam::696708350333:role/rcncr-batch-redshift-geo'                      UNION ALL
  SELECT 'PROD', 'arcgis_account_id',    '696708350333'                                                                 UNION ALL
  SELECT 'PROD', 'max_retries',          '3'                                                                            UNION ALL
  SELECT 'PROD', 'retry_backoff_seconds','300'                                                                          UNION ALL

  -- UAT (cuenta 453645298399)
  SELECT 'UAT',  'max_records',          '850000'                                                                       UNION ALL
  SELECT 'UAT',  'maxfilesize_mb',       '128'                                                                          UNION ALL
  SELECT 'UAT',  's3_prefix',            'reconocer_input_mock/'                                                        UNION ALL
  SELECT 'UAT',  'delimiter',            '|'                                                                            UNION ALL
  SELECT 'UAT',  'compression',          'GZIP'                                                                         UNION ALL
  SELECT 'UAT',  'null_string',          '\N'                                                                           UNION ALL
  SELECT 'UAT',  'bucket',               'rcncr-batch-geo-uat-453645298399'                                             UNION ALL
  SELECT 'UAT',  'iam_role',             'arn:aws:iam::453645298399:role/rcncr-batch-redshift-geo'                      UNION ALL
  SELECT 'UAT',  'arcgis_account_id',    '453645298399'                                                                 UNION ALL
  SELECT 'UAT',  'max_retries',          '3'                                                                            UNION ALL
  SELECT 'UAT',  'retry_backoff_seconds','300'                                                                          UNION ALL

  -- TEST (cuenta 667397050561)
  SELECT 'TEST', 'max_records',          '850000'                                                                       UNION ALL
  SELECT 'TEST', 'maxfilesize_mb',       '128'                                                                          UNION ALL
  SELECT 'TEST', 's3_prefix',            'reconocer_input_mock/'                                                        UNION ALL
  SELECT 'TEST', 'delimiter',            '|'                                                                            UNION ALL
  SELECT 'TEST', 'compression',          'GZIP'                                                                         UNION ALL
  SELECT 'TEST', 'null_string',          '\N'                                                                           UNION ALL
  SELECT 'TEST', 'bucket',               'rcncr-batch-geo-test-667397050561'                                            UNION ALL
  SELECT 'TEST', 'iam_role',             'arn:aws:iam::667397050561:role/rcncr-batch-redshift-geo'                      UNION ALL
  SELECT 'TEST', 'arcgis_account_id',    '667397050561'                                                                 UNION ALL
  SELECT 'TEST', 'max_retries',          '3'                                                                            UNION ALL
  SELECT 'TEST', 'retry_backoff_seconds','300'                                                                          UNION ALL

  -- DEV (cuenta 647096294147)
  SELECT 'DEV',  'max_records',          '850000'                                                                       UNION ALL
  SELECT 'DEV',  'maxfilesize_mb',       '128'                                                                          UNION ALL
  SELECT 'DEV',  's3_prefix',            'reconocer_input_mock/'                                                        UNION ALL
  SELECT 'DEV',  'delimiter',            '|'                                                                            UNION ALL
  SELECT 'DEV',  'compression',          'GZIP'                                                                         UNION ALL
  SELECT 'DEV',  'null_string',          '\N'                                                                           UNION ALL
  SELECT 'DEV',  'bucket',               'rcncr-batch-geo-dev-647096294147'                                             UNION ALL
  SELECT 'DEV',  'iam_role',             'arn:aws:iam::647096294147:role/rcncr-batch-redshift-geo'                      UNION ALL
  SELECT 'DEV',  'arcgis_account_id',    '647096294147'                                                                 UNION ALL
  SELECT 'DEV',  'max_retries',          '3'                                                                            UNION ALL
  SELECT 'DEV',  'retry_backoff_seconds','300'
) v
WHERE NOT EXISTS (SELECT 1 FROM bdm_datos.geo_config_mock LIMIT 1);
