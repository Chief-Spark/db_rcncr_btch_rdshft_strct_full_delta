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
  ) AS id_buro_suscriptor,
  -- SLCOPRBA-1355: el codigo de suscriptor EN CRUDO, aparte de
  -- id_buro_suscriptor. Las dos columnas NO son la misma cosa: id_buro_suscriptor
  -- es un COALESCE cuyo ultimo recurso es una cubeta de hash
  -- (MOD(ABS(FNV_HASH(...)), 9998) + 1), y un hash no tiene prefijo de
  -- industria. El clasificador Portafolio_Nuevo del legado parte del PREFIJO
  -- DE DOS DIGITOS de este codigo (PRO_ORD_CTA_TOTALES_PERSONAS_2.sql:378-389),
  -- asi que necesita el valor real o nada.
  --   VARCHAR(20) y no INTEGER: el legado le aplica SUBSTR(cod_suscriptor,1,2),
  --   que es semantica de caracter, y castear repetiria el job #293.
  --   Es NULL cuando el datashare no trae el dato, y entonces el portafolio
  --   cae a 'OT', que es la rama ELSE del legado.
  CAST(NULLIF(TRIM(loc."location.val.counterpartyidnumber"::VARCHAR), '') AS VARCHAR(20))
    AS cod_suscriptor,
  -- SLCOPRBA-1355: el tipo de cuenta que reporto este contacto.
  -- El legado lo trae a la fila de contacto con un join por Cod_DW_Cta
  -- (Caracteristicas.txt:112). Aqui ese join NO hace falta: una fila de
  -- xpm_location YA ES "este suscriptor reporto este contacto para esta
  -- cuenta", que es el mismo grano que el legado consigue uniendo.
  --
  -- VARCHAR(20), NO INTEGER, por dos razones. En el legado la columna es de
  -- caracter -- todas sus referencias la envuelven en CAST(... AS INTEGER),
  -- y una de las cinco ramas de CO01EMA021 (Caracteristicas.txt:235) la
  -- compara en texto crudo contra '23'. Y porque castear aqui repetiria el
  -- job #293: un valor de mas de 10 digitos aborta con "Value out of range
  -- for 4 bytes" aunque pase el guardia de solo-digitos (ver la nota de
  -- personidtype en 02_vistas_insumo_edf_views.sql:89-98).
  -- Consumidores: CO01CEL019 (via catalogo_tipo_cuenta_ord) y CO01EMA021.
  CAST(NULLIF(TRIM(loc."location.val.accounttype"::VARCHAR), '') AS VARCHAR(20))
    AS cod_tipo_cta_fte
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
