-- ============================================================
-- 34b_ddl_nov_actividad_economica_mock.sql
-- ESPEJO MOCK de 34_ddl_nov_actividad_economica.sql. Generado por sustitucion: los
-- nombres de tabla reciben el sufijo _mock y NADA MAS cambia.
-- El diff contra el real debe salir vacio modulo ese sufijo.
-- Las justificaciones de tipo, contrato y divergencia estan en el archivo
-- real y no se duplican aqui a proposito: una copia se desincroniza.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;
CREATE SCHEMA IF NOT EXISTS bdm_tempo;

-- ------------------------------------------------------------
-- bdm_tempo.stg_nov_acteco_etapa_1_mock  (legado TMP_PERS_ACTIVIDAD_ECONOMIC)
-- Salida del dominio. Contrato tomado de Novedad.sql:1347-1382 y del SCHEMA
-- del 130.TPT:76-88.
--
-- POR QUE ESTA PINADA Y NO ES UN CTAS: mismo motivo que las dos etapas de
-- Ubicacion. El tipo lo fija el DDL y no la consulta, de modo que el contrato
-- no cambia sin que alguien lo edite. Aqui importa mas que alli, porque
-- ACTIVIDAD_ECONOMICA y VERSION salen NULL hoy: un CTAS les daria el tipo que
-- le pareciera al motor y romperia el dia que el catalogo llegue.
--
-- flag_op viaja como VARCHAR(1) igual que en la etapa 9 de Ubicacion, y por
-- la misma razon: es la entrada del calculo de Severidad, no un dato final.
--
-- DISTKEY/SORTKEY por info_basica_id: es la llave del LEFT JOIN contra la
-- tabla viva que calcula Severidad (120.TPT:198-199) y la de los criterios.
-- No es id, que aqui es un surrogate que se recalcula en la carga.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_tempo.stg_nov_acteco_etapa_1_mock (
  id                      INTEGER,
  tipo_identificacion     VARCHAR(30),    -- BLOQUEADA: falta V_Hom_Tip_Ident_Linea
  numero_identificacion   BIGINT,
  ciiu                    VARCHAR(20),
  actividad_economica     VARCHAR(500),   -- BLOQUEADA: falta V_ACTIVIDAD_ECONO_CIIU
  version                 INTEGER,        -- BLOQUEADA: falta V_ACTIVIDAD_ECONO_CIIU
  fecha_reporte           DATE,
  info_basica_id          BIGINT,
  flag_op                 VARCHAR(1)      -- I | A. Nunca 'E': ver cabecera
)
DISTSTYLE KEY DISTKEY (info_basica_id)
SORTKEY (info_basica_id);

-- ------------------------------------------------------------
-- bdm_datos.mat_info_actividad_economica_mock
-- Tabla final del dominio. Ocho columnas del contrato (130.TPT:76-88) mas las
-- tres de trazabilidad que ya llevan las demas MAT de este repo.
--
-- id NO es IDENTITY a proposito: el legado lo calcula como
-- MAX(id) + row_number() en la vista de staging, y una IDENTITY daria otra
-- secuencia. Lo asigna el cargador, igual que alli.
--
-- SIN RESTRICCION DE UNICIDAD SOBRE id, aunque sea la llave del UPSERT:
-- Redshift no las impone y declararla mentiria. La unicidad la verifica el
-- criterio NOV-AE-09 sobre los datos, que es donde se puede comprobar.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_actividad_economica_mock (
  id                      INTEGER,
  ciiu                    VARCHAR(20),
  actividad_economica     VARCHAR(500),
  version                 INTEGER,
  fecha_reporte           DATE,
  info_basica_id          BIGINT,
  tipo_identificacion     VARCHAR(30),
  numero_identificacion   BIGINT,
  lote                    INTEGER,
  fecha_actualizacion     TIMESTAMP DEFAULT GETDATE(),
  usuario_bd              VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (info_basica_id)
SORTKEY (info_basica_id);
