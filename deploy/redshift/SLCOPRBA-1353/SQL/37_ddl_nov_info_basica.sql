-- ============================================================
-- 37_ddl_nov_info_basica.sql
-- SLCOPRBA-1399: tabla final del dominio INFO BASICA de Novedades (d4).
-- Quinta MAT, detras de UBICACION, ACTIVIDAD ECONOMICA, UBICACION AGREGADA y
-- CONTACTABILIDAD.
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- UTF-8 sin BOM. Sin acentos a proposito.
--
-- LEGADO: PRO_Novedad_Linea_Info_Basica (Novedad.sql:2166-3920), doce etapas.
-- La carga la hacen los dos TPT, igual que los otros dominios:
--   TMP_INBAS_ETAPA_10
--     -> Vstg_Reconocer_Info_Basica (120.TPT:207-262)
--     -> WHERE Severidad <> -1 (130.TPT:262)
--     -> UPSERT (130.TPT, TablaDestino3)
--
-- EL CONTRATO SON 22 COLUMNAS, y los anchos salen del SCHEMA P0035_10
-- (130.TPT:88-114) menos IN_Severidad, que es decision de carga y no dato.
-- Confirmado ademas por la vista VU_InBas (111.BTQ:539-562), que lista las
-- mismas 22. Mas las tres de trazabilidad que ya llevan las otras MAT.
--
-- SE RESPETAN LOS ANCHOS DEL LEGADO AUNQUE ESCRIBAMOS MENOS. genero va
-- VARCHAR(508) porque asi lo declara el contrato, aunque nuestros valores
-- sean de un caracter: una columna mas ancha de lo necesario no rompe nada y
-- una mas estrecha es un [REDSHIFT:112] que CREATE TABLE IF NOT EXISTS
-- esconde hasta el primer despliegue sobre ambiente limpio.
--
-- ------------------------------------------------------------
-- DOS COLUMNAS CAMBIAN DE TIPO RESPECTO AL LEGADO, Y YA ESTABA DECIDIDO
-- (D-NOV-04): id y cod_pin_persona van BIGINT y no INTEGER. El SCHEMA
-- P0035_10 las declara INTEGER, pero id_buro_persona es FNV_HASH(pin), un
-- hash de 64 bits: con datos reales el cast a INTEGER aborta con "Value out
-- of range for 4 bytes". Es el mismo defecto que ya se corrigio en
-- stg_nov_ubica_etapa_9 y en mat_info_ubicacion.
--
-- ------------------------------------------------------------
-- NO ES UN PORT DE LAS DOCE ETAPAS, Y CONVIENE NO VOLVER A ABRIRLO.
-- El trabajo entero de esas etapas es elegir, por persona, el valor MAS
-- CONFIABLE de cada atributo: arrastran pares de columnas (NOMBRE_1 y
-- NOMBRE_1_2, GENERO y GENERO_2...) y la etapa 9_1 resuelve con
-- COALESCE(valor_2, valor) (Novedad.sql:3447-3466). En EDF esa eleccion YA
-- ESTA HECHA: bestName, bestIdentifications y bestPersonalInformation SON el
-- registro mas confiable. Es la misma forma que la Fase 1 del Ordenamiento.
-- El detalle de la derivacion vive en bdm_tempo.v_xpm_persona_basica
-- (02_vistas_insumo_edf_views.sql).
--
-- ------------------------------------------------------------
-- TRES DE LAS 22 SALEN EN NULL, cada una por su motivo y ninguno es un
-- olvido del port:
--   tipo_identificacion -> falta el catalogo V_Hom_Tip_Ident_Linea (C37). El
--       CODIGO si se puebla (cod_tipo_ident_fte); falta la descripcion
--       homologada. Se desbloquea con el catalogo, sin tocar codigo.
--   pagina_web -> NO EXISTE EN EDF, y esta confirmado: el campo WebSite del
--       contrato Alpha esta marcado "NO APLICA (NO EXISTE CAMPO EN ALPHA)"
--       (Confluence CCBR 251264543, 2026-10-21). No hay nada que pedir.
--   mosaic_id -> Mosaic queda fuera por decision legal (D-NOV-07).
-- Las otras DIECINUEVE se pueblan.
--
-- CONTRATO DE CARGA: FOTO COMPLETA, igual que el AS-IS (111.BTQ:820 hace
-- DELETE ... ALL antes de cargar). Se porta como TRUNCATE + INSERT, y por
-- eso no hay tabla de etapa ni cargador aparte: sin estado previo que
-- comparar, la Severidad del 120.TPT no decide nada.
--
-- DISTKEY id y SORTKEY (id): la llave de la tabla es ID SOLA -- el UPSERT
-- une por STG.ID = B.ID (120.TPT:261-262) -- y es por donde la leera
-- cualquier consumidor que parta de la persona.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- bdm_datos.mat_info_basica  (legado MAT_INFO_BASICA)
-- Las 22 del contrato mas las tres de trazabilidad.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_basica (
  id                              BIGINT,         -- id_buro_persona. BIGINT y no INTEGER: D-NOV-04
  primer_nombre                   VARCHAR(100),
  segundo_nombre                  VARCHAR(100),
  primer_apellido                 VARCHAR(100),
  segundo_apellido                VARCHAR(100),
  nombre_completo                 VARCHAR(200),
  cod_tipo_ident_fte              VARCHAR(20),
  tipo_identificacion             VARCHAR(30),    -- NULL: falta V_Hom_Tip_Ident_Linea (C37)
  numero_identificacion           BIGINT,
  estado_documento                VARCHAR(20),    -- businessidstatus con LPAD a 2 (D-EDF-13)
  rango_edad                      VARCHAR(25),
  lugar_expedicion                VARCHAR(100),
  fecha_expedicion                DATE,
  genero                          VARCHAR(508),   -- M | F | O | vacio (D-EDF-14). Ancho del contrato
  ciiu                            VARCHAR(20),
  actividad_economica             VARCHAR(500),
  razon_social                    VARCHAR(500),   -- derivada: fullname cuando el tipo es NIT
  pagina_web                      VARCHAR(100),   -- NULL: NO EXISTE EN EDF (CCBR 251264543)
  mosaic_id                       INTEGER,        -- NULL: Mosaic fuera por decision legal (D-NOV-07)
  departamento_expedicion         VARCHAR(100),
  cod_pin_persona                 BIGINT,         -- BIGINT y no INTEGER: D-NOV-04
  rut                             VARCHAR(1),
  lote                            INTEGER,
  fecha_actualizacion             TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                      VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (id)
SORTKEY (id);
