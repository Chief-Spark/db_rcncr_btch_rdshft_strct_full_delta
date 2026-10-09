-- ============================================================
-- 00_vistas_insumo_bdm.sql  (DEV / edf_views)
-- Capa XPM edf_views â†’ insumo BDM para UnificaciÃ³n R1/R2/R3
-- Diferencia vs ifr_data: sin columna relationalizelastupdate en JOINs
-- Sanitiza strings vacÃ­os / IDs fuera de rango INTEGER (edf_views DEV)
-- ============================================================

DROP VIEW IF EXISTS bdm_tempo.v_xpm_ciiu_persona;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_reporte_relacion_persona_ubica;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_direccion_fisica;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_ubicacion_estandarizada;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_relacion_persona_ubicacion;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_contacto_direccion;

CREATE OR REPLACE VIEW bdm_tempo.v_xpm_contacto_direccion AS
SELECT
  xpm.pin,
  CAST(NULL AS BIGINT)              AS relationalizelastupdate,
  loc.id                            AS cod_dw_ubic,
  ci.id                             AS cod_dw_persona_ubic,
  ci.id                             AS cod_dw_direccion_fisica,
  FNV_HASH(xpm.pin)                 AS id_buro_persona,
  CAST(xpm.pin AS BIGINT)           AS cod_pin_persona,
  CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') = '8' THEN 3
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') ~ '^[0-9]+$'
    THEN CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') AS INTEGER)
    ELSE NULL
  END AS cod_dw_tipo_ubicacion_dir,
  COALESCE(
    NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedtextoubicacion"::VARCHAR), ''),
    NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
    NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '')
  ) AS texto_ubicacion,
  COALESCE(
    NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
    NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedtextoubicacion"::VARCHAR), ''),
    NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '')
  ) AS texto_ubicacion_normalizado,
  NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '') AS texto_ubicacion_original,
  CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contactasstandardizedscore"::VARCHAR), '') ~ '^[0-9]+(\.[0-9]+)?$'
    THEN CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.contactasstandardizedscore"::VARCHAR), '') AS DECIMAL(5,4))
    ELSE NULL
  END AS score_estandarizacion,
  CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), '') ~ '^[0-9]+$'
     AND CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), '') AS BIGINT) <= 2147483647
    THEN CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), '') AS INTEGER)
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.cityname"::VARCHAR), '') IS NOT NULL
    THEN MOD(ABS(FNV_HASH(UPPER(TRIM(ci."location.val.contactinformations.val.cityname"::VARCHAR)))), 99999999)
    ELSE NULL
  END AS cod_dw_ciudad,
  COALESCE(
    NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddepartment"::VARCHAR), ''),
    NULLIF(TRIM(ci."location.val.contactinformations.val.statename"::VARCHAR), '')
  ) AS departamento,
  COALESCE(
    NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedmunicipality"::VARCHAR), ''),
    NULLIF(TRIM(ci."location.val.contactinformations.val.cityname"::VARCHAR), '')
  ) AS municipio,
  ci."location.val.contactinformations.val.standardizedtipo"               AS tipo_ubicacion,
  NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedcomplemento"::VARCHAR), '') AS complemento,
  ci."location.val.contactinformations.val.standardizedtipoviaprincipal"   AS tipo_via_principal,
  ci."location.val.contactinformations.val.standardizedviaprincipal"       AS via_principal,
  ci."location.val.contactinformations.val.standardizedviageneradora"      AS via_generadora,
  ci."location.val.contactinformations.val.standardizednumeropuerta"       AS numero_puerta,
  CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacteventlastupdated"::VARCHAR), '') ~ '^[0-9]+$'
    THEN bdm_datos.convert_epoch_to_date(
      CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.contacteventlastupdated"::VARCHAR), '') AS BIGINT)
    )
    ELSE NULL
  END AS fecha_relacion_persona_ubicaci,
  CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contactfirsteventdate"::VARCHAR), '') ~ '^[0-9]+$'
    THEN bdm_datos.convert_epoch_to_date(
      CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.contactfirsteventdate"::VARCHAR), '') AS BIGINT)
    )
    ELSE NULL
  END AS fecha_primera_relacion,
  CAST(NULL AS DECIMAL(10,6)) AS latitud,
  CAST(NULL AS DECIMAL(10,6)) AS longitud,
  CASE
    WHEN NULLIF(TRIM(loc."location.val.personidtype"::VARCHAR), '') ~ '^[0-9]+$'
    THEN CAST(NULLIF(TRIM(loc."location.val.personidtype"::VARCHAR), '') AS INTEGER)
    ELSE NULL
  END AS cod_tipo_ident_fte,
  CAST(NULL AS INTEGER) AS lote
FROM ds_dba_rncr_batch.edf_views.xpm xpm
INNER JOIN ds_dba_rncr_batch.edf_views.xpm_location loc
  ON xpm.location = loc.id
INNER JOIN ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations ci
  ON loc."location.val.contactinformations" = ci.id
WHERE NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') IN ('1', '2', '3', '7', '8')
WITH NO SCHEMA BINDING;

-- SLCOPRBA-1354 (M2): la vista pasa a ser UNION ALL del datashare con las
-- RPU sinteticas que produce el motor de Regla 2. Mismo patron que
-- bdm_datos.geo_atributos: una tabla local suple lo que el datashare, de solo
-- lectura, no deja escribir. Sin esto, el motor persistiria en un catalogo que
-- ningun consumidor leeria.
-- Se filtra fecha_inactivacion IS NULL: una direccion generada se puede retirar
-- de circulacion sin borrar el historico (el legado contempla esa columna en su
-- INSERT a DIRECCION_FISICA).
-- IMPORTANTE: orden_prioridad se calcula AHORA SOBRE LA UNION, no por rama. La
-- direccion generada participa del orden de prioridad de la persona, que es
-- justo lo que la hace util aguas abajo (Ordenamiento).
-- ind_unificacion sigue llegando como constante NULL desde el datashare, pero
-- de rpu_generada llega el valor REAL de la tabla.
-- SLCOPRBA-1354 (M7): ind_unificacion se DERIVA de bdm_datos.unificacion_direccion.
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
-- solo si aparece como HIJA en bdm_datos.unificacion_direccion, que es exactamente el
-- conjunto que el TPT marca. Se deriva, y asi no hay una segunda fuente de
-- verdad que se pueda desincronizar.
--
-- El reset del FULL sale gratis: el orquestador ya trunca bdm_datos.unificacion_direccion
-- en su paso 6, antes de preparar el insumo, de modo que un FULL ve el estado
-- vacio y re-procesa todo.
--
-- Da 1 o NULL, no 1 o 0: el filtro del insumo es IS NULL, igual que el legado.
-- DISTINCT en el subquery: la Clave_Unificacion es el PAR
-- (cod_dw_persona_ubic, cod_dw_direccion_unificada), asi que una misma
-- direccion puede tener mas de una fila y un join directo DUPLICARIA el insumo.
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_relacion_persona_ubicacion AS
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
    cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir,
    CAST(NULL AS INTEGER) AS ind_unificacion,
    fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte,
    CAST(0 AS SMALLINT)   AS bloqueado
  FROM bdm_tempo.v_xpm_contacto_direccion
  UNION ALL
  SELECT
    cod_dw_persona_ubic, id_buro_persona, cod_pin_persona, cod_dw_ubic,
    cod_dw_direccion_fisica, cod_dw_tipo_ubicacion_dir,
    ind_unificacion,
    fecha_relacion_persona_ubicaci, lote, cod_tipo_ident_fte,
    CAST(0 AS SMALLINT)   AS bloqueado
  FROM bdm_datos.rpu_generada
  WHERE fecha_inactivacion IS NULL
) rpu_u
LEFT JOIN ( SELECT DISTINCT cod_dw_persona_ubic
              FROM bdm_datos.unificacion_direccion ) est
       ON est.cod_dw_persona_ubic = rpu_u.cod_dw_persona_ubic
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_xpm_ubicacion_estandarizada AS
SELECT DISTINCT
  cod_dw_ubic,
  texto_ubicacion,
  texto_ubicacion_normalizado,
  texto_ubicacion_original,
  score_estandarizacion,
  cod_dw_ciudad,
  cod_dw_ciudad AS cod_dw_municipio,
  departamento,
  municipio,
  tipo_ubicacion,
  cod_dw_tipo_ubicacion_dir AS cod_dw_tipo_ubicacion,
  latitud,
  longitud
FROM bdm_tempo.v_xpm_contacto_direccion
WITH NO SCHEMA BINDING;

-- SLCOPRBA-1354 (M2): la vista pasa a ser UNION ALL del datashare con las
-- direcciones generadas que produce el motor de Regla 2. Mismo patron que
-- bdm_datos.geo_atributos: una tabla local suple lo que el datashare, de solo
-- lectura, no deja escribir. Sin esto, el motor persistiria en un catalogo que
-- ningun consumidor leeria.
-- Se filtra fecha_inactivacion IS NULL: una direccion generada se puede retirar
-- de circulacion sin borrar el historico (el legado contempla esa columna en su
-- INSERT a DIRECCION_FISICA).
-- generada_enriquecida deja de ser constante 0: vale 0 para lo que viene del
-- datashare y 1 para lo que creo el motor, que es la semantica del legado
-- (Generada_Enriquecida en DIRECCION_FISICA).
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_direccion_fisica AS
SELECT DISTINCT
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
    cod_dw_direccion_fisica, complemento, tipo_via_principal, via_principal,
    via_generadora, numero_puerta, cod_dw_ubic,
    CAST(0 AS INTEGER) AS generada_enriquecida
  FROM bdm_tempo.v_xpm_contacto_direccion
  UNION ALL
  SELECT
    cod_dw_direccion_fisica, complemento, tipo_via_principal, via_principal,
    via_generadora, numero_puerta, cod_dw_ubic,
    COALESCE(generada_enriquecida, 1) AS generada_enriquecida
  FROM bdm_datos.direccion_fisica_generada
  WHERE fecha_inactivacion IS NULL
) df_u
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_xpm_reporte_relacion_persona_ubica AS
SELECT
  ci.id AS cod_dw_persona_ubic,
  COALESCE(
    CASE
      WHEN NULLIF(TRIM(cp."counterparties.val.counterpartyidnumber"::VARCHAR), '') ~ '^[0-9]+$'
       AND CAST(NULLIF(TRIM(cp."counterparties.val.counterpartyidnumber"::VARCHAR), '') AS BIGINT) <= 2147483647
      THEN CAST(NULLIF(TRIM(cp."counterparties.val.counterpartyidnumber"::VARCHAR), '') AS INTEGER)
      ELSE NULL
    END,
    CASE
      WHEN NULLIF(TRIM(loc."location.val.counterpartyidnumber"::VARCHAR), '') ~ '^[0-9]+$'
       AND CAST(NULLIF(TRIM(loc."location.val.counterpartyidnumber"::VARCHAR), '') AS BIGINT) <= 2147483647
      THEN CAST(NULLIF(TRIM(loc."location.val.counterpartyidnumber"::VARCHAR), '') AS INTEGER)
      ELSE NULL
    END,
    MOD(ABS(FNV_HASH(xpm.pin || ':' || ci.id::VARCHAR)), 9998) + 1
  ) AS id_buro_suscriptor,
  CASE
    WHEN NULLIF(TRIM(loc."location.val.cutoffdate"::VARCHAR), '') ~ '^[0-9]+$'
    THEN bdm_datos.convert_epoch_to_date(
      CAST(NULLIF(TRIM(loc."location.val.cutoffdate"::VARCHAR), '') AS BIGINT)
    )
    ELSE CURRENT_DATE
  END AS fecha_reporte
FROM ds_dba_rncr_batch.edf_views.xpm xpm
INNER JOIN ds_dba_rncr_batch.edf_views.xpm_location loc
  ON xpm.location = loc.id
INNER JOIN ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations ci
  ON loc."location.val.contactinformations" = ci.id
LEFT JOIN ds_dba_rncr_batch.edf_views.xpm_counterparties cp
  ON xpm.counterparties = cp.id
WHERE NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') IN ('1', '2', '3', '7', '8')
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_xpm_ciiu_persona AS
SELECT DISTINCT
  FNV_HASH(xpm.pin) AS id_buro_persona,
  NULLIF(TRIM(xpm."bestpersonalinformation.mainisiccodeforproduct"::VARCHAR), '') AS cod_act_econo_ciiu_fte
FROM ds_dba_rncr_batch.edf_views.xpm xpm
WHERE NULLIF(TRIM(xpm."bestpersonalinformation.mainisiccodeforproduct"::VARCHAR), '') IS NOT NULL
WITH NO SCHEMA BINDING;

