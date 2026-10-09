-- ============================================================
-- 01d_ddl_direccion_generada.sql
-- Tablas destino de las DIRECCIONES GENERADAS por el motor de Regla 2.
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- Cluster consumidor: reconocerbatch / dba_rncr_batch
-- DDL idempotente (CREATE TABLE IF NOT EXISTS). Objetos permanentes en bdm_datos.
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Spec: unificacion-full-delta -- reconexion del motor de direcciones
-- ------------------------------------------------------------
-- SLCOPRBA-1354: el motor de Regla 2
-- (sp_unificacion_r2_motor_nit_empates_nuevas_direcciones) resuelve los casos
-- de EMPATE que los seis escenarios dejan sin padre -- NIT con dos o mas
-- direcciones, niveles de nomenclatura distintos y empate de frecuencia
-- (fa.freq = fb.freq, justo lo que esc6 no puede porque exige >). Cuando nadie
-- puede ser padre, FUSIONA los complementos en una direccion NUEVA.
--
-- En el legado Teradata esa direccion nueva SI se persiste. La cadena es:
--   PRO_UnificacionR2 marca las filas nuevas con -99 AS ROW_U
--     -> Tmp_Unificacion_E2 --RENAME--> R2_Vstg_Unificacion
--     -> vista VstgCargaUnificacionDir (ID_ACTUALIZACION = 1 cuando ROW_U = -99)
--     -> TPT P0020_UNIFICACION_DIRECCION_130, tercer destino:
--        INSERT INTO DIRECCION_FISICA (..., Generada_Enriquecida = 1, ...)
-- y el comentario del propio legado (PRO_UnificacionR2.sql:1662) lo dice:
--   "los registros que se deben crear en direccion_fisica y en
--    Relacion_persona_ubicacion"
--
-- En Redshift el motor CALCULA todo (stg_motor_insumo trae ya el complemento
-- fusionado, los dos ids nuevos y generada_enriquecida = 1) pero NO PERSISTE:
-- su staging se construye y el orquestador de Regla 2 lo borra. Nada lo lee.
-- La causa: bdm_datos.direccion_fisica y bdm_datos.relacion_persona_ubicacion
-- NO existen como tablas en el consumidor -- son vistas de solo lectura del
-- datashare, y por eso v_xpm_direccion_fisica expone generada_enriquecida como
-- CAST(0 AS INTEGER).
--
-- Estas dos tablas cierran ese hueco siguiendo el MISMO PATRON que
-- bdm_datos.geo_atributos: una tabla local que suple lo que el datashare no
-- deja escribir. Las vistas v_xpm_* / v_mock_* pasan a ser UNION ALL del
-- datashare con estas tablas (02_vistas_insumo_edf_views.sql y 02b).
--
-- ------------------------------------------------------------
-- NOTA sobre la asignacion de identificadores (divergencia deliberada)
--   El legado usa un secuenciador central:
--     (SELECT ID FROM REC_MTDAT.MAX_ID WHERE NOMBRE_TABLA = 'DIRECCION_FISICA')
--       + SUM(1) OVER (ROWS UNBOUNDED PRECEDING)
--   Redshift usa un hash determinista:
--     FNV_HASH(id_buro_persona || '|MOTOR|DF|'  || texto_ubicacion)
--     FNV_HASH(id_buro_persona || '|MOTOR|RPU|' || texto_ubicacion)
--   Se mantiene el hash, y no solo porque no exista secuenciador en el
--   consumidor: el secuenciador NO es idempotente -- re-ejecutar genera ids
--   nuevos y DUPLICA direcciones. El hash devuelve el mismo id ante la misma
--   entrada, que es lo que un pipeline FULL/DELTA re-ejecutable necesita, y
--   hace que el UPSERT del motor sea idempotente por construccion.
--   Riesgo asumido: colision del hash con un cod_dw_direccion_fisica real del
--   datashare. Se cubre con un gate de colision en la bateria de validacion.
--
-- ------------------------------------------------------------
-- cod_dw_ubic: HEREDADO de la direccion de origen, sin recalcular. Verificado
-- en el legado (PRO_UnificacionR2.sql:1625, 'CL.COD_DW_UBIC'): la ubicacion --
-- el texto de la via -- es la misma; lo que cambia es el complemento.
--
-- fecha_inactivacion: el legado la contempla en su INSERT a DIRECCION_FISICA.
-- Las vistas filtran WHERE fecha_inactivacion IS NULL, de modo que una
-- direccion generada se puede retirar de circulacion sin borrar el historico.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ============================================================
-- bdm_datos.direccion_fisica_generada -- PERMANENTE
-- Contrapartida local de DIRECCION_FISICA para las filas que el motor crea.
-- Columnas alineadas al INSERT del tercer destino del TPT legado.
-- Clave de negocio: cod_dw_direccion_fisica (el hash determinista del motor).
-- DISTSTYLE KEY por cod_dw_ubic: es como la consultan las vistas al unirse con
-- el universo de ubicaciones.
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.direccion_fisica_generada (
  cod_dw_direccion_fisica BIGINT       NOT NULL,  -- FNV_HASH(persona|MOTOR|DF|texto)
  complemento             VARCHAR(1000),          -- complemento fusionado por el motor
  tipo_via_principal      VARCHAR(50),            -- heredados de la direccion de origen
  via_principal           VARCHAR(100),
  via_generadora          VARCHAR(100),
  numero_puerta           VARCHAR(50),
  cod_dw_ubic             BIGINT,                 -- HEREDADO (no se recalcula)
  lote                    INTEGER,                -- lote que CREO la fila (inmutable)
  lote_actualizacion      INTEGER,                -- ultimo lote que la re-toco
  severidad               INTEGER,                -- 1, igual que el legado
  usuario_bd              VARCHAR(100),
  generada_enriquecida    INTEGER,                -- siempre 1: marca de direccion generada
  fecha_inactivacion      DATE,                   -- NULL = vigente; las vistas filtran por esto
  fecha_modificacion      DATE
)
DISTSTYLE KEY
DISTKEY (cod_dw_ubic)
SORTKEY (cod_dw_direccion_fisica);

-- ============================================================
-- bdm_datos.rpu_generada -- PERMANENTE
-- RPU sintetica que asocia la direccion generada con la persona. Sin ella la
-- direccion nueva quedaria en un catalogo que nadie consulta: no entraria al
-- universo de Unificacion, Ordenamiento ni GEO.
-- Columnas alineadas a bdm_tempo.v_xpm_relacion_persona_ubicacion para que el
-- UNION ALL de la vista sea directo. orden_prioridad NO se almacena: la vista
-- lo recalcula con ROW_NUMBER sobre el universo unido.
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.rpu_generada (
  cod_dw_persona_ubic            BIGINT  NOT NULL, -- FNV_HASH(persona|MOTOR|RPU|texto)
  id_buro_persona                BIGINT,
  cod_pin_persona                BIGINT,
  cod_dw_ubic                    BIGINT,           -- HEREDADO
  cod_dw_direccion_fisica        BIGINT,           -- FK logico a direccion_fisica_generada
  cod_dw_tipo_ubicacion_dir      INTEGER,
  ind_unificacion                INTEGER,          -- NULL: la direccion generada nace sin unificar
  fecha_relacion_persona_ubicaci DATE,
  lote                           INTEGER,
  lote_actualizacion             INTEGER,
  -- VARCHAR(20) como el CAST(NULL AS VARCHAR(20)) del legado (linea 1677 de
  -- PRO_UnificacionR2.sql), y el motor siempre escribe NULL aqui. OJO: en la
  -- via REAL el datashare expone cod_tipo_ident_fte como INTEGER, asi que
  -- v_xpm_relacion_persona_ubicacion lo castea a INTEGER al unir las dos ramas.
  -- El cast no puede fallar porque el valor es NULL; si alguna vez se escribe
  -- algo aqui, tiene que ser numerico.
  cod_tipo_ident_fte             VARCHAR(20),
  usuario_bd                     VARCHAR(100),
  fecha_inactivacion             DATE,             -- NULL = vigente
  fecha_modificacion             DATE
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona, cod_dw_persona_ubic);

-- ============================================================
-- Espejos MOCK. Misma estructura; la via mock los resetea en cada FULL para
-- que la bateria de certificacion sea repetible (decision del equipo). En la
-- via REAL no se resetean: el legado nunca borra las direcciones generadas,
-- son acumulativas como geo_atributos.
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.direccion_fisica_generada_mock (
  cod_dw_direccion_fisica BIGINT       NOT NULL,
  complemento             VARCHAR(1000),
  tipo_via_principal      VARCHAR(50),
  via_principal           VARCHAR(100),
  via_generadora          VARCHAR(100),
  numero_puerta           VARCHAR(50),
  cod_dw_ubic             BIGINT,
  lote                    INTEGER,
  lote_actualizacion      INTEGER,
  severidad               INTEGER,
  usuario_bd              VARCHAR(100),
  generada_enriquecida    INTEGER,
  fecha_inactivacion      DATE,
  fecha_modificacion      DATE
)
DISTSTYLE KEY
DISTKEY (cod_dw_ubic)
SORTKEY (cod_dw_direccion_fisica);

CREATE TABLE IF NOT EXISTS bdm_datos.rpu_generada_mock (
  cod_dw_persona_ubic            BIGINT  NOT NULL,
  id_buro_persona                BIGINT,
  cod_pin_persona                BIGINT,
  cod_dw_ubic                    BIGINT,
  cod_dw_direccion_fisica        BIGINT,
  cod_dw_tipo_ubicacion_dir      INTEGER,
  ind_unificacion                INTEGER,
  fecha_relacion_persona_ubicaci DATE,
  lote                           INTEGER,
  lote_actualizacion             INTEGER,
  cod_tipo_ident_fte             VARCHAR(20),
  usuario_bd                     VARCHAR(100),
  fecha_inactivacion             DATE,
  fecha_modificacion             DATE
)
DISTSTYLE KEY
DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona, cod_dw_persona_ubic);
