-- ============================================================
-- 00_vistas_insumo_bdm.sql  (DEV / edf_views)
-- Capa XPM edf_views -> insumo BDM para Unificacion R1/R2/R3
-- Diferencia vs ifr_data: sin columna relationalizelastupdate en JOINs
-- Sanitiza strings vacios / IDs fuera de rango INTEGER (edf_views DEV)
-- ============================================================

DROP VIEW IF EXISTS bdm_tempo.v_xpm_actividad_economica_persona;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_ciiu_persona;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_reporte_relacion_persona_ubica;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_direccion_fisica;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_ubicacion_estandarizada;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_relacion_persona_ubicacion;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_contacto_direccion;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_cuenta_bloqueada;

-- 2026-10-20 (D-EDF-01): CUENTAS BLOQUEADAS, una fila por llave. Es el
-- V_BLOQUEO del AS-IS, que es de cuenta (V_Razon_Bloqueo habla de la historia
-- de credito: reclamos, prescripcion, obligaciones cerradas) y excluye la RPU
-- entera en Unificacion, Ordenamiento y Novedades. En EDF es
-- bestAccounts.blockSeverity = 1 (indicador de bloqueo 1-7, todos "no se
-- muestra"), lo mismo que Experian quita de LOCATION a sus productos (Data
-- Provisioning - Filters). La severidad 2 (reclamo vencido, cuenta sin validar
-- ante la Registraduria) mezcla una razon que se oculta y otra que se muestra:
-- se deja pasar hasta que Experian responda.
-- La llave es la de Data Provisioning: linea de negocio, tipo y numero de
-- cuenta, tipo y numero de documento, dentro del arreglo de cuentas de la
-- persona (ba_id = xpm.bestaccounts). La leen v_xpm_contacto_direccion y
-- v_xpm_contacto_canal: una sola definicion para que no deriven. El DISTINCT
-- sobre las seis columnas de la llave deja una fila por llave, de modo que el
-- LEFT JOIN de los consumidores no puede multiplicar contactos.
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_cuenta_bloqueada AS
SELECT DISTINCT
       ba.id                                                              AS ba_id,
       NULLIF(TRIM(ba."bestaccounts.val.businesslinecode"::VARCHAR), '') AS linea,
       NULLIF(TRIM(ba."bestaccounts.val.accounttype"::VARCHAR), '')      AS tipo_cta,
       NULLIF(TRIM(ba."bestaccounts.val.accountnumber"::VARCHAR), '')    AS num_cta,
       NULLIF(TRIM(ba."bestaccounts.val.personidtype"::VARCHAR), '')     AS tipo_doc,
       NULLIF(TRIM(ba."bestaccounts.val.personidnumber"::VARCHAR), '')   AS num_doc
  FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts ba
 WHERE ba."index" IS NOT NULL
   AND NULLIF(TRIM(ba."bestaccounts.val.blockseverity"::VARCHAR), '') = '1'
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_xpm_contacto_direccion AS
SELECT
  xpm.pin,
  CAST(NULL AS BIGINT)              AS relationalizelastupdate,
  -- 2026-10-20 (D-EDF-07, D-UNI-02): LLAVES REHECHAS. Antes eran
  -- cod_dw_ubic = loc.id y cod_dw_persona_ubic = ci.id, y las dos estaban mal:
  --   * loc.id es el arreglo de location de la PERSONA (98.586 id para 98.586
  --     personas, C4c): todas las direcciones de una persona compartian
  --     cod_dw_ubic, y R1/R2/R3, que agrupan por cod_dw_ubic, las trataban
  --     como el mismo lugar aunque el texto fuera distinto.
  --   * ci.id es el REPORTE, que trae ~4 contactos de distinto tipo (C4b).
  -- Ahora, como en el mock (seed_mock_matriz.sql:29-33) y en el AS-IS:
  --   cod_dw_persona_ubic = el contacto, (ci.id, ci.index), unico en los
  --     568.544 contactos reales (C4a). FNV_HASH, igual que las llaves que ya
  --     genera el motor de la R2 (sp_unificacion_r2_motor_nit_...:364-365).
  --   cod_dw_direccion_fisica = el mismo valor, 1:1 con su complemento.
  --   cod_dw_ubic = el LUGAR: texto estandarizado + DANE (o la ciudad si no
  --     hay DANE). Dos personas que reportan la misma direccion comparten
  --     cod_dw_ubic, como en el maestro de ubicaciones del legado. Sin texto
  --     no hay lugar que compartir y cae a la llave del contacto.
  CASE
    WHEN COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedtextoubicacion"::VARCHAR), ''),
               NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
               NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '')) IS NULL
    THEN FNV_HASH(CAST(ci.id AS VARCHAR) || ':' || CAST(ci."index" AS VARCHAR))
    ELSE FNV_HASH(UPPER(COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedtextoubicacion"::VARCHAR), ''),
               NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreportedstandardized"::VARCHAR), ''),
               NULLIF(TRIM(ci."location.val.contactinformations.val.contactasreported"::VARCHAR), '')))
                  || '|' || COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), ''),
                                     UPPER(NULLIF(TRIM(ci."location.val.contactinformations.val.cityname"::VARCHAR), '')),
                                     ''))
  END                               AS cod_dw_ubic,
  FNV_HASH(CAST(ci.id AS VARCHAR) || ':' || CAST(ci."index" AS VARCHAR)) AS cod_dw_persona_ubic,
  FNV_HASH(CAST(ci.id AS VARCHAR) || ':' || CAST(ci."index" AS VARCHAR)) AS cod_dw_direccion_fisica,
  FNV_HASH(xpm.pin)                 AS id_buro_persona,
  CAST(xpm.pin AS BIGINT)           AS cod_pin_persona,
  -- 2026-10-20 (D-EDF-06): tipo de direccion segun el catalogo OFICIAL de
  -- contactType (1 Residence, 2 Labor, 3 Mailing, 7 Legal Address-c,
  -- 8 Business Address-c, 12 Notification Address). El 1, 2 y 3 coinciden con
  -- los codigos de bdm_datos.tipo_ubicacion_dir (RES, LAB, CRR) y pasan tal
  -- cual. El 8 es la direccion COMERCIAL (CCL en Information Recognizer) y
  -- antes iba a CRR: el 91 % de las direcciones de DEV contaba como
  -- correspondencia en el padre de la Regla 1, en el scoring DIR y en
  -- ES_TIPO_CRR. El 7 es la LEGAL (JUD) y antes caia en el 7 'DIR' inventado.
  -- Se usan los codigos que tipo_ubicacion_dir YA tiene (01_ddl_unificacion
  -- _direccion.sql: 4 JUD, 5 CCL), sin DDL. El legado solo pregunta por RES,
  -- LAB y CRR (P0019_UNIFICACION_111.TPT:94,101; Novedad.sql:8375-8382), asi
  -- que CCL y JUD no dan puntos ni banderas, igual que alli.
  CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') = '8' THEN 5
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') = '7' THEN 4
    -- SLCOPRBA-1354: tope de magnitud, como ya lo tenian standardizeddanecode
    -- y counterpartyidnumber en este mismo archivo. Sin el, un contacttype de
    -- mas de 10 digitos aborta el lote completo con "Value out of range for 4
    -- bytes"; con el, esa fila queda con tipo NULL y el lote sigue.
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') ~ '^[0-9]+$'
     AND CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') AS BIGINT) <= 2147483647
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
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contactasstandardizedscore"::VARCHAR), '') ~ '^[0-9](\.[0-9]+)?$'
    THEN CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.contactasstandardizedscore"::VARCHAR), '') AS DECIMAL(5,4))
    ELSE NULL
  END AS score_estandarizacion,
  -- 2026-10-20: el patron admite UN digito entero. La escala es 0-1 (C24) y
  -- un "96" de otra escala habria desbordado el DECIMAL(5,4) y abortado la
  -- vista entera; ahora queda en NULL.
  -- 2026-10-20 (D-EDF-12, umbral del negocio): la gestion de registro del
  -- legado (V_Gestion_Registro: VALIDA / NO VALIDA) sale del score de la
  -- libreria de estandarizacion. VALIDA si el score es >= 0.80, NO VALIDA si
  -- es menor y NULL si no hay score. NULL no es NO VALIDA: en DEV solo el
  -- tipo 8 trae score (C24) y las direcciones de suscriptor (1, 2, 3) llegan
  -- sin el; el Ordenamiento del legado cuenta NULL como valida
  -- (Caracteristicas.txt LF 160) y Novedades lo deja pasar. Se repite la
  -- expresion del score porque una columna no lee el alias de su vecina.
  CAST(CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.contactasstandardizedscore"::VARCHAR), '') ~ '^[0-9](\.[0-9]+)?$'
    THEN CASE WHEN CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.contactasstandardizedscore"::VARCHAR), '') AS DECIMAL(5,4)) >= 0.80
              THEN 'VALIDA' ELSE 'NO VALIDA' END
    ELSE NULL
  END AS VARCHAR(20)) AS descripcion_gestion_registro,
  CASE
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), '') ~ '^[0-9]+$'
     AND CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), '') AS BIGINT) <= 2147483647
    THEN CAST(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddanecode"::VARCHAR), '') AS INTEGER)
    -- 2026-10-20 (D-EDF-02, propuesta C aprobada): CIUDAD DE RESPALDO cuando
    -- no hay DANE. Antes caia a un hash de cityname, que inventaba una ciudad
    -- y mezclaba claves DANE con valores de hash. Falta el DANE en ~55k
    -- direcciones en DEV y ~74k en QA (C18). En este orden:
    --   1. citycode de 4-5 digitos: el municipio DANE sin el cero (C18; solo
    --      en las direcciones de la fuente 6). Se toma su cabecera, * 1000.
    --   2. el nombre de municipio + departamento contra el catalogo DIVIPOLA
    --      de cabeceras (24_ddl_catalogo_divipola_cabecera.sql), primero con
    --      la clave exacta y luego con el esqueleto de consonantes;
    --   3. el nombre solo, si en el catalogo apunta a UNA cabecera.
    -- 2 y 3 son PROBABLE: el reporte nombra el municipio y se asigna su
    -- cabecera. Si nada casa, NULL.
    WHEN NULLIF(TRIM(ci."location.val.contactinformations.val.citycode"::VARCHAR), '') ~ '^[0-9]+$'
     AND LEN(TRIM(ci."location.val.contactinformations.val.citycode"::VARCHAR)) BETWEEN 4 AND 5
    THEN CAST(TRIM(ci."location.val.contactinformations.val.citycode"::VARCHAR) AS INTEGER) * 1000
    ELSE COALESCE(dve.cod_dane_ciudad, due.cod_dane_ciudad,
                  dvs.cod_dane_ciudad, dus.cod_dane_ciudad)
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
  -- SLCOPRBA-1354: VARCHAR(20), NO INTEGER.
  -- En el legado Cod_Tipo_Ident_Fte es CAST(NULL AS VARCHAR(20)) (lineas 1677,
  -- 1699, 1723, 3505 y 3527 de PRO_UnificacionR2.sql) y se usa como LLAVE DE
  -- JOIN contra la tabla de tipos; la prueba de NIT es sobre el nombre
  -- (Nombre_Tipo_Ident LIKE '%Nit%'), nunca sobre un numero.
  -- Castearlo a INTEGER rompia de dos maneras: un personidtype de mas de 10
  -- digitos aborta con "Value out of range for 4 bytes" (asi cayo el job #293,
  -- porque el guardia solo exigia que fueran digitos, no que cupieran en 4
  -- bytes), y dejaba el tipo de la via real divergente del mock, que ya lo
  -- trae VARCHAR(20) igual que bdm_datos.rpu_generada.
  CAST(NULLIF(TRIM(loc."location.val.personidtype"::VARCHAR), '') AS VARCHAR(20))
    AS cod_tipo_ident_fte,
  CAST(NULL AS INTEGER) AS lote,
  -- 2026-10-20 (D-EDF-01): bloqueado si se cumple cualquiera de las dos.
  --   * SUSCRIPTOR BLOQUEADO: el reporte trae razon de bloqueo distinta de
  --     vacio y de '0'. Es el blockReason del suscriptor (subscriber.json) y
  --     en DEV va siempre con blockStatus 0, que es "bloqueado" (C7, C13;
  --     fichas ICBCLA e ICBSUS). La regla "razon 2 o 5" de getXPM es para los
  --     calculos agregados del XPM, no para mostrar datos.
  --   * CUENTA BLOQUEADA: la cuenta del reporte tiene blockSeverity = 1 en
  --     bestAccounts (indicador 1-7: historico, caducidad, Novedat,
  --     eliminacion logica, obligacion cerrada, registro frenado). Es el
  --     V_BLOQUEO del AS-IS, que es de cuenta (V_Razon_Bloqueo: "no se
  --     muestra en la Historia de Credito"), y lo que Experian quita de
  --     LOCATION a sus productos (Data Provisioning - Filters). La severidad
  --     2 se muestra hasta que Experian diga otra cosa. Ver
  --     v_xpm_cuenta_bloqueada.
  -- Los SP excluyen el id entero con anti-join, como el legado.
  CASE WHEN COALESCE(NULLIF(TRIM(loc."location.val.blockreason"::VARCHAR), ''), '0') <> '0'
         OR cbq.ba_id IS NOT NULL
       THEN 1 ELSE 0 END AS bloqueado
FROM ds_dba_rncr_batch.edf_views.xpm xpm
INNER JOIN ds_dba_rncr_batch.edf_views.xpm_location loc
  ON xpm.location = loc.id
INNER JOIN ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations ci
  ON loc."location.val.contactinformations" = ci.id
-- Cuenta bloqueada del reporte (bloqueado). Ver v_xpm_cuenta_bloqueada.
LEFT JOIN bdm_tempo.v_xpm_cuenta_bloqueada cbq
  ON cbq.ba_id    = xpm.bestaccounts
 AND cbq.linea    = NULLIF(TRIM(loc."location.val.businesslinecode"::VARCHAR), '')
 AND cbq.tipo_cta = NULLIF(TRIM(loc."location.val.accounttype"::VARCHAR), '')
 AND cbq.num_cta  = NULLIF(TRIM(loc."location.val.accountnumber"::VARCHAR), '')
 AND cbq.tipo_doc = NULLIF(TRIM(loc."location.val.personidtype"::VARCHAR), '')
 AND cbq.num_doc  = NULLIF(TRIM(loc."location.val.personidnumber"::VARCHAR), '')
-- Ciudad de respaldo (ver cod_dw_ciudad): clave exacta con departamento,
-- exacta sola, esqueleto de consonantes con departamento y esqueleto solo.
-- Cada subconsulta deja una fila por clave y solo si la clave apunta a UNA
-- cabecera: el LEFT JOIN no puede multiplicar direcciones. El esqueleto
-- casa los nombres con tilde que la exacta no puede (Medellin con tilde da
-- MEDELLN en la exacta y MDLLN en las dos variantes del esqueleto).
LEFT JOIN ( SELECT clave_ciudad, clave_depto, MIN(cod_dane_ciudad) AS cod_dane_ciudad
              FROM bdm_datos.catalogo_divipola_cabecera
             WHERE tipo_clave = 'E'
             GROUP BY clave_ciudad, clave_depto
            HAVING COUNT(DISTINCT cod_dane_ciudad) = 1 ) dve
  ON dve.clave_ciudad = REGEXP_REPLACE(UPPER(TRIM(COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedmunicipality"::VARCHAR), ''),
                                   NULLIF(TRIM(ci."location.val.contactinformations.val.cityname"::VARCHAR), '')))), '[^A-Z0-9]', '')
 AND dve.clave_depto  = REGEXP_REPLACE(UPPER(TRIM(COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddepartment"::VARCHAR), ''),
                                   NULLIF(TRIM(ci."location.val.contactinformations.val.statename"::VARCHAR), '')))), '[^A-Z0-9]', '')
LEFT JOIN ( SELECT clave_ciudad, MIN(cod_dane_ciudad) AS cod_dane_ciudad
              FROM bdm_datos.catalogo_divipola_cabecera
             WHERE tipo_clave = 'E'
             GROUP BY clave_ciudad
            HAVING COUNT(DISTINCT cod_dane_ciudad) = 1 ) due
  ON due.clave_ciudad = REGEXP_REPLACE(UPPER(TRIM(COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedmunicipality"::VARCHAR), ''),
                                   NULLIF(TRIM(ci."location.val.contactinformations.val.cityname"::VARCHAR), '')))), '[^A-Z0-9]', '')
LEFT JOIN ( SELECT clave_ciudad, clave_depto, MIN(cod_dane_ciudad) AS cod_dane_ciudad
              FROM bdm_datos.catalogo_divipola_cabecera
             WHERE tipo_clave = 'S'
             GROUP BY clave_ciudad, clave_depto
            HAVING COUNT(DISTINCT cod_dane_ciudad) = 1 ) dvs
  ON dvs.clave_ciudad = REGEXP_REPLACE(UPPER(TRIM(COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedmunicipality"::VARCHAR), ''),
                                   NULLIF(TRIM(ci."location.val.contactinformations.val.cityname"::VARCHAR), '')))), '[^B-DF-HJ-NP-TV-Z0-9]', '')
 AND dvs.clave_depto  = REGEXP_REPLACE(UPPER(TRIM(COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizeddepartment"::VARCHAR), ''),
                                   NULLIF(TRIM(ci."location.val.contactinformations.val.statename"::VARCHAR), '')))), '[^B-DF-HJ-NP-TV-Z0-9]', '')
LEFT JOIN ( SELECT clave_ciudad, MIN(cod_dane_ciudad) AS cod_dane_ciudad
              FROM bdm_datos.catalogo_divipola_cabecera
             WHERE tipo_clave = 'S'
             GROUP BY clave_ciudad
            HAVING COUNT(DISTINCT cod_dane_ciudad) = 1 ) dus
  ON dus.clave_ciudad = REGEXP_REPLACE(UPPER(TRIM(COALESCE(NULLIF(TRIM(ci."location.val.contactinformations.val.standardizedmunicipality"::VARCHAR), ''),
                                   NULLIF(TRIM(ci."location.val.contactinformations.val.cityname"::VARCHAR), '')))), '[^B-DF-HJ-NP-TV-Z0-9]', '')
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
  -- SLCOPRBA-1354: CAST EXPLICITO EN LAS DOS RAMAS.
  -- Antes de M2 esta vista NO tenia UNION: leia una sola fuente, asi que
  -- ninguna columna estaba pareada contra nada y los tipos no importaban. Al
  -- introducir el UNION ALL hay que garantizar que cada par case, y el riesgo
  -- NO lo avisa el despliegue: la vista es WITH NO SCHEMA BINDING, de modo que
  -- Redshift la crea sin validar y el error aparece recien cuando alguien la
  -- CONSULTA ("UNION types integer and character varying cannot be matched",
  -- que es como se cayo el job #279 en 04_vistas_insumo_ordenamiento).
  -- Casteando ambas ramas la union no puede romperse por tipos, y los tipos de
  -- salida de la vista quedan fijos y documentados.
  -- Los VARCHAR no se castean a proposito: Redshift ensancha solo al unir dos
  -- VARCHAR de distinto largo, y castear a lo ancho fijo arriesgaria truncar.
  SELECT
    CAST(cod_dw_persona_ubic            AS BIGINT)   AS cod_dw_persona_ubic,
    CAST(id_buro_persona                AS BIGINT)   AS id_buro_persona,
    CAST(cod_pin_persona                AS BIGINT)   AS cod_pin_persona,
    CAST(cod_dw_ubic                    AS BIGINT)   AS cod_dw_ubic,
    CAST(cod_dw_direccion_fisica        AS BIGINT)   AS cod_dw_direccion_fisica,
    CAST(cod_dw_tipo_ubicacion_dir      AS INTEGER)  AS cod_dw_tipo_ubicacion_dir,
    CAST(NULL                           AS INTEGER)  AS ind_unificacion,
    CAST(fecha_relacion_persona_ubicaci AS DATE)     AS fecha_relacion_persona_ubicaci,
    CAST(lote                           AS INTEGER)  AS lote,
    CAST(cod_tipo_ident_fte          AS VARCHAR(20)) AS cod_tipo_ident_fte,
    CAST(bloqueado                      AS SMALLINT) AS bloqueado
  FROM bdm_tempo.v_xpm_contacto_direccion
  UNION ALL
  SELECT
    CAST(cod_dw_persona_ubic            AS BIGINT),
    CAST(id_buro_persona                AS BIGINT),
    CAST(cod_pin_persona                AS BIGINT),
    CAST(cod_dw_ubic                    AS BIGINT),
    CAST(cod_dw_direccion_fisica        AS BIGINT),
    CAST(cod_dw_tipo_ubicacion_dir      AS INTEGER),
    CAST(ind_unificacion                AS INTEGER),
    CAST(fecha_relacion_persona_ubicaci AS DATE),
    CAST(lote                           AS INTEGER),
    CAST(cod_tipo_ident_fte          AS VARCHAR(20)),
    CAST(0                              AS SMALLINT)
  FROM bdm_datos.rpu_generada
  WHERE fecha_inactivacion IS NULL
) rpu_u
LEFT JOIN ( SELECT DISTINCT cod_dw_persona_ubic
              FROM bdm_datos.unificacion_direccion ) est
       ON est.cod_dw_persona_ubic = rpu_u.cod_dw_persona_ubic
WITH NO SCHEMA BINDING;

-- SLCOPRBA-1355: latitud/longitud se COALESCEan contra bdm_datos.geo_atributos.
--
-- EL DATASHARE NO PUBLICA COORDENADAS. v_xpm_contacto_direccion las expone como
-- CAST(NULL AS DECIMAL(10,6)), de modo que esta vista entregaba NULL en las dos
-- columnas SIEMPRE. El insumo de la Regla 3 exige coordenadas, asi que R3 no
-- podia unificar NUNCA sobre datos reales: no daba error, daba cero.
--
-- bdm_datos.geo_atributos es la unica fuente posible, y es justamente donde el
-- Ciclo GEO escribe lo que devuelve ArcGIS. Que ninguna vista de insumo la
-- leyera es el segundo de los dos defectos encadenados que CA-04 reporta.
--
-- UNA FILA POR UBICACION: geo_atributos no tiene clave unica declarada
-- (Redshift no impone ninguna) y una ubicacion puede tener fila en varios
-- Lotes. Sin reducir a una, el LEFT JOIN multiplicaria el insumo de TODAS las
-- reglas, no solo de R3. Se toma la del lote mas reciente y solo si trae las
-- dos coordenadas.
--
-- El COALESCE deja primero el valor del datashare aunque hoy sea constante
-- nulo: el dia que el datashare las publique, manda el productor y esta vista
-- no se vuelve a tocar. Es el mismo criterio con que ind_unificacion y
-- bloqueado quedaron puestos antes de que el datashare los expusiera.
--
-- ORDEN DE DESPLIEGUE: geo_atributos la crea 03_ddl_geo.sql, que corre DESPUES
-- de este script. No importa porque la vista es WITH NO SCHEMA BINDING y no
-- resuelve sus referencias al crearse; nada la consulta entre los dos pasos.
-- 2026-10-20: UNA FILA POR LUGAR. Con cod_dw_ubic = texto + DANE, varios
-- contactos comparten lugar y pueden diferir en lo demas (texto original,
-- score, tipo). Un DISTINCT dejaria varias filas por cod_dw_ubic y cada join
-- de R1/R2/R3 contra esta vista se multiplicaria. Se toma la del contacto de
-- menor llave, que es deterministica.
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_ubicacion_estandarizada AS
SELECT
  cd.cod_dw_ubic,
  cd.texto_ubicacion,
  cd.texto_ubicacion_normalizado,
  cd.texto_ubicacion_original,
  -- 2026-10-20 (D-EDF-12): el score y la gestion son del LUGAR, como en el
  -- legado (UBICACION_ESTANDARIZADA.Cod_DW_Gestion_Registro,
  -- Novedad.sql:7679). Se toma el mejor score de los contactos del lugar y no
  -- el del contacto de menor llave, que es lo que daba antes esta columna y
  -- nadie leia: si uno de sus reportes quedo estandarizado con >= 0.80, el
  -- lugar es VALIDA. Sin ningun score, NULL.
  cd.score_ubic AS score_estandarizacion,
  CAST(CASE WHEN cd.score_ubic IS NULL THEN NULL
            WHEN cd.score_ubic >= 0.80 THEN 'VALIDA'
            ELSE 'NO VALIDA' END AS VARCHAR(20)) AS descripcion_gestion_registro,
  cd.cod_dw_ciudad,
  -- 2026-10-20 (D-UNI-06): el DANE de EDF es el centro poblado de 8 digitos
  -- (C6c); el municipio son sus 5 primeros. El INTEGER ya perdio el cero
  -- inicial, de modo que la division entera da el codigo correcto:
  -- 05001000 -> 5001000 / 1000 = 5001 = 05001.
  cd.cod_dw_ciudad / 1000 AS cod_dw_municipio,
  cd.departamento,
  cd.municipio,
  cd.tipo_ubicacion,
  cd.cod_dw_tipo_ubicacion_dir AS cod_dw_tipo_ubicacion,
  COALESCE(cd.latitud,  g.latitud)  AS latitud,
  COALESCE(cd.longitud, g.longitud) AS longitud
FROM ( SELECT cd0.*,
              ROW_NUMBER() OVER (PARTITION BY cd0.cod_dw_ubic
                                 ORDER BY cd0.cod_dw_persona_ubic) AS rn_ubic,
              MAX(cd0.score_estandarizacion) OVER (PARTITION BY cd0.cod_dw_ubic) AS score_ubic
         FROM bdm_tempo.v_xpm_contacto_direccion cd0 ) cd
LEFT JOIN (
  SELECT cod_dw_ubic, latitud, longitud
  FROM ( SELECT cod_dw_ubic, latitud, longitud,
                ROW_NUMBER() OVER (PARTITION BY cod_dw_ubic
                                   ORDER BY lote DESC NULLS LAST) AS rn
           FROM bdm_datos.geo_atributos
          WHERE latitud IS NOT NULL AND longitud IS NOT NULL ) z
  WHERE rn = 1
) g ON g.cod_dw_ubic = cd.cod_dw_ubic
WHERE cd.rn_ubic = 1
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
  -- SLCOPRBA-1354: CAST EXPLICITO de las columnas NUMERICAS en las dos ramas,
  -- por la misma razon que en la vista de relacion_persona_ubicacion: la vista
  -- es WITH NO SCHEMA BINDING y un desajuste de tipos en el UNION no se detecta
  -- al desplegar, solo al consultarla. Los VARCHAR se dejan sin castear: al unir
  -- dos VARCHAR Redshift ensancha solo, y fijar un ancho arriesgaria truncar.
  SELECT
    CAST(cod_dw_direccion_fisica AS BIGINT)  AS cod_dw_direccion_fisica,
    complemento, tipo_via_principal, via_principal,
    via_generadora, numero_puerta,
    CAST(cod_dw_ubic             AS BIGINT)  AS cod_dw_ubic,
    CAST(0                       AS INTEGER) AS generada_enriquecida
  FROM bdm_tempo.v_xpm_contacto_direccion
  UNION ALL
  SELECT
    CAST(cod_dw_direccion_fisica AS BIGINT),
    complemento, tipo_via_principal, via_principal,
    via_generadora, numero_puerta,
    CAST(cod_dw_ubic             AS BIGINT),
    CAST(COALESCE(generada_enriquecida, 1) AS INTEGER)
  FROM bdm_datos.direccion_fisica_generada
  WHERE fecha_inactivacion IS NULL
) df_u
WITH NO SCHEMA BINDING;

CREATE OR REPLACE VIEW bdm_tempo.v_xpm_reporte_relacion_persona_ubica AS
SELECT
  -- 2026-10-20: la misma llave de contacto que v_xpm_contacto_direccion.
  FNV_HASH(CAST(ci.id AS VARCHAR) || ':' || CAST(ci."index" AS VARCHAR)) AS cod_dw_persona_ubic,
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
  CASE
    WHEN NULLIF(TRIM(loc."location.val.cutoffdate"::VARCHAR), '') ~ '^[0-9]+$'
    THEN bdm_datos.convert_epoch_to_date(
      CAST(NULLIF(TRIM(loc."location.val.cutoffdate"::VARCHAR), '') AS BIGINT)
    )
    ELSE CURRENT_DATE
  END AS fecha_reporte,
  -- 2026-10-21 (T5, D-NOV-03): LA FUENTE DEL REPORTE.
  -- El legado la saca de V_FUENTE por Cod_DW_Fuente y cae a 'CAM' cuando no
  -- hay coincidencia (Novedad.sql:8635). No tenemos V_FUENTE ni cod_dw_fuente
  -- en el datashare, de modo que se deriva del typeOfData, que es el campo que
  -- SI dice de donde viene el reporte (catalogo 170, RESULTADOS seccion 18):
  -- los tipos de suscriptor (1, 2, 3 y 17) son SUS y el resto CAM.
  --   DECISION DEL USUARIO, 2026-10-21. Es una DIVERGENCIA de origen, no de
  --   valor: el legado decide por catalogo y nosotros por tipo de dato.
  -- QUE CAMBIA AGUAS ABAJO: la etapa 2 de Novedades agrupa por fuente
  -- (Novedad.sql:8670, GROUP BY 1..11), asi que con un literal constante el
  -- grano colapsaba. Con esto vuelve a ser UNA FILA POR RPU Y FUENTE, que es
  -- el grano del legado.
  --   SE COMPARA COMO TEXTO, con el mismo idiom que el resto del archivo
  --   (::VARCHAR + TRIM + NULLIF). En el datashare la columna es BIGINT y un
  --   IN (1, 2, 3, 17) vale, pero el stub del banco la declara VARCHAR y
  --   revienta con "operator does not exist: character varying = integer".
  --   El cast explicito es correcto en los dos y no cambia el resultado.
  CASE WHEN NULLIF(TRIM(loc."location.val.typeofdata"::VARCHAR), '') IN ('1', '2', '3', '17')
       THEN CAST('SUS' AS VARCHAR(30))
       ELSE CAST('CAM' AS VARCHAR(30))
  END AS fuente
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
WHERE NULLIF(TRIM(ci."location.val.contactinformations.val.contacttype"::VARCHAR), '') IN ('1', '2', '3', '7', '8')
WITH NO SCHEMA BINDING;

-- ============================================================
-- v_xpm_actividad_economica_persona (2026-10-21, D-NOV-06)
-- EL UNIVERSO COMPLETO DE ACTIVIDADES ECONOMICAS DE LA PERSONA.
--
-- El legado lee VU_PERSONA_ACTIVIDAD_ECONOMICA, que tiene una fila POR
-- PERSONA Y POR COD_DW_ACT_ECONO_CIIU (Novedad.sql:1280-1294,
-- PRIMARY INDEX(INFO_BASICA_ID, COD_DW_ACT_ECONO_CIIU)). Nosotros
-- entregabamos SOLO el CIIU principal, que es una de las once fuentes.
--
-- ES UNA VISTA NUEVA Y NO UNA AMPLIACION DE v_xpm_ciiu_persona, Y ESO NO ES
-- UN CAPRICHO: sp_unificacion_r1_preparar_insumo.sql:87 une esa vista a la
-- RPU por id_buro_persona con un LEFT JOIN, y hoy puede hacerlo porque tiene
-- UNA fila por persona. Devolver alli todas las actividades MULTIPLICARIA el
-- insumo de la Regla 1 por el numero de actividades de cada persona, que es
-- el mismo fan-out que ya se pago dos veces -- v_xpm_contacto_canal por tres
-- y stg_ord_alcance_origen -- y esta vez caeria sobre Unificacion, que ya
-- esta desplegada y certificada. v_xpm_ciiu_persona se queda EXACTAMENTE
-- como estaba, con el CIIU principal, que es lo que la Regla 1 necesita.
--
-- LAS ONCE FUENTES, todas del mismo grano persona -> actividad:
--   1  xpm.bestpersonalinformation.mainisiccodeforproduct  (la que ya habia)
--   2  personalinformation.val.mainisiccode
--   3-6 personalinformation.val.secondaryisiccode.secondaryisiccode1..4
--   7  chamberofcommerce...detailofmercantileregistrations.mainisiccodeforproduct
--   8-11 chamberofcommerce...secondaryisiccode1..4
--
-- El DISTINCT de la cabecera es el que impide que una persona que repite la
-- misma actividad en dos fuentes la reciba dos veces: el legado tiene esa
-- unicidad por indice primario.
-- ============================================================
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_actividad_economica_persona AS
SELECT DISTINCT id_buro_persona, cod_act_econo_ciiu_fte
FROM (
  SELECT FNV_HASH(xpm.pin) AS id_buro_persona,
         CAST(NULLIF(TRIM(xpm."bestpersonalinformation.mainisiccodeforproduct"::VARCHAR), '') AS VARCHAR(20)) AS cod_act_econo_ciiu_fte
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  UNION ALL
  SELECT FNV_HASH(xpm.pin),
         CAST(NULLIF(TRIM(pi."personalinformation.val.mainisiccode"::VARCHAR), '') AS VARCHAR(20))
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  INNER JOIN ds_dba_rncr_batch.edf_views.xpm_personalinformation pi
          ON pi.id = xpm.personalinformation AND pi."index" IS NOT NULL
  UNION ALL
  SELECT FNV_HASH(xpm.pin),
         CAST(NULLIF(TRIM(pi."personalinformation.val.secondaryisiccode.secondaryisiccode1"::VARCHAR), '') AS VARCHAR(20))
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  INNER JOIN ds_dba_rncr_batch.edf_views.xpm_personalinformation pi
          ON pi.id = xpm.personalinformation AND pi."index" IS NOT NULL
  UNION ALL
  SELECT FNV_HASH(xpm.pin),
         CAST(NULLIF(TRIM(pi."personalinformation.val.secondaryisiccode.secondaryisiccode2"::VARCHAR), '') AS VARCHAR(20))
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  INNER JOIN ds_dba_rncr_batch.edf_views.xpm_personalinformation pi
          ON pi.id = xpm.personalinformation AND pi."index" IS NOT NULL
  UNION ALL
  SELECT FNV_HASH(xpm.pin),
         CAST(NULLIF(TRIM(pi."personalinformation.val.secondaryisiccode.secondaryisiccode3"::VARCHAR), '') AS VARCHAR(20))
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  INNER JOIN ds_dba_rncr_batch.edf_views.xpm_personalinformation pi
          ON pi.id = xpm.personalinformation AND pi."index" IS NOT NULL
  UNION ALL
  SELECT FNV_HASH(xpm.pin),
         CAST(NULLIF(TRIM(pi."personalinformation.val.secondaryisiccode.secondaryisiccode4"::VARCHAR), '') AS VARCHAR(20))
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  INNER JOIN ds_dba_rncr_batch.edf_views.xpm_personalinformation pi
          ON pi.id = xpm.personalinformation AND pi."index" IS NOT NULL
  UNION ALL
  SELECT FNV_HASH(xpm.pin),
         CAST(NULLIF(TRIM(cc."chamberofcommerce.val.detailofmercantileregistrations.mainisiccodeforproduct"::VARCHAR), '') AS VARCHAR(20))
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  INNER JOIN ds_dba_rncr_batch.edf_views.xpm_chamberofcommerce cc
          ON cc.id = xpm.chamberofcommerce AND cc."index" IS NOT NULL
  UNION ALL
  SELECT FNV_HASH(xpm.pin),
         CAST(NULLIF(TRIM(cc."chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode1"::VARCHAR), '') AS VARCHAR(20))
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  INNER JOIN ds_dba_rncr_batch.edf_views.xpm_chamberofcommerce cc
          ON cc.id = xpm.chamberofcommerce AND cc."index" IS NOT NULL
  UNION ALL
  SELECT FNV_HASH(xpm.pin),
         CAST(NULLIF(TRIM(cc."chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode2"::VARCHAR), '') AS VARCHAR(20))
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  INNER JOIN ds_dba_rncr_batch.edf_views.xpm_chamberofcommerce cc
          ON cc.id = xpm.chamberofcommerce AND cc."index" IS NOT NULL
  UNION ALL
  SELECT FNV_HASH(xpm.pin),
         CAST(NULLIF(TRIM(cc."chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode3"::VARCHAR), '') AS VARCHAR(20))
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  INNER JOIN ds_dba_rncr_batch.edf_views.xpm_chamberofcommerce cc
          ON cc.id = xpm.chamberofcommerce AND cc."index" IS NOT NULL
  UNION ALL
  SELECT FNV_HASH(xpm.pin),
         CAST(NULLIF(TRIM(cc."chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode4"::VARCHAR), '') AS VARCHAR(20))
  FROM ds_dba_rncr_batch.edf_views.xpm xpm
  INNER JOIN ds_dba_rncr_batch.edf_views.xpm_chamberofcommerce cc
          ON cc.id = xpm.chamberofcommerce AND cc."index" IS NOT NULL
) u
WHERE cod_act_econo_ciiu_fte IS NOT NULL
WITH NO SCHEMA BINDING;

-- v_xpm_ciiu_persona: SOLO el CIIU principal, UNA fila por persona. NO se
-- amplia: la lee sp_unificacion_r1_preparar_insumo.sql:87 con un LEFT JOIN
-- por persona y mas de una fila multiplicaria el insumo de la Regla 1. El
-- universo completo vive en v_xpm_actividad_economica_persona, aqui arriba.
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_ciiu_persona AS
SELECT DISTINCT
  FNV_HASH(xpm.pin) AS id_buro_persona,
  NULLIF(TRIM(xpm."bestpersonalinformation.mainisiccodeforproduct"::VARCHAR), '') AS cod_act_econo_ciiu_fte
FROM ds_dba_rncr_batch.edf_views.xpm xpm
WHERE NULLIF(TRIM(xpm."bestpersonalinformation.mainisiccodeforproduct"::VARCHAR), '') IS NOT NULL
WITH NO SCHEMA BINDING;

