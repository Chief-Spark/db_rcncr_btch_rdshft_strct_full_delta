-- ============================================================
-- 34_ddl_nov_actividad_economica.sql
-- SLCOPRBA-1355: Novedades, dominio ACTIVIDAD ECONOMICA.
-- Segunda de las siete MAT_*. UTF-8 sin BOM, sin acentos.
--
-- LA NOMENCLATURA DEL LEGADO ESTA CRUZADA, y esta es la tabla donde mas
-- engana: MAT_INFO_ACTIVIDAD_ECONOMICA la produce PRO_Novedad_Linea_HISTORIAL
-- (Novedad.sql:1060), no un SP llamado "actividad". Para portar hay que seguir
-- el 120.TPT y el 130.TPT, nunca el nombre del procedimiento.
--
-- LA CADENA DEL LEGADO:
--   TMP_VU_PERS_ACTIVIDAD_ECONOMIC            (universo)
--     -> TMP_PERS_ACTIVIDAD_ECONOMIC          (Novedad.sql:1347-1382)
--     -> Vstg_Reconocer_Actividad_Econo       (120.TPT:176-199, calcula Severidad)
--     -> UPSERT / DELETE por ID               (130.TPT:710-757)
--
-- POLITICA DE TIPOS: mandan los nativos de Redshift (decision del equipo,
-- SLCOPRBA-1355). FECHA_REPORTE viaja como VARCHAR(8) 'YYYYMMDD' por el
-- contrato de archivo plano y el TPT la castea a DATE al escribirla
-- (130.TPT:729, 'CAST(:IN_FECHA_REPORTE AS DATE FORMAT ''YYYYMMDD'')'), asi
-- que aqui se ALMACENA DATE y el formato se resuelve en el UNLOAD.
--
-- ------------------------------------------------------------
-- DOS RAMAS MUERTAS DEL LEGADO, Y ES LA SEGUNDA VEZ QUE APARECE EL PATRON.
-- Igual que con flag_op = 'E' en Ubicacion, aqui hay codigo que no se ejecuta
-- nunca. Se porta literal y se deja escrito para que nadie lo "arregle":
--
--   1. EL DELETE NO OCURRE. El 130.TPT lleva su rama
--      'WHEN IN_Severidad = 2 THEN DELETE ... WHERE ID = :IN_ID' (:753), pero
--      el CASE que calcula Severidad en 120.TPT:186-197 tiene exactamente
--      tres ramas que dan 1 y un ELSE que da -1. NO HAY RAMA QUE DEVUELVA 2.
--      El -1 lo descarta el filtro de carga (130.TPT:215). Esta tabla solo
--      recibe altas.
--
--   2. EL UPDATE DEL UPSERT TAMPOCO. La vista de staging asigna
--      ID = Max_ID + SUM(1) OVER (ROWS UNBOUNDED PRECEDING) (120.TPT:177),
--      con Max_ID = COALESCE(MAX(ID),0) de la tabla VIVA. Cada fila preparada
--      estrena por tanto un ID por encima del maximo existente, de modo que el
--      'UPDATE ... WHERE ID = :IN_ID' (:722) no encuentra fila jamas y el
--      'INSERT FOR MISSING UPDATE ROWS' (:750) inserta siempre.
--
--   CONSECUENCIA QUE HAY QUE SABER ANTES DE MIRAR LOS DATOS: la tabla CRECE y
--   acumula una fila nueva por persona cada vez que su Severidad da 1. El
--   legado nunca actualiza ni borra una fila de esta tabla.
--
--   EN NUESTRO PORT ESO NO SE DISPARA, y conviene decir por que: la Severidad
--   compara ACTIVIDAD_ECONOMICA y VERSION contra la tabla viva
--   (120.TPT:189-192), y las dos salen NULL en nuestra via por falta del
--   catalogo CIIU. COALESCE(NULL,'SV') <> COALESCE(NULL,'SV') es falso, asi
--   que solo quedan vivas las ramas de "persona nueva". No hay duplicacion
--   descontrolada mientras el catalogo no llegue. Cuando llegue, volvera.
--
-- ------------------------------------------------------------
-- LO QUE SALE POBLADO Y LO QUE NO, que es lo primero que alguien va a
-- preguntar al ver la tabla. Origen segun el mapeo del datashare:
--
--   ID                     surrogate                                     SI
--   CIIU                   v_xpm_ciiu_persona.cod_act_econo_ciiu_fte     SI
--   ACTIVIDAD_ECONOMICA    catalogo V_ACTIVIDAD_ECONO_CIIU            NO (*)
--   VERSION                catalogo V_ACTIVIDAD_ECONO_CIIU            NO (*)
--   FECHA_REPORTE          cutoffdate via v_xpm_reporte_rel_pers_ubica   SI (**)
--   INFO_BASICA_ID         id_buro_persona                               SI
--   TIPO_IDENTIFICACION    catalogo V_Hom_Tip_Ident_Linea             NO (*)
--   NUMERO_IDENTIFICACION  cod_pin_persona                               SI
--
--   (*)  Los tres catalogos estan pedidos en
--        docs/PETICION_CATALOGOS_NOVEDADES.md. V_ACTIVIDAD_ECONO_CIIU NO
--        estaba en esa peticion y se anade ahora: no venia en los diez CSV de
--        novedades_mapeo_y_catalogos.zip.
--   (**) DIVERGENCIA DE GRANO, documentada y no corregida: el legado toma
--        COALESCE(VPAE.FECHA_REPORTE, VPJC.Fecha_Matricula) con grano por
--        (persona, CIIU). Nuestro cutoffdate tiene grano por UBICACION, de
--        modo que aqui se agrega con MAX por persona. Es la fecha mas
--        reciente en que se vio a la persona, no la del reporte de su CIIU.
--        V_Persona_Juridica_Camara no esta en el datashare.
--
-- ------------------------------------------------------------
-- info_basica_id ES BIGINT AQUI Y EN EL LEGADO ES INTEGER, A PROPOSITO.
-- Lo alimenta id_buro_persona, que 02_vistas_insumo_edf_views.sql:22 define
-- como FNV_HASH(xpm.pin): 64 bits, habitualmente negativo y muy por fuera del
-- rango de INTEGER. Un INTEGER aqui aborta el lote entero con
-- "Value out of range for 4 bytes" en cuanto se corra contra datos reales.
-- Es la misma politica de tipos del resto del dominio -- manda el nativo de
-- Redshift -- aplicada a una columna donde ademas no es cosmetica.
--
-- Y SE ELEVA, PORQUE TOCA LO YA ESCRITO: mat_info_ubicacion.info_basica SI
-- esta declarada INTEGER (30_ddl_novedades.sql) y sp_novedades_ubicacion_edf
-- hace CAST(e6.id_buro_persona AS INTEGER). En el mock no se nota, porque
-- alli id_buro_persona va de 9000000 a 9999999 y cabe; contra el datashare
-- real desborda. No se corrige en este commit para no mezclar dos cosas, pero
-- es un defecto abierto de Ubicacion, no una duda.
--
-- NONATOMIC no aplica: esto es DDL. Rollback en
-- RevSQL/34_rollback_ddl_nov_actividad_economica.sql.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;
CREATE SCHEMA IF NOT EXISTS bdm_tempo;

-- ------------------------------------------------------------
-- bdm_tempo.stg_nov_acteco_etapa_1  (legado TMP_PERS_ACTIVIDAD_ECONOMIC)
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
CREATE TABLE IF NOT EXISTS bdm_tempo.stg_nov_acteco_etapa_1 (
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
-- bdm_datos.mat_info_actividad_economica
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
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_actividad_economica (
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
