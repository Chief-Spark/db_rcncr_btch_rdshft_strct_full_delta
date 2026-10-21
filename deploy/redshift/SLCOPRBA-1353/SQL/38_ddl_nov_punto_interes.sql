-- ============================================================
-- 38_ddl_nov_punto_interes.sql
-- SLCOPRBA-1399: tabla final del dominio PUNTO DE INTERES de Novedades (d7).
-- Sexta MAT, detras de UBICACION, ACTIVIDAD ECONOMICA, UBICACION AGREGADA,
-- CONTACTABILIDAD e INFO BASICA.
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- UTF-8 sin BOM. Sin acentos a proposito.
--
-- LEGADO: PRO_Novedad_Linea_Punto_Interes (Novedad.sql:4585-5031), dos
-- etapas. La carga la hacen los dos TPT:
--   TMP_PINTER_ETAPA_2
--     -> Vstg_Reconocer_Info_PuntoInter (120.TPT:338-369)
--     -> WHERE Severidad <> -1 (130.TPT:331)
--     -> UPSERT (130.TPT, TablaDestino6)
--
-- EL CONTRATO SON 10 COLUMNAS, del SCHEMA P0035_13 (130.TPT:146-159) menos
-- IN_Severidad, que es decision de carga y no dato. Mas las tres de
-- trazabilidad que ya llevan las otras MAT.
--
-- LA LLAVE SON DOS COLUMNAS: (ID, UBICACION_ID). El UPSERT une por las dos
-- (120.TPT:367-368) y las dos etapas del legado llevan
-- PRIMARY INDEX (ID, UBICACION_ID). No es ID sola, al contrario de
-- INFO BASICA.
--
-- ------------------------------------------------------------
-- QUE ES CADA COLUMNA Y DE DONDE SALE. La fuente es nuestra propia
-- bdm_datos.geo_distancias, que es la respuesta de ArcGIS al contrato
-- Salida_Distancias: el legado lee V_RELACION_UBICACION_PUNTO_INT y
-- V_PUNTO_DE_INTERES_GEO, que son la version Teradata del mismo dato.
--
--   id                      FNV_HASH de la llave 1:N del contrato. El legado
--       usa COD_DW_UBIC_PUNTO_INTERES, la llave de la fila de relacion, que
--       no viaja en el contrato de distancias. Se DERIVA de las tres
--       columnas que si viajan y que forman esa misma relacion
--       (cod_dw_ubic, tipo_punto_interes, cod_punto_interes_host), igual que
--       cod_dw_persona_ubic se deriva de (id, index). DIVERGENCIA ANOTADA:
--       el valor no coincide con el de Teradata; la IDENTIDAD de la fila si.
--   nombre                  col08 del contrato. LLEGABA Y SE TIRABA hasta
--       hoy; sp_geo_cargar_distancias.sql lo decia en redondo. Ya se guarda.
--   distancia               col11, metros.
--   descripcion_tipo_punto_interes  col07, EL VALOR CRUDO del contrato. El
--       legado pone aqui la descripcion del catalogo V_TIPO_PUNTO_INTERES,
--       que no tenemos. DIVERGENCIA: mismo campo, valor sin homologar.
--   ubicacion_id            cod_dw_ubic. OJO: es la UBICACION y no la
--       relacion persona-ubicacion. El legado lo toma de
--       TMP_UBICA_ETAPA_9 agrupado por COD_DW_UBIC (Novedad.sql:4807), no de
--       su columna ID.
--   latitud / longitud      col09 y col10, las del PUNTO DE INTERES y no las
--       de la ubicacion. El legado las toma de PDIG, la vista del punto.
--   tipo                    NULL. Falta V_Hom_Tipo_Pto_Int_Linea, el
--       catalogo de homologacion que el legado cruza por
--       Cod_Tipo_Punto_Interes_Host (Novedad.sql:4888-4890).
--   nombre_entidad          NULL. Sale de RELACION_PUNTO_INTERES_X_PERS
--   nit_entidad             NULL. (NOMBRE_SUSCRIPTOR y NUM_IDENT,
--       Novedad.sql:4801-4802), una tabla que no existe de este lado y que no
--       esta en el contrato de distancias. Es peticion, no codigo.
--
-- SIETE DE LAS DIEZ SE POBLAN. Las tres en NULL lo hacen por falta de fuente,
-- no por omision, y NULL y no un valor por defecto: la distincion de las
-- columnas por_* del censo de Ordenamiento (F1-08) y de NOV-UB-12.
--
-- ------------------------------------------------------------
-- CONTRATO DE CARGA: FOTO COMPLETA, igual que el AS-IS (111.BTQ:820 hace
-- DELETE ... ALL antes de cargar). TRUNCATE + INSERT, y por eso no hay tabla
-- de etapa ni cargador aparte.
--
-- DISTKEY ubicacion_id y SORTKEY (ubicacion_id, id): de las dos columnas de
-- la llave, ubicacion_id es la que reparte -- hay muchos puntos por
-- ubicacion y no al contrario -- y es por donde se une a las ubicaciones.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- bdm_datos.mat_info_punto_interes  (legado MAT_INFO_PUNTO_INTERES)
-- Las 10 del contrato mas las tres de trazabilidad.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_punto_interes (
  id                               BIGINT,         -- derivada: FNV_HASH de la llave 1:N
  nombre                           VARCHAR(200),
  distancia                        INTEGER,        -- metros
  descripcion_tipo_punto_interes   VARCHAR(1000),  -- valor CRUDO: falta V_TIPO_PUNTO_INTERES
  ubicacion_id                     BIGINT,         -- cod_dw_ubic, NO la relacion persona-ubicacion
  nombre_entidad                   VARCHAR(1000),  -- NULL: falta RELACION_PUNTO_INTERES_X_PERS
  nit_entidad                      VARCHAR(20),    -- NULL: idem
  latitud                          VARCHAR(40),    -- del PUNTO DE INTERES. VARCHAR por el contrato
  longitud                         VARCHAR(40),    -- idem
  tipo                             VARCHAR(30),    -- NULL: falta V_Hom_Tipo_Pto_Int_Linea
  lote                             INTEGER,
  fecha_actualizacion              TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                       VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (ubicacion_id)
SORTKEY (ubicacion_id, id);
