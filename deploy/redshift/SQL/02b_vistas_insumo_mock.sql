-- ============================================================
-- 02b_vistas_insumo_mock.sql
-- Insumo MOCK para SPs sp_unificacion_mock_*
-- Fuente: bdm_stage (seed / suite TC) — NO lee edf_views / DS real
-- Los SPs reales siguen en 02_vistas_insumo_edf_views.sql (v_xpm_*)
-- ============================================================

DROP VIEW IF EXISTS bdm_tempo.v_mock_contacto_canal;
DROP VIEW IF EXISTS bdm_tempo.v_mock_contacto_direccion;
DROP VIEW IF EXISTS bdm_tempo.v_mock_ciiu_persona;
DROP VIEW IF EXISTS bdm_tempo.v_mock_reporte_relacion_persona_ubica;
DROP VIEW IF EXISTS bdm_tempo.v_mock_direccion_fisica;
DROP VIEW IF EXISTS bdm_tempo.v_mock_ubicacion_estandarizada;
DROP VIEW IF EXISTS bdm_tempo.v_mock_relacion_persona_ubicacion;

-- SLCOPRBA-1354 (M2): UNION ALL con las RPU sinteticas que produce el motor,
-- espejo de lo que hace v_xpm_relacion_persona_ubicacion con rpu_generada.
-- CAMBIO DE COMPORTAMIENTO DELIBERADO: orden_prioridad deja de leerse de
-- bdm_stage y pasa a calcularse con ROW_NUMBER SOBRE LA UNION, igual que en la
-- vista real. Antes el mock honraba el valor sembrado y el real lo calculaba:
-- eran dos semanticas distintas. Ningun consumidor de la cadena depende de ese
-- valor (R1 calcula su propio ROW_NUMBER y el Ordenamiento toma el suyo de
-- rpu_orden_prioridad), de modo que el cambio alinea sin romper nada.
-- SLCOPRBA-1354 (M7): ind_unificacion se DERIVA de bdm_datos.unificacion_direccion_mock.
--
-- Antes la rama del datashare lo exponia como CAST(NULL AS INTEGER), es decir
-- "nada esta unificado nunca", y el filtro de estado del insumo
-- (ind_unificacion IS NULL, el del legado en V_Insumo_Unificacion_Regla1) no
-- filtraba nada: cada DELTA re-procesaba todo lo ya unificado.
--
-- El legado marca el estado con la quinta pasada del TPT
-- (P0020_UNIFICACION_DIRECCION_130.TPT, lineas 281-292):
--     UPDATE <RELACION_PERSONA_UBICACION> SET IND_UNIFICACION = 1
-- sobre las filas que acaba de unificar. En el consumidor no se puede escribir
-- la tabla del PRODUCTOR -- los objetos de un datashare son de solo lectura --
-- pero el estado no hace falta almacenarlo: una direccion esta unificada si y
-- solo si aparece como HIJA en bdm_datos.unificacion_direccion_mock, que es exactamente el
-- conjunto que el TPT marca. Se deriva, y asi no hay una segunda fuente de
-- verdad que se pueda desincronizar.
--
-- El reset del FULL sale gratis: el orquestador ya trunca bdm_datos.unificacion_direccion_mock
-- en su paso 6, antes de preparar el insumo, de modo que un FULL ve el estado
-- vacio y re-procesa todo.
--
-- Da 1 o NULL, no 1 o 0: el filtro del insumo es IS NULL, igual que el legado.
-- DISTINCT en el subquery: la Clave_Unificacion es el PAR
-- (cod_dw_persona_ubic, cod_dw_direccion_unificada), asi que una misma
-- direccion puede tener mas de una fila y un join directo DUPLICARIA el insumo.
CREATE OR REPLACE VIEW bdm_tempo.v_mock_relacion_persona_ubicacion AS
SELECT
  rpu_u.cod_dw_persona_ubic,
  rpu_u.id_buro_persona,
  rpu_u.cod_pin_persona,
  rpu_u.cod_dw_ubic,
  rpu_u.cod_dw_direccion_fisica,
  rpu_u.cod_dw_tipo_ubicacion_dir,
  -- Derivado O almacenado, en ese orden. El almacenado importa en las dos
  -- vias: en mock es el que siembra la matriz (la posicion YA_UNIF marca con
  -- 1 la ultima direccion del grupo y es lo que la hace funcionar), y en real
  -- es el de rpu_generada. La rama del datashare aporta NULL, asi que alli
  -- manda la derivacion.
  CASE WHEN est.cod_dw_persona_ubic IS NOT NULL THEN 1
       ELSE rpu_u.ind_unificacion END AS ind_unificacion,
  ROW_NUMBER() OVER (
    PARTITION BY rpu_u.id_buro_persona, rpu_u.cod_dw_ubic, rpu_u.cod_dw_tipo_ubicacion_dir
    ORDER BY rpu_u.fecha_relacion_persona_ubicaci DESC NULLS LAST, rpu_u.cod_dw_persona_ubic
  ) AS orden_prioridad,
  rpu_u.fecha_relacion_persona_ubicaci,
  rpu_u.lote,
  rpu_u.cod_tipo_ident_fte,
  rpu_u.bloqueado
FROM (
  SELECT
    cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
    cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
    fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte,
    CAST(0 AS SMALLINT) AS bloqueado
  FROM bdm_stage.relacion_persona_ubicacion
  UNION ALL
  SELECT
    cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
    cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir, ind_unificacion,
    fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte,
    CAST(0 AS SMALLINT) AS bloqueado
  FROM bdm_datos.rpu_generada_mock
  WHERE fecha_inactivacion IS NULL
) rpu_u
LEFT JOIN ( SELECT DISTINCT cod_dw_persona_ubic
              FROM bdm_datos.unificacion_direccion_mock ) est
       ON est.cod_dw_persona_ubic = rpu_u.cod_dw_persona_ubic
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_mock_ubicacion_estandarizada AS
SELECT
  cod_dw_ubic,
  texto_ubicacion,
  texto_ubicacion AS texto_ubicacion_normalizado,
  texto_ubicacion AS texto_ubicacion_original,
  CAST(NULL AS DECIMAL(5,4)) AS score_estandarizacion,
  cod_dw_ciudad,
  cod_dw_ciudad AS cod_dw_municipio,
  departamento,
  municipio,
  CAST(NULL AS VARCHAR(50)) AS tipo_ubicacion,
  CAST(NULL AS INTEGER) AS cod_dw_tipo_ubicacion,
  latitud,
  longitud
FROM bdm_stage.ubicacion_estandarizada
WITH NO SCHEMA BINDING;

-- SLCOPRBA-1354 (M2): UNION ALL con las direcciones que produce el motor.
-- Las columnas de via siguen siendo NULL en la rama de semillas (bdm_stage no
-- las almacena) pero SI llegan con valor desde direccion_fisica_generada_mock,
-- que las hereda de la direccion de origen igual que el real.
CREATE OR REPLACE VIEW bdm_tempo.v_mock_direccion_fisica AS
SELECT
  cod_dw_direccion_fisica,
  complemento,
  tipo_via_principal,
  via_principal,
  via_generadora,
  numero_puerta,
  cod_dw_ubic,
  generada_enriquecida
FROM (
  SELECT
    cod_dw_direccion_fisica,
    complemento,
    CAST(NULL AS VARCHAR(50))  AS tipo_via_principal,
    CAST(NULL AS VARCHAR(100)) AS via_principal,
    CAST(NULL AS VARCHAR(100)) AS via_generadora,
    CAST(NULL AS VARCHAR(50))  AS numero_puerta,
    cod_dw_ubic,
    COALESCE(generada_enriquecida, 0) AS generada_enriquecida
  FROM bdm_stage.direccion_fisica
  UNION ALL
  SELECT
    cod_dw_direccion_fisica,
    complemento,
    tipo_via_principal,
    via_principal,
    via_generadora,
    numero_puerta,
    cod_dw_ubic,
    COALESCE(generada_enriquecida, 1) AS generada_enriquecida
  FROM bdm_datos.direccion_fisica_generada_mock
  WHERE fecha_inactivacion IS NULL
) df_u
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_mock_reporte_relacion_persona_ubica AS
SELECT
  cod_dw_persona_ubic,
  id_buro_suscriptor,
  fecha_reporte
FROM bdm_stage.reporte_relacion_persona_ubica
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_mock_ciiu_persona AS
SELECT
  id_buro_persona,
  cod_act_econo_ciiu_fte
FROM bdm_stage.ciiu_persona
WITH NO SCHEMA BINDING;

-- ============================================================
-- SLCOPRBA-1355: espejos mock de las dos vistas base que consume el
-- Ordenamiento (sp_ordenamiento_preparar_insumos_*). Exponen EXACTAMENTE los
-- mismos nombres de columna que v_xpm_contacto_direccion y v_xpm_contacto_canal
-- para que el preparar mock materialice las mismas tablas de staging y los SP
-- de scoring / consolidacion REALES corran sobre datos mock sin modificacion.
-- Las columnas que el stage mock no almacena se exponen como NULL casteado, de
-- modo que el SELECT cd.* de stg_contacto_direccion_rpu conserve la forma.
-- ============================================================

CREATE OR REPLACE VIEW bdm_tempo.v_mock_contacto_direccion AS
SELECT
  CAST(rpu.cod_pin_persona AS VARCHAR(50))   AS pin,
  CAST(NULL AS BIGINT)                       AS relationalizelastupdate,
  rpu.cod_dw_ubic,
  rpu.cod_dw_persona_ubic,
  rpu.cod_dw_direccion_fisica,
  rpu.id_buro_persona,
  rpu.cod_pin_persona,
  rpu.cod_dw_tipo_ubicacion_dir,
  ubi.texto_ubicacion,
  ubi.texto_ubicacion                        AS texto_ubicacion_normalizado,
  ubi.texto_ubicacion                        AS texto_ubicacion_original,
  CAST(NULL AS DECIMAL(5,4))                 AS score_estandarizacion,
  ubi.cod_dw_ciudad,
  ubi.departamento,
  ubi.municipio,
  CAST(NULL AS VARCHAR(50))                  AS tipo_ubicacion,
  df.complemento,
  CAST(NULL AS VARCHAR(50))                  AS tipo_via_principal,
  CAST(NULL AS VARCHAR(100))                 AS via_principal,
  CAST(NULL AS VARCHAR(100))                 AS via_generadora,
  CAST(NULL AS VARCHAR(50))                  AS numero_puerta,
  rpu.fecha_relacion_persona_ubicaci,
  rpu.fecha_relacion_persona_ubicaci         AS fecha_primera_relacion,
  ubi.latitud,
  ubi.longitud,
  rpu.cod_tipo_ident_fte,
  rpu.lote
FROM bdm_stage.relacion_persona_ubicacion rpu
JOIN bdm_stage.ubicacion_estandarizada ubi
  ON rpu.cod_dw_ubic = ubi.cod_dw_ubic
LEFT JOIN bdm_stage.direccion_fisica df
  ON rpu.cod_dw_direccion_fisica = df.cod_dw_direccion_fisica
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_mock_contacto_canal AS
SELECT
  cod_dw_persona_ubic,
  id_buro_persona,
  cod_pin_persona,
  contact_type,
  valor_contacto,
  texto_ubicacion_vinculo,
  cod_dane_ciudad,
  fecha_contacto,
  id_buro_suscriptor
FROM bdm_stage.contacto_canal
WITH NO SCHEMA BINDING;
