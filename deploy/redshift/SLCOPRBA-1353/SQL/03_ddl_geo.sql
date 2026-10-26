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
-- Estados operativos:  fallido | fallido definitivo | vencido
-- 2026-10-20 (GEO no bloqueante): 'vencido' es un Lote que siguio en
-- 'exportado' mas de dias_espera_arcgis dias sin respuesta de ArcGIS; sus
-- candidatos vuelven a exportarse. Los 'fallido' tambien (antes quedaban
-- excluidos para siempre).
-- DISTSTYLE ALL: tabla pequena (una fila por Lote) consultada por todos
-- los SPs; se replica en cada nodo para joins baratos. Estado unico por
-- Lote satisface Req 7.4.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.geo_lote_control (
  lote                 INTEGER      NOT NULL,
  -- corrida_id (2026-10-21, observabilidad F3): ata el Lote GEO a la corrida
  -- de Unificacion que lo creo. Sin el, un Lote fallido no se puede cruzar
  -- con la traza de la corrida que lo produjo.
  corrida_id           BIGINT,
  estado               VARCHAR(40)  NOT NULL,  -- exportado | procesado por ArcGIS_Externo | cargado | fallido | fallido definitivo | vencido
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
  -- 2026-10-21 (d7): el NOMBRE del punto de interes, col08 del contrato
  -- Salida_Distancias. Llegaba y se tiraba -- sp_geo_cargar_distancias.sql
  -- lo decia en redondo: "no se guarda: geo_distancias no tiene columna; va
  -- con Novedades d7" --, y es la columna NOMBRE de
  -- MAT_INFO_PUNTO_INTERES (Novedad.sql:4794, PDIG.NOMBRE).
  --   ANCHO DEL CONTRATO DE SALIDA: VARCHAR(200), como IN_NOMBRE del SCHEMA
  --   P0035_13 (130.TPT:149). El crudo llega en VARCHAR(500) y se trunca al
  --   cargar, que es lo que haria la tabla final de todos modos.
  --   En un ambiente que ya tenga la tabla, la anade
  --   sp_rcn_ctl_obs_migrar: CREATE TABLE IF NOT EXISTS no altera.
  nombre_punto_interes      VARCHAR(200),
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
  SELECT 'PROD', 'bucket',               'prod-696708350333-rcncr-ws5-geo'                                            UNION ALL
  SELECT 'PROD', 'iam_role',             'arn:aws:iam::696708350333:role/BURoleFor-prod-696708350333-rcncr-ws5-redshift-geo'                      UNION ALL
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
  SELECT 'UAT',  'bucket',               'uat-453645298399-rcncr-ws5-geo'                                             UNION ALL
  SELECT 'UAT',  'iam_role',             'arn:aws:iam::453645298399:role/BURoleFor-uat-453645298399-rcncr-ws5-redshift-geo'                      UNION ALL
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
  SELECT 'TEST', 'bucket',               'test-667397050561-rcncr-ws5-geo'                                            UNION ALL
  SELECT 'TEST', 'iam_role',             'arn:aws:iam::667397050561:role/BURoleFor-test-667397050561-rcncr-ws5-redshift-geo'                      UNION ALL
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
  SELECT 'DEV',  'bucket',               'dev-647096294147-rcncr-ws5-geo'                                             UNION ALL
  SELECT 'DEV',  'iam_role',             'arn:aws:iam::647096294147:role/BURoleFor-dev-647096294147-rcncr-ws5-redshift-geo'                      UNION ALL
  SELECT 'DEV',  'arcgis_account_id',    '647096294147'                                                                 UNION ALL
  SELECT 'DEV',  'max_retries',          '3'                                                                            UNION ALL
  SELECT 'DEV',  'retry_backoff_seconds','300'
) v
WHERE NOT EXISTS (SELECT 1 FROM bdm_datos.geo_config LIMIT 1);

-- ------------------------------------------------------------
-- RECONCILIACION DE bucket / iam_role (SLCOPRBA-1355, 2026-10-27).
--
-- POR QUE HACE FALTA, Y NO BASTA CON CAMBIAR EL INSERT DE ARRIBA: ese INSERT
-- lleva WHERE NOT EXISTS (... LIMIT 1), de modo que siembra SOLO si la tabla
-- esta vacia. En un ambiente que ya la tiene poblada -- DEV hoy -- cambiar el
-- literal del INSERT no cambia nada: el valor viejo sobrevive para siempre.
-- Es el mismo patron que ya se pago con CREATE TABLE IF NOT EXISTS y el ancho
-- de mat_info_basica: funciona en limpio y falla donde ya hay datos.
--
-- Los nombres pasan a la convencion de la cuenta
-- (<env>-<cuenta>-rcncr-ws5-geo y BURoleFor-<env>-<cuenta>-rcncr-ws5-redshift-geo),
-- que es la que usa la infraestructura desplegada por IaC. Antes llevaban un
-- literal nuestro (rcncr-batch-geo-*) que no existia en ninguna cuenta.
--
-- Es idempotente: re-ejecutarlo deja los mismos valores. WHERE explicito y
-- acotado por ambiente y parametro [REDSHIFT:232].
-- ------------------------------------------------------------
UPDATE bdm_datos.geo_config SET valor = 'prod-696708350333-rcncr-ws5-geo'
 WHERE ambiente = 'PROD' AND parametro = 'bucket';
UPDATE bdm_datos.geo_config SET valor = 'arn:aws:iam::696708350333:role/BURoleFor-prod-696708350333-rcncr-ws5-redshift-geo'
 WHERE ambiente = 'PROD' AND parametro = 'iam_role';

UPDATE bdm_datos.geo_config SET valor = 'uat-453645298399-rcncr-ws5-geo'
 WHERE ambiente = 'UAT' AND parametro = 'bucket';
UPDATE bdm_datos.geo_config SET valor = 'arn:aws:iam::453645298399:role/BURoleFor-uat-453645298399-rcncr-ws5-redshift-geo'
 WHERE ambiente = 'UAT' AND parametro = 'iam_role';

UPDATE bdm_datos.geo_config SET valor = 'test-667397050561-rcncr-ws5-geo'
 WHERE ambiente = 'TEST' AND parametro = 'bucket';
UPDATE bdm_datos.geo_config SET valor = 'arn:aws:iam::667397050561:role/BURoleFor-test-667397050561-rcncr-ws5-redshift-geo'
 WHERE ambiente = 'TEST' AND parametro = 'iam_role';

UPDATE bdm_datos.geo_config SET valor = 'dev-647096294147-rcncr-ws5-geo'
 WHERE ambiente = 'DEV' AND parametro = 'bucket';
UPDATE bdm_datos.geo_config SET valor = 'arn:aws:iam::647096294147:role/BURoleFor-dev-647096294147-rcncr-ws5-redshift-geo'
 WHERE ambiente = 'DEV' AND parametro = 'iam_role';

-- ------------------------------------------------------------
-- 2026-10-20 (GEO no bloqueante): dos parametros nuevos.
--   s3_output_prefix    donde ArcGIS deja los resultados (Salida_Geo.pdf:
--                       reconocer_output/, archivos geo_result_* y
--                       distancias_result_*). Lo lee sp_rcn_geo_02_buscar_
--                       resultados.
--   dias_espera_arcgis  dias que un Lote puede seguir en 'exportado' sin
--                       respuesta antes de pasar a 'vencido' y reexportar
--                       sus candidatos. Lo lee sp_geo_exportar_insumo.
-- VAN EN UN INSERT APARTE Y CON GUARDA POR PARAMETRO: el seed de arriba solo
-- siembra una tabla vacia, de modo que en un ambiente ya desplegado no
-- entrarian nunca (mismo patron que s3_enabled en 03b_ddl_geo_mock.sql).
-- Los dos SP usan un valor por defecto si el parametro falta: nunca fallan
-- por esto.
-- ------------------------------------------------------------
INSERT INTO bdm_datos.geo_config (ambiente, parametro, valor)
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
  SELECT 1 FROM bdm_datos.geo_config c
  WHERE c.ambiente = a.ambiente
    AND c.parametro = p.parametro
);

