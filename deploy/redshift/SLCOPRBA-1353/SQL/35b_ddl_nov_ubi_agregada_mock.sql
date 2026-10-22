-- ============================================================
-- 35b_ddl_nov_ubi_agregada_mock.sql
-- ESPEJO MOCK de 35_ddl_nov_ubi_agregada.sql. Generado por sustitucion: los
-- nombres de tabla reciben el sufijo _mock y NADA MAS cambia.
-- El diff contra el real debe salir vacio modulo ese sufijo.
-- Las justificaciones de tipo, contrato y divergencia estan en el archivo
-- real y no se duplican aqui a proposito: una copia se desincroniza.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;
CREATE SCHEMA IF NOT EXISTS bdm_tempo;

-- ------------------------------------------------------------
-- bdm_tempo.stg_nov_ubiagr_etapa_final_mock  (legado TMP_AGR_ETAPA_FINAL)
-- Salida del SP y entrada del cargador. Las 29 del contrato mas flag_op,
-- que es de carga y no de dato: por eso esta aqui y no en la tabla final.
--
-- flag_op es 'I' LITERAL en el legado -- CAST(COALESCE(NULL,'I') AS CHAR(1)),
-- Novedad.sql:7170 --, de modo que este dominio no distingue alta de cambio
-- en la etapa. Quien decide es la Severidad del 120.TPT, que compara contra
-- la tabla viva. Se porta literal: una columna constante que el legado emite.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_tempo.stg_nov_ubiagr_etapa_final_mock (
  tipo_identificacion             VARCHAR(30),
  numero_identificacion           BIGINT,
  info_basica                     BIGINT,
  codigo_dane                     VARCHAR(20),
  ciudad                          VARCHAR(30),
  departamento                    VARCHAR(30),
  ubicacion_dato                  VARCHAR(201),
  ubicacion_reportdesde           DATE,
  ubicacion_ultreporte            DATE,
  ubicacion_numentidades          INTEGER,
  ubicacion_numreportes           INTEGER,
  ubicacion_clase                 VARCHAR(5),
  ubicacion_tipocuenta            VARCHAR(1),
  ubicacion_orden                 INTEGER,
  ubicacion_indicativo            VARCHAR(20),
  ubicacion_estrato               VARCHAR(10),
  ubicacion_zona                  VARCHAR(30),
  ubicacion_ciudad                VARCHAR(30),
  ubicacion_departamento          VARCHAR(30),
  ubicacion_codigodane            VARCHAR(20),
  ubicacion_barrio                VARCHAR(100),
  ubicacion_localidad             VARCHAR(100),
  ubicacion_codigopostal          VARCHAR(20),
  ubicacion_longitud              DECIMAL(10,6),
  ubicacion_latitud               DECIMAL(10,6),
  tipo                            VARCHAR(30),
  fuente                          VARCHAR(30),
  id                              VARCHAR(1000),
  cod_pais                        VARCHAR(3),
  flag_op                         VARCHAR(1)      -- 'I' literal; ver cabecera
)
DISTSTYLE KEY DISTKEY (info_basica)
SORTKEY (info_basica, ubicacion_dato);

CREATE TABLE IF NOT EXISTS bdm_datos.mat_ubicacion_agregada_mock (
  tipo_identificacion             VARCHAR(30),    -- SI se puebla desde el 2026-10-21 (llego el catalogo)
  numero_identificacion           BIGINT,
  info_basica                     BIGINT,         -- id_buro_persona; BIGINT, ver cabecera
  codigo_dane                     VARCHAR(20),
  ciudad                          VARCHAR(30),
  departamento                    VARCHAR(30),
  ubicacion_dato                  VARCHAR(201),
  ubicacion_reportdesde           DATE,           -- SI se puebla: viene de la etapa 2
  ubicacion_ultreporte            DATE,           -- SI se puebla: viene de la etapa 2
  ubicacion_numentidades          INTEGER,        -- SI se puebla: viene de la etapa 2
  ubicacion_numreportes           INTEGER,        -- SI se puebla: viene de la etapa 2
  ubicacion_clase                 VARCHAR(5),
  ubicacion_tipocuenta            VARCHAR(1),     -- BLOQUEADA: falta V_TIPO_CORREO
  ubicacion_orden                 INTEGER,
  ubicacion_indicativo            VARCHAR(20),    -- BLOQUEADA: falta V_TELEFONO_FIJO
  ubicacion_estrato               VARCHAR(10),    -- BLOQUEADA: contrato GEO sin pinar
  ubicacion_zona                  VARCHAR(30),    -- BLOQUEADA: falta V_ZONA_UBICACION
  ubicacion_ciudad                VARCHAR(30),
  ubicacion_departamento          VARCHAR(30),
  ubicacion_codigodane            VARCHAR(20),
  ubicacion_barrio                VARCHAR(100),   -- BLOQUEADA: contrato GEO sin pinar
  ubicacion_localidad             VARCHAR(100),   -- BLOQUEADA: contrato GEO sin pinar
  ubicacion_codigopostal          VARCHAR(20),    -- BLOQUEADA: contrato GEO sin pinar
  ubicacion_longitud              DECIMAL(10,6),
  ubicacion_latitud               DECIMAL(10,6),
  tipo                            VARCHAR(30),    -- cadena agregada: 'R - L - C'
  fuente                          VARCHAR(30),    -- cadena agregada: 'SUS - CAM'
  id                              VARCHAR(1000),  -- lista de cod_dw_ubic separada por comas
  cod_pais                        VARCHAR(3),     -- BLOQUEADA: falta V_PAIS
  lote                            INTEGER,
  fecha_actualizacion             TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                      VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (info_basica)
SORTKEY (info_basica, ubicacion_dato);
