-- 21_ddl_catalogos_dominio.sql
-- Catalogos de dominio entregados por el cliente (novedades_mapeo_y_catalogos.zip).
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- Cluster consumidor: reconocerbatch / dba_rncr_batch
-- Objetos permanentes en bdm_datos. Idempotente (CREATE TABLE IF NOT EXISTS + TRUNCATE).
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- ------------------------------------------------------------
-- SLCOPRBA-1355: los CUATRO catalogos que NO tenian contraparte en el repo.
--
-- Se cargan tal cual los entrego el cliente, con TODAS sus columnas: son de
-- 2 a 33 filas, no cuesta nada conservarlas, y asi no hay que volver a pedir
-- la que falte. Los 'NULL' de texto del CSV entran como NULL de verdad.
--
-- NO se tocan los dos catalogos que SI tienen contraparte y la CONTRADICEN:
--   bdm_datos.nomenclatura        12 entradas nuestras contra 58 reales, y 8
--                                 de las 12 con el nivel equivocado
--   bdm_datos.tipo_ubicacion_dir  llaves nuestras 1..7 contra las reales de
--                                 cinco digitos (21478, 21426, 21461, ...)
-- Los dos cambian resultados de procesos ya certificados. Decision tomada:
-- documentar, no corregir. Ver docs/HALLAZGOS_CATALOGOS_REALES.md en dt.
--
-- NO se cargan V_Cod_Entrega_Dato ni V_Geografia: llegaron TRUNCADOS a 1000
-- filas exactas (Geografia se corta en Santander). Un catalogo geografico a
-- medias no da error: da joins que no casan, en silencio.
-- ============================================================

-- catalogo_fuente -- origen REC_VISTA.V_Fuente
-- Fuente de la ubicacion. Gap del Bloque B de la peticion de datashare.
CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_fuente (
  cod_dw_fuente                      VARCHAR(20),
  descripcion_fuente                 VARCHAR(20),
  valor_fuente                       VARCHAR(20),
  cod_dw_pais                        VARCHAR(20)
)
DISTSTYLE ALL;   -- 6 filas: replicarlo cuesta menos que redistribuirlo

TRUNCATE TABLE bdm_datos.catalogo_fuente;

INSERT INTO bdm_datos.catalogo_fuente (cod_dw_fuente, descripcion_fuente, valor_fuente, cod_dw_pais)
  SELECT CAST('77387' AS VARCHAR(20)), CAST('CIU' AS VARCHAR(20)), CAST('CIU' AS VARCHAR(20)), CAST('1' AS VARCHAR(20)) UNION ALL
  SELECT '21409', 'CAS', 'CAS', '1' UNION ALL
  SELECT '21484', 'SUS', 'Suscriptor', '1' UNION ALL
  SELECT '31937', 'CONTACTABILIDAD', 'CONTACTABILIDAD', '1' UNION ALL
  SELECT '21402', 'Camara de Comercio', 'Camara de Comercio', '1' UNION ALL
  SELECT '21464', 'MiDC', 'Mi DataCredito', '1';

-- catalogo_gestion_registro -- origen REC_VISTA.V_Gestion_Registro
-- Gestion del registro. Hoy el Ordenamiento la SINTETIZA con una expresion regular (04_vistas_insumo_ordenamiento_edf_views.sql:104-107); este es el catalogo real.
CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_gestion_registro (
  cod_dw_gestion_registro            VARCHAR(20),
  descripcion_gestion_registro       VARCHAR(20),
  cod_dw_pais                        VARCHAR(20)
)
DISTSTYLE ALL;   -- 2 filas: replicarlo cuesta menos que redistribuirlo

TRUNCATE TABLE bdm_datos.catalogo_gestion_registro;

INSERT INTO bdm_datos.catalogo_gestion_registro (cod_dw_gestion_registro, descripcion_gestion_registro, cod_dw_pais)
  SELECT CAST('61197' AS VARCHAR(20)), CAST('VALIDA' AS VARCHAR(20)), CAST('1' AS VARCHAR(20)) UNION ALL
  SELECT '61196', 'NO VALIDA', '1';

-- catalogo_razon_bloqueo -- origen BDM_VISTA.V_Razon_Bloqueo
-- Razon de bloqueo. El criterio F3-01 del Ordenamiento la echa de menos: hoy no hay filtro de bloqueo.
CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_razon_bloqueo (
  cod_dw_razon_bloqueo               VARCHAR(20),
  nombre_razon_bloqueo               VARCHAR(100),
  desc_razon_bloqueo                 VARCHAR(100),
  cod_dw_pais                        VARCHAR(20),
  cod_dw_fte_dato                    VARCHAR(20),
  cod_razon_bloqueo_fte              VARCHAR(20),
  lote                               VARCHAR(20),
  lote_actualizacion                 VARCHAR(20),
  severidad                          VARCHAR(20),
  fecha_eliminado                    VARCHAR(20),
  cod_dw_evento_entrega_dato         VARCHAR(20)
)
DISTSTYLE ALL;   -- 18 filas: replicarlo cuesta menos que redistribuirlo

TRUNCATE TABLE bdm_datos.catalogo_razon_bloqueo;

INSERT INTO bdm_datos.catalogo_razon_bloqueo (cod_dw_razon_bloqueo, nombre_razon_bloqueo, desc_razon_bloqueo, cod_dw_pais, cod_dw_fte_dato, cod_razon_bloqueo_fte, lote, lote_actualizacion, severidad, fecha_eliminado, cod_dw_evento_entrega_dato)
  SELECT CAST('6' AS VARCHAR(20)), CAST('Eliminacion por Novedat (nuevo), no se muestra en la Historia de Credito.' AS VARCHAR(100)), CAST('Eliminacion por Novedat (nuevo), no se muestra en la Historia de Credito.' AS VARCHAR(100)), CAST('1' AS VARCHAR(20)), CAST('0' AS VARCHAR(20)), CAST('5' AS VARCHAR(20)), CAST('370' AS VARCHAR(20)), CAST('1112' AS VARCHAR(20)), CAST('1' AS VARCHAR(20)), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR) UNION ALL
  SELECT '17', 'No presenta autorizacion firmada', 'No presenta autorizacion firmada', '1', '0', 'D', '1112', NULL, '1', NULL, NULL UNION ALL
  SELECT '11', 'Cancelado por prescripcion', 'Cancelado por prescripcion', '1', '0', 'I', '1112', NULL, '1', NULL, NULL UNION ALL
  SELECT '18', 'Se presento fraude', 'Se presento fraude', '1', '0', 'E', '1112', NULL, '1', NULL, NULL UNION ALL
  SELECT '15', 'Duplicidad en el registro', 'Duplicidad en el registro', '1', '0', 'B', '1112', NULL, '1', NULL, NULL UNION ALL
  SELECT '7', 'Obligaciones Cerradas - Despues de 4 anos se bloquean, no se muestra en la Historia de Credito.', 'Obligaciones Cerradas - Despues de 4 anos se bloquean, no se muestra en la Historia de Credito.', '1', '0', '6', '370', '1112', '1', NULL, NULL UNION ALL
  SELECT '10', 'Registro frenado, no se muestra en la Historia de Credito.', 'Registro frenado, no se muestra en la Historia de Credito.', '1', '0', '7', '370', '1112', '1', NULL, NULL UNION ALL
  SELECT '4', 'El registro se encuentra activo, si se muestra en la Historia de Credito.', 'El registro se encuentra activo, si se muestra en la Historia de Credito.', '1', '0', '0', '370', '1112', '1', NULL, NULL UNION ALL
  SELECT '1', 'Bloqueado por no solucion de reclamos, no se muestra en la Historia de Credito.', 'Bloqueado por no solucion de reclamos, no se muestra en la Historia de Credito.', '1', '0', '8', '370', '1112', '1', NULL, NULL UNION ALL
  SELECT '2', 'Bloqueo historico, no se muestra en la Historia de Credito', 'Bloqueo historico, no se muestra en la Historia de Credito', '1', '0', '1', '370', '1112', '1', NULL, NULL UNION ALL
  SELECT '9', 'Proceso de Eliminacion logica, no se muestra en la Historia de Credito.', 'Proceso de Eliminacion logica, no se muestra en la Historia de Credito.', '1', '0', '4', '370', '1112', '1', NULL, NULL UNION ALL
  SELECT '16', 'No le pertenece la obligacion', 'No le pertenece la obligacion', '1', '0', 'C', '1112', NULL, '1', NULL, NULL UNION ALL
  SELECT '3', 'Cuentas sin validar ante la Registraduria, si se muestra en la Historia de Credito.', 'Cuentas sin validar ante la Registraduria, si se muestra en la Historia de Credito.', '1', '0', '9', '370', '1112', '1', NULL, NULL UNION ALL
  SELECT '5', 'Eliminacion por Novedat (antiguo), no se muestra en la Historia de Credito.', 'Eliminacion por Novedat (antiguo), no se muestra en la Historia de Credito.', '1', '0', '3', '370', '1112', '1', NULL, NULL UNION ALL
  SELECT '8', 'Proceso de caducidad, no se muestra en la Historia de Credito.', 'Proceso de caducidad, no se muestra en la Historia de Credito.', '1', '0', '2', '370', '1112', '1', NULL, NULL UNION ALL
  SELECT '13', 'Cuenta con fecha de actualizacion menor a la fecha de ingreso', 'Cuenta con fecha de actualizacion menor a la fecha de ingreso', '1', '0', 'F', '1112', NULL, '1', NULL, NULL UNION ALL
  SELECT '12', 'Credito reemplazado por otro numero de obligacion', 'Credito reemplazado por otro numero de obligacion', '1', '0', 'A', '1112', NULL, '1', NULL, NULL UNION ALL
  SELECT '14', 'Cuenta con reclamo en tramite', 'Cuenta con reclamo en tramite', '1', '0', 'G', '1112', NULL, '1', NULL, NULL;

-- catalogo_fuente_dato -- origen BDM_VISTA.V_Fuente_Dato
-- Fuente del dato. Gap del Bloque A de la peticion de datashare.
CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_fuente_dato (
  cod_dw_fte_dato                    VARCHAR(20),
  nombre_fte_dato                    VARCHAR(60),
  desc_fte_dato                      VARCHAR(60),
  id_buro_proveedor_dato             VARCHAR(20),
  cod_fte_dato_fte                   VARCHAR(20),
  cod_dw_pais                        VARCHAR(20),
  lote                               VARCHAR(20),
  lote_actualizacion                 VARCHAR(20),
  severidad                          VARCHAR(20),
  fecha_eliminado                    VARCHAR(20),
  cod_dw_evento_entrega_dato         VARCHAR(20)
)
DISTSTYLE ALL;   -- 33 filas: replicarlo cuesta menos que redistribuirlo

TRUNCATE TABLE bdm_datos.catalogo_fuente_dato;

INSERT INTO bdm_datos.catalogo_fuente_dato (cod_dw_fte_dato, nombre_fte_dato, desc_fte_dato, id_buro_proveedor_dato, cod_fte_dato_fte, cod_dw_pais, lote, lote_actualizacion, severidad, fecha_eliminado, cod_dw_evento_entrega_dato)
  SELECT CAST('24' AS VARCHAR(20)), CAST('WEB SERVICE CCB - CAMARAS DE COMERCIO' AS VARCHAR(60)), CAST('WEB SERVICE CCB - CAMARAS DE COMERCIO' AS VARCHAR(60)), CAST(NULL AS VARCHAR), CAST('24' AS VARCHAR(20)), CAST('1' AS VARCHAR(20)), CAST('0' AS VARCHAR(20)), CAST(NULL AS VARCHAR), CAST('1' AS VARCHAR(20)), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR) UNION ALL
  SELECT '13', 'VALORES COMPLEMENTARIOS DE OBLIGACIONES DE CARTERA', 'VALORES COMPLEMENTARIOS DE OBLIGACIONES DE CARTERA', NULL, '13', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '9', 'HUELLAS DE CONSULTA', 'HUELLAS DE CONSULTA', NULL, '9', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '20', 'MOTIVO ORIGEN PASIVO Y ACTIVO', 'MOTIVO ORIGEN PASIVO Y ACTIVO', NULL, '20', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '18', 'GEOGRAFIA REGISTRADURIA', 'GEOGRAFIA REGISTRADURIA', NULL, '18', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '17', 'ADJETIVOS', 'ADJETIVOS', NULL, '17', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '6', 'CLIENTES DE LOS SUSCRIPTORES', 'CLIENTES DE LOS SUSCRIPTORES', NULL, '6', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '29', 'REGISTRO NACIONAL DE PROPONENTES  RNP', 'REGISTRO NACIONAL DE PROPONENTES  RNP', NULL, '29', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '15', 'RELACION ENTRE CATALOGOS', 'RELACION ENTRE CATALOGOS', NULL, '15', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '32', 'SCORE ADVANCE', 'SCORE ADVANCE DE ASCEND', NULL, '32', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '21', 'CALIFICACION COMPORTAMIENTO CUENTA PASIVO Y ACTIVO', 'CALIFICACION COMPORTAMIENTO CUENTA PASIVO Y ACTIVO', NULL, '21', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '1', 'REGISTRADURIA', 'REGISTRADURIA', NULL, '1', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '4', 'SUSCRIPTORES', 'SUSCRIPTORES', NULL, '4', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '7', 'OBLIGACIONES DE CARTERA', 'OBLIGACIONES DE CARTERA', NULL, '7', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '31', 'CDT', 'CDT', NULL, '31', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '25', 'WEB SERVICE JURAD - CAMARAS DE COMERCIO', 'WEB SERVICE JURAD - CAMARAS DE COMERCIO', NULL, '25', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '19', 'NOVEDAD BURO PASIVO Y ACTIVO', 'NOVEDAD BURO PASIVO Y ACTIVO', NULL, '19', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '28', 'REGISTRO NACIONAL DE TURISMO  RNT', 'REGISTRO NACIONAL DE TURISMO  RNT', NULL, '28', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '23', 'ARCHIVO PLANO - ETL - CAMARAS DE COMERCIO', 'ARCHIVO PLANO - ETL - CAMARAS DE COMERCIO', NULL, '23', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '0', 'CATALOGO', 'CATALOGO', NULL, '0', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '22', 'CAMARAS DE COMERCIO', 'CAMARAS DE COMERCIO', NULL, '22', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '2', 'DIAN', 'DIAN', NULL, '2', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '10', 'ENDEUDAMIENTO GLOBAL', 'ENDEUDAMIENTO GLOBAL', NULL, '10', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '8', 'DIRECCIONES Y TELEFONOS', 'DIRECCIONES Y TELEFONOS', NULL, '8', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '12', 'SCORES HISTORICO 360', 'SCORES HISTORICO 360', NULL, '12', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '14', 'GEOGRAFIA', 'GEOGRAFIA', NULL, '14', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '3', 'DAS', 'DAS', NULL, '3', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '16', 'CIIU', 'CIIU', NULL, '16', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '30', 'GARANTIAS MOBILIARIAS', 'GARANTIAS MOBILIARIAS', NULL, '30', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '27', 'SISBEN', 'SISBEN', NULL, '27', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '5', 'CUENTA CORRIENTE Y AHORROS', 'CUENTA CORRIENTE Y AHORROS', NULL, '5', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '11', 'SCORES MENSUAL 360', 'SCORES MENSUAL 360', NULL, '11', '1', '0', NULL, '1', NULL, NULL UNION ALL
  SELECT '26', 'SUPERSOCIEDADES', 'SUPERSOCIEDADES', NULL, '26', '1', '0', NULL, '1', NULL, NULL;
