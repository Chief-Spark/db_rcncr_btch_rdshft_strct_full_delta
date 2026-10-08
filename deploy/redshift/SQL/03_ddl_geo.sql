-- ============================================================
-- 03_ddl_geo.sql  (Reconocer / Enriquecimiento GEO - Regla 3)
-- DDL de tablas permanentes y de control del ciclo GEO + config.
-- Objetos en bdm_datos; idempotente (CREATE TABLE IF NOT EXISTS /
-- CREATE TABLE IF NOT EXISTS). UTF-8 sin BOM. Nunca GRANT TO PUBLIC.
-- Ref: .kiro/specs/geo-enriquecimiento-regla3/design.md (Data Models)
-- ============================================================

-- ------------------------------------------------------------
-- bdm_datos.geo_config (Tabla_Config) - PERMANENTE (config por ambiente)
-- Estructura nombre->valor, reemplaza SSM (Req 8.1, 8.2, 8.3).
-- Misma DDL en los 4 ambientes; valores distintos por ambiente.
-- DISTSTYLE ALL: catalogo pequeno replicado en cada nodo para joins baratos.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.geo_config (
  ambiente    VARCHAR(10)   NOT NULL,   -- PROD | UAT | TEST | DEV
  parametro   VARCHAR(60)   NOT NULL,
  valor       VARCHAR(500)  NOT NULL
)
DISTSTYLE ALL
SORTKEY (ambiente, parametro);

-- ------------------------------------------------------------
-- NOTA Redshift: NO se crea FUNCTION geo_get_config.
-- Las SQL UDFs de Redshift no admiten SELECT ... FROM (error 0A000).
-- Los SPs (_pgm) leen bdm_datos.geo_config con SELECT ... INTO.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- bdm_datos.geo_lote_control  -- PERMANENTE (control de Lote)
-- Maquina de estados y control de reintentos (Req 7.4, 13.1, 13.2, 13.4).
-- Estados de negocio:  exportado | procesado por ArcGIS_Externo | cargado
-- Estados operativos:  fallido | fallido definitivo
-- DISTSTYLE ALL: tabla pequena (una fila por Lote) consultada por todos
-- los SPs; se replica en cada nodo para joins baratos. Estado unico por
-- Lote satisface Req 7.4.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.geo_lote_control (
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
-- bdm_datos.geo_atributos (Tabla_Atributos_Geo) - PERMANENTE
-- Fuente de coordenadas para la Regla 3, en reemplazo del NULL
-- del datashare. Acumulativa entre dias (Req 11.1, 11.2).
-- Clave 1:1 idempotente del UPDATE de georreferenciacion: cod_dw_ubic.
-- latitud/longitud NULL si la ubicacion aun no fue enriquecida (Req 11.6).
-- DISTSTYLE KEY + DISTKEY/SORTKEY(cod_dw_ubic) por clave de negocio.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.geo_atributos (
  cod_dw_ubic         BIGINT       NOT NULL,
  latitud             DECIMAL(10,6),         -- NULL si no enriquecida (Req 11.6)
  longitud            DECIMAL(10,6),         -- NULL si no enriquecida (Req 11.6)
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
-- bdm_datos.geo_distancias (Tabla_Distancias_Geo) - PERMANENTE
-- Distancias a puntos de interes (POI), relacion 1:N por ubicacion,
-- delta por Lote (Req 4, 11.5). Acumulativa entre dias.
-- Clave logica 1:N: (cod_dw_ubic, tipo_punto_interes, cod_punto_interes_host)
-- (Req 4.2). distancia_punto_interes en metros, rango [0, 2147483647] (Req 4.6).
-- El SORTKEY (cod_dw_ubic, lote) favorece el DELETE ... WHERE lote = ?
-- del reemplazo atomico del delta (Req 4.4, 4.5, 7.2).
-- DISTSTYLE KEY + DISTKEY(cod_dw_ubic) por clave de negocio.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.geo_distancias (
  cod_dw_ubic               BIGINT       NOT NULL,
  lote                      INTEGER      NOT NULL,
  tipo_punto_interes        VARCHAR(60)  NOT NULL,
  cod_punto_interes_host    VARCHAR(60)  NOT NULL,
  latitud                   DECIMAL(38,8),
  longitud                  DECIMAL(38,8),
  latitud_punto_interes     DECIMAL(38,8),
  longitud_punto_interes    DECIMAL(38,8),
  distancia_punto_interes   INTEGER,               -- metros [0, 2147483647] (Req 4.6)
  fecha_actualizacion       DATE,
  usuario_bd                VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (cod_dw_ubic)
SORTKEY (cod_dw_ubic, lote);

-- ------------------------------------------------------------
-- Seed idempotente de bdm_datos.geo_config para los 4 ambientes.
-- Estructura nombre->valor; una fila por (ambiente, parametro).
-- Mismo artefacto versionado: el mismo deploy.par sirve en los 4
-- ambientes y el filtro por 'ambiente' se aplica en tiempo de consulta,
-- por lo que el mismo binario opera en cualquier cuenta sin cambios
-- (Req 8.1, 8.2, 8.4, 9.4). Idempotente: WHERE NOT EXISTS evita
-- duplicar filas al re-desplegar.
--
-- Cuentas AWS por ambiente (Req 8.4):
--   PROD 696708350333 | UAT 453645298399 | TEST 667397050561 | DEV 647096294147
--
-- Valores no secretos por ambiente (bucket / iam_role / arcgis_account_id):
-- placeholders con convencion de nombre estandar; el bucket y el rol IAM
-- son publicos por convencion y ajustables por ambiente sin tocar codigo.
-- arcgis_account_id identifica la cuenta cross-account de ArcGIS_Externo a
-- la que se otorga s3:PutObject restringido a reconocer_output/ (Req 9.4).
-- ------------------------------------------------------------
INSERT INTO bdm_datos.geo_config (ambiente, parametro, valor)
SELECT v.ambiente, v.parametro, v.valor
FROM (
  -- PROD (cuenta 696708350333)
  SELECT 'PROD' AS ambiente, 'max_records'           AS parametro, '850000'                                   AS valor UNION ALL
  SELECT 'PROD', 'maxfilesize_mb',       '128'                                                                          UNION ALL
  SELECT 'PROD', 's3_prefix',            'reconocer_input/'                                                             UNION ALL
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
  SELECT 'UAT',  's3_prefix',            'reconocer_input/'                                                             UNION ALL
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
  SELECT 'TEST', 's3_prefix',            'reconocer_input/'                                                             UNION ALL
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
  SELECT 'DEV',  's3_prefix',            'reconocer_input/'                                                             UNION ALL
  SELECT 'DEV',  'delimiter',            '|'                                                                            UNION ALL
  SELECT 'DEV',  'compression',          'GZIP'                                                                         UNION ALL
  SELECT 'DEV',  'null_string',          '\N'                                                                           UNION ALL
  SELECT 'DEV',  'bucket',               'rcncr-batch-geo-dev-647096294147'                                             UNION ALL
  SELECT 'DEV',  'iam_role',             'arn:aws:iam::647096294147:role/rcncr-batch-redshift-geo'                      UNION ALL
  SELECT 'DEV',  'arcgis_account_id',    '647096294147'                                                                 UNION ALL
  SELECT 'DEV',  'max_retries',          '3'                                                                            UNION ALL
  SELECT 'DEV',  'retry_backoff_seconds','300'
) v
WHERE NOT EXISTS (SELECT 1 FROM bdm_datos.geo_config LIMIT 1);

