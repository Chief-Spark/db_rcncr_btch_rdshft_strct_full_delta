-- ============================================================
-- 36_ddl_nov_contactabilidad.sql
-- SLCOPRBA-1399: tabla final del dominio CONTACTABILIDAD de Novedades.
-- Cuarta MAT, detras de UBICACION, ACTIVIDAD ECONOMICA y UBICACION AGREGADA.
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- UTF-8 sin BOM. Sin acentos a proposito.
--
-- LEGADO: PRO_Novedad_Linea_Contact (Novedad.sql:186-1059), siete etapas
-- encadenadas. La carga la hacen los dos TPT, igual que los otros dominios:
--   TMP_HIST_ETAPA_7
--     -> Vstg_Reconocer_Info_Contacto (120.TPT:266-305)
--     -> WHERE Severidad <> -1 (130.TPT:285)
--     -> UPSERT (130.TPT:854-918, TablaDestino4)
--
-- EL CONTRATO SON 12 COLUMNAS, y las confirman tres listas independientes:
--   la vista VU_Contact (111.BTQ:540-552), la vista de staging
--   (120.TPT:270-282, menos Severidad, que es decision de carga y no dato) y
--   la lista del INSERT del UPSERT (130.TPT:877-890). Mas las tres de
--   trazabilidad que ya llevan las otras MAT de este repo.
--   El orden fisico NO esta confirmado: el 111.BTQ pone los dos
--   MEJOR_RESULTADO antes de REPORTADO_POR y el INSERT del 130.TPT los pone
--   al final. Se adopta el orden del INSERT, que es el que carga.
--
-- ------------------------------------------------------------
-- DIEZ DE LAS DOCE COLUMNAS SALEN EN NULL, Y NO ES UN DEFECTO DEL PORT:
-- NO EXISTE LA FUENTE. Esto es D-NOV-08 y conviene leerlo antes de abrir
-- trabajo sobre esta tabla.
--
-- Las doce columnas son el resumen de un HECHO -- la gestion de contacto:
-- alguien llamo a ese numero tal dia a tal hora y paso tal cosa -- que en
-- Teradata entra entero por REC_VISTA.V_CONTACTABILIDAD, una de las SEIS
-- fuentes del buro (V_Fuente, Cod_Dw_Fuente = 31937). En Redshift no hay
-- nada equivalente:
--   1. no esta en el datashare: buscado en svv_all_columns de
--      ds_dba_rncr_batch.edf_views por contact, gestion, effect, result,
--      call y attempt;
--   2. no esta en la documentacion de EDF: la seccion contactInformations
--      del contrato Alpha tiene NUEVE campos y los nueve son el dato de
--      contacto, ninguno la gestion sobre el dato (Confluence CCBR,
--      pagina 251264536, consultada el 2026-10-21);
--   3. el cargador de la fuente 31937 no esta en el material entregado.
-- Detalle y el texto de la peticion en dt/docs/PETICION_CATALOGOS_NOVEDADES.md.
--
-- ------------------------------------------------------------
-- LAS DOS QUE SI SE POBLAN LO HACEN CON UN EQUIVALENTE DE OTRA SEMANTICA.
-- DECISION DEL USUARIO, 2026-10-21. Es una divergencia asumida, no un
-- hallazgo: se escribe aqui para que nadie la lea como paridad.
--
--   fecha_ultimo_contacto  <- ContactEventLastUpdated
--       El legado pone MAX(FECHA_GESTION): la ultima vez que ALGUIEN CONTACTO
--       esa ubicacion. Nosotros ponemos la ultima vez que SE ACTUALIZO EL
--       DATO de contacto. Son dos cosas distintas y la segunda no implica la
--       primera: un telefono puede reportarse cien veces sin que nadie lo
--       haya marcado nunca.
--
--   reportado_por          <- id_buro_suscriptor del reporte
--       El legado pone CTB.ID_BURO_SUSCRIPTOR: quien GESTIONO
--       (Novedad.sql:598). Nosotros ponemos quien REPORTO la ubicacion.
--
-- Quien consuma esta tabla tiene que saber que esas dos columnas NO hablan
-- de gestion. Las otras diez en NULL son la senal honesta de que el hecho no
-- se midio -- NULL dice "no hay con que medir" y un 'NO' en
-- contactabilidad diria "se intento y no se pudo", que es falso. Es la misma
-- distincion de las cuatro columnas por_* del censo de Ordenamiento (F1-08)
-- y la de NOV-UB-12.
--
-- ------------------------------------------------------------
-- NO HAY TABLA DE ETAPA, Y ES DELIBERADO. Los otros tres dominios pinan su
-- ultima etapa porque es el traspaso del SP al cargador y el tipo tiene que
-- ser contrato. Aqui no hay cascada que traspasar: las siete etapas del
-- legado existen para resumir eventos de gestion y sin eventos no hay nada
-- que resumir. El SP escribe la tabla final de una sola pasada.
--
-- CONTRATO DE CARGA: FOTO COMPLETA, igual que el AS-IS. El 111.BTQ:820 hace
-- DELETE ... ALL antes de cargar, de modo que el UPSERT del 130.TPT opera
-- siempre sobre una tabla vacia. Se porta como TRUNCATE + INSERT.
--
-- ------------------------------------------------------------
-- DISTKEY ubicacion_id y SORTKEY (ubicacion_id): la llave del legado es
-- (ID, SECTOR, UBICACION_ID) -- PRIMARY INDEX de Novedad.sql:885 y predicado
-- del UPSERT en 130.TPT:871-873 -- y de las tres la unica que tiene valor en
-- esta via es ubicacion_id, que es ademas por donde se une a la etapa 9.
-- DISTSTYLE KEY y no ALL: la tabla tiene el orden de magnitud de las
-- ubicaciones del universo, no es pequena.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- bdm_datos.mat_info_contactabilidad  (legado MAT_INFO_CONTACTABILIDAD)
-- Las 12 del contrato mas las tres de trazabilidad.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_contactabilidad (
  id                              BIGINT,         -- NULL: es COD_DW_CONTACTABILIDAD, la llave del evento de gestion
  contactabilidad                 VARCHAR(2),     -- NULL: necesita V_CONTACTO_EFECTIVO y el indicador de efectividad
  fecha_ultimo_contacto           TIMESTAMP,      -- SI se puebla, con OTRA semantica: ContactEventLastUpdated
  fecha_gestion                   TIMESTAMP,      -- NULL: no hay eventos de gestion
  mejor_dia_gestion               VARCHAR(10),    -- NULL: se deriva de fecha_gestion
  mejor_hora_gestion              VARCHAR(20),    -- NULL: pide hora del dia, que EDF no trae
  reportado_por                   INTEGER,        -- SI se puebla, con OTRA semantica: quien REPORTO, no quien gestiono
  sector                          VARCHAR(100),   -- NULL: falta V_PERSONA_CLASE_BURO y v_clase_buro
  ubicacion_id                    BIGINT,         -- SI se puebla: cod_dw_persona_ubic
  peso                            BIGINT,         -- NULL: es COUNT(*) de eventos de gestion
  mejor_resultado_3meses          VARCHAR(100),   -- NULL: codigo GESTION de la ventana de 3 meses
  mejor_resultado_6meses          VARCHAR(100),   -- NULL: idem, 6 meses
  lote                            INTEGER,
  fecha_actualizacion             TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                      VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (ubicacion_id)
SORTKEY (ubicacion_id);
