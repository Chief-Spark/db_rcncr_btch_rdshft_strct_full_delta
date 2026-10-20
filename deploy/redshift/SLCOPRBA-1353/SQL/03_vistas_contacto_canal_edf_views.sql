-- ============================================================
-- 03_vistas_contacto_canal.sql
-- Canales desde ds_dba_rncr_batch.edf_views, en la columna canal:
--   DIR 1/2/3/7/8 | TEL 4/5 y el 6 fijo | CEL 9 y el 6 celular | EMA 10
-- 2026-10-20, medido en DEV y QA (docs/edf_views/RESULTADOS_CONSULTAS_EDF.md
-- secciones 14 y 15): el 8 es direccion (D-EDF-08), el 10 es correo (100 %
-- con arroba), el 6 es el telefono de la fuente 6 (D-EDF-11) y el 11 viene
-- vacio y no se lee. Falta el catalogo contacttype para confirmarlo.
-- ============================================================

DROP VIEW IF EXISTS bdm_tempo.v_xpm_contacto_canal;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_persona_dir_ganadora;

CREATE OR REPLACE VIEW bdm_tempo.v_xpm_contacto_canal AS
SELECT
  -- 2026-10-20 (D-EDF-07): la llave cambia en v_xpm_contacto_direccion de
  -- ci.id (el reporte) a (ci.id, ci.index) (el contacto). Aqui NO se usa la
  -- del propio contacto: Ordenamiento enlaza cada telefono, celular o correo
  -- con la direccion de SU MISMO REPORTE por igualdad de cod_dw_persona_ubic
  -- (sp_ordenamiento_preparar_insumos_edf.sql:342,
  -- sp_ordenamiento_ubicaciones_edf.sql:238,245). Antes ese enlace salia
  -- gratis porque los dos compartian ci.id. Ahora se apunta a la direccion
  -- del reporte (la de menor index si trae varias); una direccion se apunta
  -- a si misma, y un reporte sin direccion cae a la llave del contacto, que
  -- no enlaza con nada, igual que antes.
  -- La llave propia de cada contacto de canal (una RPU por telefono, como en
  -- el AS-IS) es D-ORD-10 y va con el lugar por canal (F5).
  CASE WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') IN ('1', '2', '3', '7', '8')
       THEN FNV_HASH(CAST(ci.id AS VARCHAR) || ':' || CAST(ci."index" AS VARCHAR))
       ELSE COALESCE(dir.cod_rpu_dir, FNV_HASH(CAST(ci.id AS VARCHAR) || ':' || CAST(ci."index" AS VARCHAR)))
  END AS cod_dw_persona_ubic,
  FNV_HASH(xpm.pin) AS id_buro_persona,
  CAST(xpm.pin AS BIGINT) AS cod_pin_persona,
  NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') AS contact_type,
  -- 2026-10-20 (D-EDF-10): LOS TELEFONOS SE NORMALIZAN AQUI. EDF no los
  -- estandariza (contactasreportedstandardized vacio en el 100 %, C21) y el
  -- crudo llega RELLENADO CON CEROS hasta 12 digitos (C22, en DEV y en QA).
  -- Con el relleno el operador salia '003', no estaba en V_Operador_Ord_Cel y
  -- la compuerta CEL018 sacaba a todos los celulares del ranking.
  -- No contradice al legado: el SP sigue sacando el operador con el SUBSTR
  -- en crudo de Caracteristicas.txt:912, solo que ahora sobre un valor
  -- equivalente al Texto_Ubicacion del AS-IS, que no venia rellenado (su
  -- catalogo de operadores usa 300-350). El relleno es formato de EDF.
  -- Solo digitos y sin los ceros de la izquierda; correos y direcciones no
  -- se tocan.
  CASE WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') IN ('4', '5', '6', '9')
       THEN NULLIF(LTRIM(REGEXP_REPLACE(COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
                 NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '')), '[^0-9]', ''), '0'), '')
       ELSE COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
                 NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), ''))
  END AS valor_contacto,
  -- 2026-10-20 (D-EDF-11): el canal se decide aqui, una vez, y los filtros
  -- de Ordenamiento leen esta columna en vez de repetir codigos. El 6 trae
  -- celulares y fijos mezclados (C18: 104.851 y 23.044 en DEV; 13.684 y
  -- 2.075 en QA): va a CEL si tiene forma de celular colombiano (10 digitos
  -- que empiezan por 3) y a TEL si no.
  CAST(CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') IN ('1', '2', '3', '7', '8') THEN 'DIR'
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') IN ('4', '5') THEN 'TEL'
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') = '9' THEN 'CEL'
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') = '10' THEN 'EMA'
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') = '6'
     AND LEN(NULLIF(LTRIM(REGEXP_REPLACE(COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
                 NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '')), '[^0-9]', ''), '0'), '')) = 10
     AND LEFT(NULLIF(LTRIM(REGEXP_REPLACE(COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
                 NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '')), '[^0-9]', ''), '0'), ''), 1) = '3' THEN 'CEL'
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') = '6' THEN 'TEL'
  END AS VARCHAR(3)) AS canal,
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
  -- 2026-10-20 (D-EDF-03): SUSCRIPTOR EN TRES NIVELES, sin hash y sin
  -- multiplicar filas. Antes mandaba la contraparte de la PERSONA, igual para
  -- todos sus reportes, y caia a una cubeta de hash; ademas el join por
  -- persona repetia cada reporte tantas veces como contrapartes (hasta x57,
  -- C15). Ahora:
  --   1. el suscriptor del propio reporte (solo el 4,9 % lo trae en DEV, C16);
  --   2. si falta y la persona tiene UNA sola contraparte, esa (el subquery cp
  --      deja una fila por persona o ninguna);
  --   3. si no, NULL: no se inventa una entidad.
  -- PENDIENTE C19: si la contraparte de la persona resulta ser la fuente y no
  -- un suscriptor, el nivel 2 se quita y queda solo el 1.
  COALESCE(
    CASE
      WHEN NULLIF(TRIM(loc."location.val.counterpartyidnumber"::VARCHAR), '') ~ '^[0-9]+$'
       AND CAST(NULLIF(TRIM(loc."location.val.counterpartyidnumber"::VARCHAR), '') AS BIGINT) <= 2147483647
      THEN CAST(NULLIF(TRIM(loc."location.val.counterpartyidnumber"::VARCHAR), '') AS INTEGER)
      ELSE NULL
    END,
    CASE
      WHEN cp.counterpartyidnumber ~ '^[0-9]+$'
       AND CAST(cp.counterpartyidnumber AS BIGINT) <= 2147483647
      THEN CAST(cp.counterpartyidnumber AS INTEGER)
      ELSE NULL
    END
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
LEFT JOIN ( SELECT c0.id,
                   MAX(NULLIF(TRIM(c0."counterparties.val.counterpartyidnumber"::VARCHAR), '')) AS counterpartyidnumber
              FROM ds_dba_rncr_batch.edf_views.xpm_counterparties c0
             WHERE c0."index" IS NOT NULL
             GROUP BY c0.id
            HAVING COUNT(*) = 1 ) cp
  ON xpm.counterparties = cp.id
LEFT JOIN ( SELECT d0.id,
                   FNV_HASH(CAST(d0.id AS VARCHAR) || ':'
                            || CAST(MIN(CAST(d0."index" AS INTEGER)) AS VARCHAR)) AS cod_rpu_dir
              FROM ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations d0
             WHERE NULLIF(TRIM(d0."location.val.contactinformations.val.contacttype"::VARCHAR), '') IN ('1', '2', '3', '7', '8')
             GROUP BY d0.id ) dir
  ON dir.id = ci.id
WHERE NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') IN
  ('1','2','3','4','5','6','7','8','9','10')
  -- 2026-10-20 (D-EDF-01, PROVISIONAL): fuera los contactos de un reporte
  -- bloqueado. Las direcciones llevan la bandera en la RPU y los SP las
  -- excluyen por anti-join; los canales no tienen esa bandera aguas abajo,
  -- asi que se filtran aqui. El efecto es el mismo: el legado excluye el
  -- contacto entero.
  AND COALESCE(NULLIF(TRIM(loc."location.val.blockreason"::VARCHAR), ''), '0') = '0'
WITH NO SCHEMA BINDING;

-- Personas con DIR ganadora post-unificacion (vista; no tabla local)
-- NOTA: tras 04_vistas_sin_copia_productor.sql se redefine sobre v_rpu_post_unificacion
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_persona_dir_ganadora AS
SELECT DISTINCT id_buro_persona
FROM bdm_tempo.v_xpm_relacion_persona_ubicacion rpu
WHERE NOT EXISTS (
  SELECT 1 FROM bdm_datos.unificacion_direccion u
  WHERE u.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
)
WITH NO SCHEMA BINDING;
