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
-- ALCANCE (AMPLIADO, SLCOPRBA-1355): el ciclo GEO mock completo --
-- exportacion, carga de georreferenciacion y reenganche de la Regla 3 -- sin
-- tocar S3. Antes solo cubria la generacion de candidatos. Sigue sin haber
-- geo_distancias_mock: las distancias no entran en ninguno de los cinco
-- criterios GEO.
--
-- EL VIAJE A S3 SE SALTA, NO SE SIMULA MAL. Dos piezas lo sustituyen:
--   1. el parametro s3_enabled, que en la via mock vale '0' y hace que
--      sp_geo_exportar_insumo_mock OMITA el UNLOAD y deje el Lote en
--      'exportado' en vez de 'fallido';
--   2. bdm_stage.mock_geo_respuesta, que ES el archivo de vuelta de
--      ArcGIS_Externo, columna por columna, y que sp_geo_cargar_
--      georreferenciacion_mock lee con un INSERT en lugar del COPY.
--
-- LO QUE ESTO NO CERTIFICA, y hay que decirlo: que el UNLOAD escriba de
-- verdad en S3 y que el COPY lo lea. Son dos sentencias cuyo riesgo es de
-- permisos (el rol arn:aws:iam::<cuenta>:role/rcncr-batch-redshift-geo no
-- esta asociado al cluster DEV), no de logica. Todo lo demas -- gate de
-- estado, gate de conteo, conciliacion de tipos, rechazos, los tres UPDATE a
-- geo_atributos y la maquina de estados del Lote -- es el mismo SQL.
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

-- ------------------------------------------------------------
-- bdm_stage.mock_geo_respuesta -- PERMANENTE (SLCOPRBA-1355)
-- ES EL ARCHIVO DE VUELTA de ArcGIS_Externo, columna por columna: las mismas
-- 32 columnas VARCHAR crudas de Salida_Georreferenciacion que el COPY real
-- deposita en bdm_tempo.stg_arcgis_georeferenciacion. Que tenga la MISMA
-- forma es lo que permite que sp_geo_cargar_georreferenciacion_mock difiera
-- del real en una sola sentencia: el COPY pasa a ser un INSERT ... SELECT
-- desde aqui, y todo el SQL de abajo (conciliacion de tipos, rechazos,
-- UPDATEs) es identico.
--
-- Del contrato de 32 columnas (Salida_Geo.pdf, 2026-10-20) el cargador lee:
--   col01 Cod_DW_Ubic | col02 Lote | col05 Descripcion_Proceso (GEOCODE)
--   col12 Latitud     | col13 Longitud | col26 Status (M/U)
-- Las demas existen para que la forma coincida; van NULL. Hasta el
-- 2026-10-20 el simulador y los cargadores usaban Status en col03 y
-- latitud/longitud en col05/col06, que no es el contrato (D-EDF-05).
--
-- col02 es la llave de filtrado: el cargador toma del "archivo" solo las
-- filas cuyo Lote coincide con el que esta procesando, igual que el contrato
-- 1:1 por Lote del camino real.
--
-- DISTSTYLE EVEN como el staging real, que tampoco distribuye por clave.
-- ------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS bdm_stage;

CREATE TABLE IF NOT EXISTS bdm_stage.mock_geo_respuesta (
  col01  VARCHAR(500),   -- Cod_DW_Ubic
  col02  VARCHAR(500),   -- Lote
  col03  VARCHAR(500),   -- Direccion
  col04  VARCHAR(500),   -- Cod_Dane_Ciudad
  col05  VARCHAR(500),   -- Descripcion_Proceso (GEOCODE)
  col06  VARCHAR(500),   -- Zona
  col07  VARCHAR(500),
  col08  VARCHAR(500),
  col09  VARCHAR(500),
  col10  VARCHAR(500),
  col11  VARCHAR(500),
  col12  VARCHAR(500),   -- Latitud
  col13  VARCHAR(500),   -- Longitud
  col14  VARCHAR(500),
  col15  VARCHAR(500),
  col16  VARCHAR(500),
  col17  VARCHAR(500),
  col18  VARCHAR(500),
  col19  VARCHAR(500),
  col20  VARCHAR(500),
  col21  VARCHAR(500),
  col22  VARCHAR(500),
  col23  VARCHAR(500),
  col24  VARCHAR(500),
  col25  VARCHAR(500),
  col26  VARCHAR(500),   -- Status (M | U)
  col27  VARCHAR(500),
  col28  VARCHAR(500),
  col29  VARCHAR(500),
  col30  VARCHAR(500),
  col31  VARCHAR(500),
  col32  VARCHAR(500)
)
DISTSTYLE EVEN;

-- ------------------------------------------------------------
-- s3_enabled: el interruptor que separa la via mock de S3.
--
-- VA EN UN INSERT APARTE A PROPOSITO. El seed de arriba se protege con
-- WHERE NOT EXISTS (... FROM geo_config_mock LIMIT 1), que mira si la tabla
-- tiene ALGUNA fila; sobre un ambiente donde ya se desplego, ese guarda es
-- cierto y un parametro nuevo anadido alli NO se insertaria jamas. El guarda
-- de aqui es por parametro, que es el que corresponde cuando se agrega uno.
--
-- Vale '0' en los cuatro ambientes: la via mock nunca escribe en S3. El
-- camino REAL no mira este parametro, de modo que su comportamiento no
-- cambia.
-- ------------------------------------------------------------
INSERT INTO bdm_datos.geo_config_mock (ambiente, parametro, valor)
SELECT v.ambiente, v.parametro, v.valor
FROM (
  SELECT 'PROD' AS ambiente, 's3_enabled' AS parametro, '0' AS valor UNION ALL
  SELECT 'UAT',  's3_enabled', '0'                                   UNION ALL
  SELECT 'TEST', 's3_enabled', '0'                                   UNION ALL
  SELECT 'DEV',  's3_enabled', '0'
) v
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_datos.geo_config_mock c
  WHERE c.parametro = 's3_enabled'
);

-- 2026-10-20 (GEO no bloqueante): los dos parametros nuevos de geo_config,
-- con el mismo guarda por parametro. Ver 03_ddl_geo.sql.
INSERT INTO bdm_datos.geo_config_mock (ambiente, parametro, valor)
SELECT a.ambiente, p.parametro, p.valor
FROM (
  SELECT 'PROD' AS ambiente UNION ALL
  SELECT 'UAT'              UNION ALL
  SELECT 'TEST'             UNION ALL
  SELECT 'DEV'
) a
CROSS JOIN (
  SELECT 's3_output_prefix' AS parametro, 'reconocer_output/' AS valor UNION ALL
  SELECT 'dias_espera_arcgis',            '7'
) p
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_datos.geo_config_mock c
  WHERE c.ambiente = a.ambiente
    AND c.parametro = p.parametro
);

-- ============================================================
-- LAS DISTANCIAS ENTRAN A LA VIA MOCK (2026-10-21, d7)
--
-- Esta seccion desmiente la nota de la cabecera, que decia "sigue sin haber
-- geo_distancias_mock: las distancias no entran en ninguno de los cinco
-- criterios GEO". Sigue siendo cierto que no entran en los cinco -- no se
-- toca ninguno --, pero SI entran en la tabla dominio d7
-- (mat_info_punto_interes), y sin ellas esa tabla saldria VACIA en la
-- bateria. Una tabla vacia no prueba nada: es la leccion de "un DELTA en
-- cero no prueba que no haya cambios".
--
-- Dos piezas, las mismas que para georreferenciacion:
--   1. bdm_datos.geo_distancias_mock, espejo de geo_distancias;
--   2. bdm_stage.mock_geo_distancias, que ES el archivo de vuelta de
--      ArcGIS_Externo con las 12 columnas crudas del contrato
--      Salida_Distancias, y que sp_geo_cargar_distancias_mock lee con un
--      INSERT en lugar del COPY.
-- ============================================================

-- ------------------------------------------------------------
-- bdm_datos.geo_distancias_mock -- PERMANENTE
-- Espejo de bdm_datos.geo_distancias. Mismas columnas y mismas claves; la
-- justificacion de tipos, de la clave 1:N y del rango de la distancia vive
-- en 03_ddl_geo.sql y no se duplica aqui.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.geo_distancias_mock (
  cod_dw_ubic               BIGINT       NOT NULL,
  lote                      INTEGER      NOT NULL,
  tipo_punto_interes        VARCHAR(60)  NOT NULL,
  cod_punto_interes_host    VARCHAR(60)  NOT NULL,
  latitud                   DECIMAL(38,8),
  longitud                  DECIMAL(38,8),
  latitud_punto_interes     DECIMAL(38,8),
  longitud_punto_interes    DECIMAL(38,8),
  distancia_punto_interes   INTEGER,
  nombre_punto_interes      VARCHAR(200),
  fecha_actualizacion       DATE,
  usuario_bd                VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (cod_dw_ubic)
SORTKEY (cod_dw_ubic, lote);

-- ------------------------------------------------------------
-- bdm_stage.mock_geo_distancias -- PERMANENTE
-- EL ARCHIVO DE VUELTA de las distancias, columna por columna del contrato
-- Salida_Distancias (Salida_Geo.pdf, seccion 3). Doce VARCHAR(500) crudos,
-- igual que mock_geo_respuesta para georreferenciacion: el cargador valida y
-- castea, y si aqui se declararan los tipos finales el mock se saltaria justo
-- la parte que hay que certificar.
--   col01 Cod_DW_Ubic   col07 Tipo_Punto_Interes
--   col02 Lote          col08 Nombre_Punto_Interes
--   col03 Direccion     col09 Latitud_Punto_Interes
--   col04 Latitud       col10 Longitud_Punto_Interes
--   col05 Longitud      col11 Distancia_Punto_Interes
--   col06 Descripcion   col12 Cod_Punto_Interes_Host
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_stage.mock_geo_distancias (
  col01  VARCHAR(500),   -- Cod_DW_Ubic
  col02  VARCHAR(500),   -- Lote
  col03  VARCHAR(500),   -- Direccion
  col04  VARCHAR(500),   -- Latitud
  col05  VARCHAR(500),   -- Longitud
  col06  VARCHAR(500),   -- Descripcion_Proceso (DISTANCIAS)
  col07  VARCHAR(500),   -- Tipo_Punto_Interes
  col08  VARCHAR(500),   -- Nombre_Punto_Interes
  col09  VARCHAR(500),   -- Latitud_Punto_Interes
  col10  VARCHAR(500),   -- Longitud_Punto_Interes
  col11  VARCHAR(500),   -- Distancia_Punto_Interes
  col12  VARCHAR(500)    -- Cod_Punto_Interes_Host
)
DISTSTYLE EVEN;
