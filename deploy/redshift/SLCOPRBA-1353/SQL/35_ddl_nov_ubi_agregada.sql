-- ============================================================
-- 35_ddl_nov_ubi_agregada.sql
-- SLCOPRBA-1399: tabla final del dominio UBICACION AGREGADA de Novedades.
-- Tercera MAT portada, detras de UBICACION y ACTIVIDAD ECONOMICA.
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- UTF-8 sin BOM. Sin acentos a proposito.
--
-- LEGADO: PRO_Novedad_Linea_Ubi_Agregada (Novedad.sql:5032-7302), 2270 lineas
-- y 22 etapas. La carga la hacen los dos TPT, igual que en los otros dos
-- dominios:
--   TMP_AGR_ETAPA_FINAL
--     -> Vstg_Reconocer_Info_Ubic_Agrupa (120.TPT:374-443)
--     -> WHERE Severidad <> -1 (130.TPT:215)
--     -> UPSERT (130.TPT:1029-1147, TablaDestino7)
--
-- EL CONTRATO SON 29 COLUMNAS: las del SCHEMA P0035_14 (130.TPT:161-193)
-- menos IN_Severidad, que es decision de carga y no dato. Mas las tres de
-- trazabilidad que ya llevan las otras dos MAT de este repo.
--
-- ------------------------------------------------------------
-- SE PINAN DOS TABLAS Y NO VEINTITRES, y la raya esta en quien las lee.
--   Las 21 etapas intermedias (TMP_AGRUP_1..11, TMP_RECAGR_1..9 y
--   TMP_AGR_ETAPA_FINAL_1) no las lee nadie desde fuera -- lo comprobe: su
--   unico consumidor es el propio SP --, asi que viven y mueren dentro de el.
--   La etapa FINAL si se pina: es el traspaso del SP al cargador, el mismo
--   papel que stg_nov_acteco_etapa_1 en ACTIVIDAD ECONOMICA. Un CTAS dejaria
--   que el tipo lo infiriera la consulta y el contrato cambiaria sin avisar.
--
-- ------------------------------------------------------------
-- CINCO COLUMNAS DEL LEGADO QUE NO SE PORTAN, Y NO ES UN OLVIDO.
--   TMP_RECAGR_ETAPA_7 arrastra Tipo_Via_Principal, Via_Principal,
--   Via_Generadora, Numero_Puerta y Descripcion_Tipo_Via desde la etapa 9, y
--   las pasea por las etapas 8, 9 y FINAL_1 hasta TMP_AGR_ETAPA_FINAL.
--   Ninguna esta en el contrato de 29 columnas, de modo que
--   Vstg_Reconocer_Info_Ubic_Agrupa no las selecciona y jamas llegan a la
--   tabla final: viajan cuatro etapas para nada. Es la cuarta via muerta que
--   aparece en este proceso. No se portan, y por eso la etapa 9 de Ubicacion
--   no necesita las cinco columnas que no tiene.
--
-- ------------------------------------------------------------
-- LA LLAVE SON SIETE COLUMNAS, y conviene tenerlo presente porque es lo que
-- este dominio arriesga. El DELETE del UPSERT (130.TPT:1139-1146) borra por
--   (INFO_BASICA, TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION, UBICACION_DATO,
--    UBICACION_CODIGODANE, UBICACION_CIUDAD, UBICACION_DEPARTAMENTO)
-- y las 22 etapas agrupan y se unen por esa misma llave una y otra vez. Un
-- join que abra en cualquiera de ellas multiplica la salida sin que nada
-- falle: es el fan-out que ya se pago con v_xpm_contacto_canal.
--
-- ------------------------------------------------------------
-- TRES DIVERGENCIAS DE TIPO, LAS MISMAS QUE YA LLEVA mat_info_ubicacion y por
-- los mismos motivos. No se vuelven a discutir:
--
--   | Columna                      | Contrato TPT | Aqui          |
--   |------------------------------|--------------|---------------|
--   | reportado_desde, ultimo_rep. | VARCHAR(8)   | DATE          |
--   | longitud, latitud            | VARCHAR(40)  | DECIMAL(10,6) |
--   | info_basica                  | INTEGER      | BIGINT        |
--
--   Las dos primeras son el DATE -> CHAR implicito de Teradata, que da
--   'YY/MM/DD' en ocho caracteres; guardar la fecha como fecha es mas fiel al
--   dato que al formato. La tercera NO es cosmetica: info_basica es
--   FNV_HASH(pin), de 64 bits, y un INTEGER lo desborda. mat_info_ubicacion
--   se quedo en INTEGER y eso es un defecto abierto de lo ya desplegado;
--   aqui se nace bien, igual que en mat_info_actividad_economica.
--
-- Y UN NOMBRE: el contrato deletrea IN_UBICACCION_INDICATIVO, con dos C. Es
-- una errata del legado en el nombre de una columna de su vista de staging,
-- no un dato. La columna de aqui se llama ubicacion_indicativo.
--
-- ------------------------------------------------------------
-- COD_PAIS NACE BLOQUEADA. El legado la resuelve con
--   CROSS JOIN (SELECT Cod_pais_Geo_Fte FROM V_PAIS WHERE Desc_pais='Colombia')
-- (Novedad.sql:7175-7178) y V_PAIS no se entrego. Se deja NULL. El CROSS JOIN
-- NO se porta: contra una vista que no existe dejaria la etapa final VACIA, y
-- eso seria un defecto nuestro disfrazado de dato que falta.
--
-- Tablas pequenas en DISTSTYLE ALL; esta no lo es -- una fila por persona,
-- dato y ciudad -- y va DISTKEY por info_basica, que es por donde se une con
-- las dos etapas de Ubicacion.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;
CREATE SCHEMA IF NOT EXISTS bdm_tempo;

-- ------------------------------------------------------------
-- bdm_tempo.stg_nov_ubiagr_etapa_final  (legado TMP_AGR_ETAPA_FINAL)
-- Salida del SP y entrada del cargador. Las 29 del contrato mas flag_op,
-- que es de carga y no de dato: por eso esta aqui y no en la tabla final.
--
-- flag_op es 'I' LITERAL en el legado -- CAST(COALESCE(NULL,'I') AS CHAR(1)),
-- Novedad.sql:7170 --, de modo que este dominio no distingue alta de cambio
-- en la etapa. Quien decide es la Severidad del 120.TPT, que compara contra
-- la tabla viva. Se porta literal: una columna constante que el legado emite.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_tempo.stg_nov_ubiagr_etapa_final (
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

CREATE TABLE IF NOT EXISTS bdm_datos.mat_ubicacion_agregada (
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
