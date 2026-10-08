-- ============================================================
-- 03_vistas_contacto_canal.sql
-- TEL 4/5/8 | CEL 9 | EMA 10 desde ds_dba_rncr_batch.edf_views
-- ============================================================

DROP VIEW IF EXISTS bdm_tempo.v_xpm_contacto_canal;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_persona_dir_ganadora;

CREATE OR REPLACE VIEW bdm_tempo.v_xpm_contacto_canal AS
SELECT
  ci.id AS cod_dw_persona_ubic,
  FNV_HASH(xpm.pin) AS id_buro_persona,
  CAST(xpm.pin AS BIGINT) AS cod_pin_persona,
  NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') AS contact_type,
  COALESCE(
    NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
    NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '')
  ) AS valor_contacto,
  COALESCE(
    NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedtextoubicacion"::VARCHAR), ''),
    NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
    NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '')
  ) AS texto_ubicacion_vinculo,
  CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), '') ~ '^[0-9]+$'
     AND CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), '') AS BIGINT) <= 2147483647
    THEN CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), '') AS INTEGER)
    ELSE NULL
  END AS cod_dane_ciudad,
  CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacteventlastupdated"::VARCHAR), '') ~ '^[0-9]+$'
    THEN bdm_datos.convert_epoch_to_date(
      CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.contacteventlastupdated"::VARCHAR), '') AS BIGINT)
    )
    ELSE NULL
  END AS fecha_contacto,
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
  ) AS id_buro_suscriptor
FROM ds_dba_rncr_batch.edf_views.xpm xpm
INNER JOIN ds_dba_rncr_batch.edf_views.xpm_location loc
  ON xpm.location = loc.id
INNER JOIN ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations ci
  ON loc."location.val.contactinformations" = ci.id
LEFT JOIN ds_dba_rncr_batch.edf_views.xpm_counterparties cp
  ON xpm.counterparties = cp.id
WHERE NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') IN
  ('1','2','3','4','5','7','8','9','10')
WITH NO SCHEMA BINDING;

-- Personas con DIR ganadora post-unificación (vista; no tabla local)
-- NOTA: tras 04_vistas_sin_copia_productor.sql se redefine sobre v_rpu_post_unificacion
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_persona_dir_ganadora AS
SELECT DISTINCT id_buro_persona
FROM bdm_tempo.v_xpm_relacion_persona_ubicacion rpu
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_datos.unificacion_direccion u
  WHERE u.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
)
WITH NO SCHEMA BINDING;
