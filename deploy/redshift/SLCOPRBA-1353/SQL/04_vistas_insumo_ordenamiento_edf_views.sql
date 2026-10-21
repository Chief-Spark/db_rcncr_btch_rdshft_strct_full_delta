-- ============================================================
-- 04_vistas_sin_copia_productor.sql
-- Reemplaza materializacion de RPU e insumos: lectura via datashare.
-- PRECONDICION: unificacion ejecutada (unificacion_direccion poblada).
-- ============================================================

-- Salida ordenamiento: solo prioridad por RPU (no copiar universo XPM)
-- EL RANKING ES POR CANAL (D-ORD-10, 2026-10-21). La columna canal entro con
-- esa correccion y cambia el GRANO de la tabla: antes era una fila por RPU con
-- el MIN(lugar) MEZCLANDO canales, y ahora es una fila por RPU Y CANAL con el
-- lugar DENTRO de su canal.
--
-- POR QUE: el legado ordena cada canal por separado (Caracteristicas.txt:72
-- EMA, :79 CEL, :88 DIR, :105 TEL) y alli una fila de DIRECCIONES_TEMP
-- pertenece a UN canal, de modo que "lugar por canal" y "un valor por RPU" son
-- lo mismo. En nuestro modelo no: v_xpm_contacto_canal ata cada canal a la
-- direccion de su reporte, asi que un mismo cod_dw_persona_ubic aparece en
-- varios canales y el MIN los fundia. El Batch entrega UN CUBO POR CANAL
-- (Sps_Batch.sql:5416-5796) y cada uno necesita el lugar de SU canal.
--
-- LOS CONSUMIDORES DE HOY NO CAMBIAN DE VALOR: los tres que la leen agregan
-- con MIN(orden_prioridad) GROUP BY cod_dw_persona_ubic -- la vista de abajo,
-- sp_novedades_ubicacion_*.sql:123 y el evaluador --, de modo que siguen
-- obteniendo el mismo numero que antes. Lo que gana el Batch es poder pedir el
-- lugar de un canal concreto.
--
-- CREATE TABLE IF NOT EXISTS NO ANADE LA COLUMNA a una tabla que ya existe:
-- de eso se encarga sp_rcn_ctl_ord_migrar_canal, que la anade una sola vez y
-- vacia la tabla (la corrida siguiente es FULL y la repuebla).
CREATE TABLE IF NOT EXISTS bdm_datos.rpu_orden_prioridad (
  cod_dw_persona_ubic  BIGINT  ENCODE AZ64,
  id_buro_persona      BIGINT  ENCODE AZ64,
  canal                VARCHAR(3) ENCODE ZSTD,
  orden_prioridad      INTEGER ENCODE AZ64,
  fecha_actualizacion  TIMESTAMP DEFAULT GETDATE()
)
DISTSTYLE KEY DISTKEY(id_buro_persona)
SORTKEY(cod_dw_persona_ubic);

-- RPU post-unificacion: vista sobre productor + flag local de unificacion
DROP VIEW IF EXISTS bdm_tempo.v_rpu_post_unificacion;
CREATE OR REPLACE VIEW bdm_tempo.v_rpu_post_unificacion AS
SELECT
  rpu.cod_dw_persona_ubic,
  rpu.cod_pin_persona,
  rpu.id_buro_persona,
  rpu.cod_dw_ubic,
  op.orden_prioridad,
  rpu.fecha_relacion_persona_ubicaci,
  CASE WHEN u.cod_dw_persona_ubic IS NOT NULL THEN 1 ELSE 0 END AS ind_unificacion
FROM bdm_tempo.v_xpm_relacion_persona_ubicacion rpu
LEFT JOIN bdm_datos.unificacion_direccion u
  ON u.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
LEFT JOIN (
  SELECT cod_dw_persona_ubic, MIN(orden_prioridad) AS orden_prioridad
  FROM bdm_datos.rpu_orden_prioridad
  GROUP BY 1
) op
  ON op.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
WITH NO SCHEMA BINDING;

-- Compatibilidad: nombre historico usado en validaciones
DROP VIEW IF EXISTS bdm_tempo.v_relacion_persona_ubicacion_ord;
CREATE OR REPLACE VIEW bdm_tempo.v_relacion_persona_ubicacion_ord AS
SELECT * FROM bdm_tempo.v_rpu_post_unificacion
WITH NO SCHEMA BINDING;

-- Eliminar materializaciones previas (tabla o vista legacy).
-- Importante: DROP TABLE primero. Si el objeto es TABLE, DROP VIEW falla con 42809
-- ("is not a view") y aborta el script Jenkins (REDSHIFT:112).
DROP TABLE IF EXISTS bdm_datos.relacion_persona_ubicacion;
DROP TABLE IF EXISTS bdm_datos.insumo_direccion;
DROP TABLE IF EXISTS bdm_datos.insumo_telefono;
DROP TABLE IF EXISTS bdm_datos.insumo_celular;
DROP TABLE IF EXISTS bdm_datos.insumo_email;
DROP VIEW IF EXISTS bdm_datos.insumo_direccion;
DROP VIEW IF EXISTS bdm_datos.insumo_telefono;
DROP VIEW IF EXISTS bdm_datos.insumo_celular;
DROP VIEW IF EXISTS bdm_datos.insumo_email;

-- -- Insumo DIR (vista = logica de sp_ordenamiento_preparar_insumos_edf) --
CREATE OR REPLACE VIEW bdm_datos.insumo_direccion AS
SELECT
  rpu.cod_dw_persona_ubic,
  rpu.cod_pin_persona,
  rpu.id_buro_persona,
  cd.texto_ubicacion AS direccion_fisica,
  cd.complemento,
  tud.descripcion_tipo_ubicacion_dir AS tipo_ubicacion,
  cd.cod_dw_ciudad AS cod_dane_ciudad,
  rep.id_buro_suscriptor,
  rep.fecha_reporte,
  GREATEST(DATEDIFF(month, rep.fecha_reporte, CURRENT_DATE), 0) AS meses_reporte,
  COALESCE(sf.sector_financiero, 0) AS sector_financiero,
  dir_cnt.conteo_direcciones
FROM bdm_tempo.v_rpu_post_unificacion rpu
INNER JOIN bdm_tempo.v_xpm_contacto_direccion cd
  ON cd.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
INNER JOIN bdm_datos.tipo_ubicacion_dir tud
  ON cd.cod_dw_tipo_ubicacion_dir = tud.cod_dw_tipo_ubicacion_dir
INNER JOIN bdm_tempo.v_xpm_reporte_relacion_persona_ubica rep
  ON rpu.cod_dw_persona_ubic = rep.cod_dw_persona_ubic
LEFT JOIN bdm_datos.catalogo_sector_financiero sf
  ON sf.id_buro_suscriptor = rep.id_buro_suscriptor
INNER JOIN (
  SELECT r2.id_buro_persona, COUNT(DISTINCT cd2.texto_ubicacion) AS conteo_direcciones
  FROM bdm_tempo.v_rpu_post_unificacion r2
  INNER JOIN bdm_tempo.v_xpm_contacto_direccion cd2
    ON cd2.cod_dw_persona_ubic = r2.cod_dw_persona_ubic
  WHERE COALESCE(r2.ind_unificacion, 0) <> 1
  GROUP BY 1
) dir_cnt ON dir_cnt.id_buro_persona = rpu.id_buro_persona
WHERE COALESCE(rpu.ind_unificacion, 0) <> 1
WITH NO SCHEMA BINDING;

-- -- Insumo TEL --
CREATE OR REPLACE VIEW bdm_datos.insumo_telefono AS
SELECT
  c.cod_dw_persona_ubic,
  c.cod_pin_persona,
  c.id_buro_persona,
  COALESCE(ref.dir_ref, c.texto_ubicacion_vinculo, c.valor_contacto) AS direccion_fisica,
  c.cod_dane_ciudad,
  CASE
    WHEN c.valor_contacto ~ '^[0-9]+$' AND LENGTH(TRIM(c.valor_contacto)) >= 7 THEN 'VALIDA'
    ELSE 'NO VALIDA'
  END AS descripcion_gestion,
  c.id_buro_suscriptor,
  COALESCE(c.fecha_contacto, CURRENT_DATE) AS fecha_reporte,
  GREATEST(DATEDIFF(month, COALESCE(c.fecha_contacto, CURRENT_DATE), CURRENT_DATE), 0) AS meses_reporte,
  0 AS coincidencia_geo,
  COALESCE(sf.sector_financiero, 0) AS sector_financiero,
  COALESCE(tcat.tipo_cuenta, 'FIJA') AS tipo_cuenta
FROM bdm_tempo.v_xpm_contacto_canal c
INNER JOIN bdm_tempo.v_xpm_persona_dir_ganadora pg
  ON pg.id_buro_persona = c.id_buro_persona
LEFT JOIN bdm_datos.catalogo_sector_financiero sf
  ON sf.id_buro_suscriptor = c.id_buro_suscriptor
LEFT JOIN bdm_datos.catalogo_tipo_cuenta_tel tcat
  ON tcat.prefijo_operador = LEFT(LTRIM(c.valor_contacto, '0'), 3)
LEFT JOIN (
  SELECT r.id_buro_persona, MIN(u.texto_ubicacion) AS dir_ref
  FROM bdm_tempo.v_rpu_post_unificacion r
  INNER JOIN bdm_tempo.v_xpm_ubicacion_estandarizada u ON r.cod_dw_ubic = u.cod_dw_ubic
  WHERE COALESCE(r.ind_unificacion, 0) <> 1
  GROUP BY 1
) ref ON ref.id_buro_persona = c.id_buro_persona
-- 2026-10-20: el canal lo decide v_xpm_contacto_canal (TEL = 4, 5, 6 y 13
-- fijos). Antes era IN ('4','5','8') y el 8 es direccion (D-EDF-08).
WHERE c.canal = 'TEL'
  AND c.valor_contacto IS NOT NULL
WITH NO SCHEMA BINDING;

-- -- Insumo CEL --
CREATE OR REPLACE VIEW bdm_datos.insumo_celular AS
SELECT
  c.cod_dw_persona_ubic,
  c.cod_pin_persona,
  c.id_buro_persona,
  LTRIM(c.valor_contacto, '0') AS celular,
  COALESCE(ref.dir_ref, c.texto_ubicacion_vinculo) AS texto_ubicacion,
  c.id_buro_suscriptor,
  COALESCE(c.fecha_contacto, CURRENT_DATE) AS fecha_reporte,
  GREATEST(DATEDIFF(month, COALESCE(c.fecha_contacto, CURRENT_DATE), CURRENT_DATE), 0) AS meses_reporte,
  LEFT(LTRIM(c.valor_contacto, '0'), 3) AS operador,
  COALESCE(sf.sector_financiero, 0) AS sector_financiero,
  COALESCE(tcat.tipo_cuenta, 'PREPAGO') AS tipo_cuenta
FROM bdm_tempo.v_xpm_contacto_canal c
INNER JOIN bdm_tempo.v_xpm_persona_dir_ganadora pg
  ON pg.id_buro_persona = c.id_buro_persona
LEFT JOIN bdm_datos.catalogo_sector_financiero sf
  ON sf.id_buro_suscriptor = c.id_buro_suscriptor
LEFT JOIN bdm_datos.catalogo_tipo_cuenta_tel tcat
  ON tcat.prefijo_operador = LEFT(LTRIM(c.valor_contacto, '0'), 3)
LEFT JOIN (
  SELECT r.id_buro_persona, MIN(u.texto_ubicacion) AS dir_ref
  FROM bdm_tempo.v_rpu_post_unificacion r
  INNER JOIN bdm_tempo.v_xpm_ubicacion_estandarizada u ON r.cod_dw_ubic = u.cod_dw_ubic
  WHERE COALESCE(r.ind_unificacion, 0) <> 1
  GROUP BY 1
) ref ON ref.id_buro_persona = c.id_buro_persona
WHERE c.canal = 'CEL'   -- 2026-10-20: 9 y 4/5/6/13 celulares (D-EDF-11)
  AND c.valor_contacto IS NOT NULL
WITH NO SCHEMA BINDING;

-- -- Insumo EMA --
CREATE OR REPLACE VIEW bdm_datos.insumo_email AS
SELECT
  c.cod_dw_persona_ubic,
  c.cod_pin_persona,
  c.id_buro_persona,
  LOWER(TRIM(c.valor_contacto)) AS email,
  LOWER(SPLIT_PART(TRIM(c.valor_contacto), '@', 2)) AS dominio,
  c.id_buro_suscriptor,
  COALESCE(c.fecha_contacto, CURRENT_DATE) AS fecha_reporte,
  GREATEST(DATEDIFF(month, COALESCE(c.fecha_contacto, CURRENT_DATE), CURRENT_DATE), 0) AS meses_reporte,
  COALESCE(sf.sector_financiero, 0) AS sector_financiero,
  CASE WHEN LOWER(SPLIT_PART(TRIM(c.valor_contacto), '@', 2)) IN
    ('gmail.com','hotmail.com','yahoo.com','outlook.com') THEN 'PERSONAL' ELSE 'CORPORATIVO' END AS tipo_cuenta
FROM bdm_tempo.v_xpm_contacto_canal c
INNER JOIN bdm_tempo.v_xpm_persona_dir_ganadora pg
  ON pg.id_buro_persona = c.id_buro_persona
LEFT JOIN bdm_datos.catalogo_sector_financiero sf
  ON sf.id_buro_suscriptor = c.id_buro_suscriptor
WHERE c.canal = 'EMA'
  AND c.valor_contacto LIKE '%@%'
WITH NO SCHEMA BINDING;

-- Smoke: insumos son vistas (no tablas)
SELECT 'v_rpu_post_unificacion' AS obj, COUNT(*)::BIGINT AS n FROM bdm_tempo.v_rpu_post_unificacion
UNION ALL SELECT 'insumo_dir_vista', COUNT(*) FROM bdm_datos.insumo_direccion
UNION ALL SELECT 'rpu_ganadoras_vista', COUNT(*) FROM bdm_tempo.v_rpu_post_unificacion WHERE COALESCE(ind_unificacion,0)<>1
UNION ALL SELECT 'rpu_hijas_vista', COUNT(*) FROM bdm_tempo.v_rpu_post_unificacion WHERE COALESCE(ind_unificacion,0)=1;

-- Redefinir filtro personas ganadoras (ya no depende de tabla local)
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_persona_dir_ganadora AS
SELECT DISTINCT id_buro_persona
FROM bdm_tempo.v_rpu_post_unificacion
WHERE COALESCE(ind_unificacion, 0) <> 1
WITH NO SCHEMA BINDING;


-- ============================================================
-- v_xpm_cuenta: EL CONTRATO DE LA FASE 2, YA CON FUENTE (2026-10-21)
--
-- ESTA VISTA DEVOLVIA CERO FILAS A PROPOSITO Y YA NO. La cabecera anterior
-- decia que la fuente quedaba pendiente "el dia que la llave se verifique",
-- citando docs/MAPEO_DESBLOQUEO_DATASHARE_ORDENAMIENTO.md:184-188:
--
--   "Lo que no se hace: escribir nada sobre xpm_bestaccounts todavia. Su
--    relacion con xpm_location por accountnumber esta sin verificar..."
--
-- ESA CONDICION ESTA CUMPLIDA. Medido contra el productor (C33b, C38 y C39,
-- RESULTADOS seccion 19.1 y D-EDF-15):
--   * el contenedor bestaccounts es 1:1 con la persona -- 98.586 de 98.586
--     tienen exactamente UNA --, de modo que no colapsa cuentas de personas
--     distintas, que era el riesgo que esa decision protegia;
--   * la llave de seis partes (contenedor mas los cinco campos de Data
--     Provisioning) casa sin un solo falso positivo;
--   * unir solo por numero de cuenta SI es falso: 5.802 pares contra 278, y
--     el 95 % son de otra cuenta de la misma persona. Por eso aqui no se
--     afloja la llave.
--
-- LO QUE HOY NO TRAE DATO NO ES LA LLAVE, ES EL ORIGEN: solo 146 de 98.586
-- personas tienen alguna cuenta en DEV y QA (7.759 filas en 146
-- contenedores). La vista queda CABLEADA para que el dia que Experian pueble
-- bestaccounts -- demo y produccion -- la Fase 2 real funcione sin tocar
-- codigo. Decision del usuario, 2026-10-21: no es bloqueante.
--
-- DOS COLUMNAS SE QUEDAN EN NULL Y ESTA ESCRITO DONDE: cod_tipo_obligacion_fte
-- y numero_dias_mora. Las dos tienen mas de un candidato en el datashare y
-- las dos entran en el clasificador Portafolio, que decide el Sector y el
-- Sector entra en el score. Elegir mal seria una divergencia disfrazada de
-- dato. Se preguntan antes de cablearlas.
--
-- El mock NO pasa por aqui: lee bdm_stage.mock_cuenta por su propio espejo,
-- de modo que el tablero no se mueve.
-- WITH NO SCHEMA BINDING como todas las de este archivo.
-- ============================================================

CREATE OR REPLACE VIEW bdm_tempo.v_xpm_cuenta AS
SELECT
  -- cod_dw_cta: SURROGADA, igual que cod_dw_persona_ubic. El legado tiene un
  -- Cod_DW_Cta propio y el datashare no lo expone, de modo que se deriva de
  -- (id, index), que es unico por cuenta dentro del contenedor. Mismo idioma
  -- que las demas llaves (02_vistas_insumo_edf_views.sql).
  FNV_HASH(CAST(ba.id AS VARCHAR) || ':' || CAST(ba."index" AS VARCHAR))  AS cod_dw_cta,
  FNV_HASH(CAST(xpm.pin AS VARCHAR))                                      AS id_buro_persona,
  CAST(xpm.pin AS BIGINT)                                                 AS cod_pin_persona,
  -- El cod_suscriptor del legado son SEIS digitos y businesslinecode viene
  -- con seis (C33b: len 6 en los dos lados). SUBSTRING por si alguno llega
  -- mas largo: un CHAR(6) truncaria en silencio.
  CAST(SUBSTRING(NULLIF(TRIM(ba."bestaccounts.val.businesslinecode"::VARCHAR), ''), 1, 6) AS CHAR(6))
                                                                          AS cod_suscriptor,
  CAST(NULLIF(TRIM(ba."bestaccounts.val.accounttype"::VARCHAR), '') AS VARCHAR(10))
                                                                          AS cod_tipo_cta_fte,
  -- cod_tipo_obligacion_fte: SIN FUENTE CONFIRMADA, y por eso NULL.
  -- Los candidatos son typeofcredit (catalogo 18_SUBSCRIBER_TYPE_OF_CREDIT_NH)
  -- y subaccounttype (238_SUBSCRIBER_SUB_ACCOUNT_TYPE_NH). Elegir mal cambia
  -- una de las NUEVE columnas del clasificador Portafolio, asi que se deja
  -- NULL y el CASE cae a su rama ELSE, que es lo que el legado hace sin dato.
  CAST(NULL AS VARCHAR(10))                                               AS cod_tipo_obligacion_fte,
  -- tipo de relacion con la cuenta: typeofdebtor. CONFIRMADO en RESULTADOS
  -- seccion 18 con los catalogos 15, 16 y 17 (00 principal, 01 codeudor,
  -- 04 avalista, 05 deudor solidario, 96 cotitular...).
  CAST(NULLIF(TRIM(ba."bestaccounts.val.typeofdebtor"::VARCHAR), '') AS VARCHAR(10))
                                                                          AS cod_tipo_rel_con_cta_fte,
  -- clase de garantia: guaranteetype (catalogo 8_SUBSCRIBER_GUARANTEE_TYPE_NH).
  -- NO es guaranteedetail (101 y 226), que es el detalle y no la clase.
  CAST(ba."bestaccounts.val.guaranteetype" AS VARCHAR(10))                AS cod_clase_garantia_buro_fte,
  CAST(ba."bestaccounts.val.totalnumberofinstallments" AS INTEGER)        AS num_cuotas_pactadas,
  CASE WHEN ba."bestaccounts.val.cutoffdate" IS NOT NULL
       THEN bdm_datos.convert_epoch_to_date(CAST(ba."bestaccounts.val.cutoffdate" AS BIGINT))
       ELSE NULL
  END                                                                     AS fecha_nov,
  -- Las tres de valor viven en el comportamiento, no en la cuenta, y se toman
  -- de la fila MAS RECIENTE por behaviourdate (fb.rn = 1).
  CAST(fb.debtbalance        AS DECIMAL(18,2))                            AS valor_saldo,
  CAST(fb.valuemonthlypayment AS DECIMAL(18,2))                           AS valor_cuota_mensual,
  -- numero_dias_mora: SIN FUENTE CONFIRMADA, y por eso NULL. Los candidatos
  -- son businessdelinquencymaturation (maduracion de la mora, en el
  -- comportamiento) e installmentsoverdue (cuotas vencidas, que NO son dias).
  -- Misma regla que arriba: antes de elegir, preguntar.
  CAST(NULL AS INTEGER)                                                   AS numero_dias_mora,
  CAST(fb.paidinstallments AS INTEGER)                                    AS num_cuotas_pagadas
FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts ba
INNER JOIN ds_dba_rncr_batch.edf_views.xpm xpm
        ON xpm.bestaccounts = ba.id
LEFT JOIN (
  SELECT fb0.id,
         fb0."bestaccounts.val.frequentbehaviour.val.debtbalance"        AS debtbalance,
         fb0."bestaccounts.val.frequentbehaviour.val.valuemonthlypayment" AS valuemonthlypayment,
         fb0."bestaccounts.val.frequentbehaviour.val.paidinstallments"    AS paidinstallments,
         ROW_NUMBER() OVER (
           PARTITION BY fb0.id
           ORDER BY fb0."bestaccounts.val.frequentbehaviour.val.behaviourdate" DESC NULLS LAST,
                    fb0."index" DESC )                                    AS rn
  FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts_val_frequentbehaviour fb0
  WHERE fb0."index" IS NOT NULL
) fb
  ON  fb.id = ba."bestaccounts.val.frequentbehaviour"
  AND fb.rn = 1
WHERE ba."index" IS NOT NULL
WITH NO SCHEMA BINDING;

-- El comportamiento, con el MISMO cod_dw_cta que la vista de arriba.
--
-- LO QUE FALTA AQUI, Y ES CATALOGO, NO CODIGO: el legado parte el
-- comportamiento en dos tablas, ACTIVO y PASIVO, y el Ordenamiento las lee
-- como 'A' y 'P' (sp_ordenamiento_cuentas_edf.sql:107 y :115). En EDF hay UNA
-- sola tabla de comportamiento y nada que diga de que lado cae cada cuenta:
-- activo y pasivo son categorias del PRODUCTO (credito contra captacion), de
-- modo que la regla sale del tipo de cuenta y de un catalogo que no tenemos.
-- Se deja tipo en NULL A PROPOSITO: con NULL los dos predicados fallan y las
-- dos banderas salen 'N', que es lo que hoy es cierto. Inventar la regla
-- marcaria mal DOS de las nueve columnas del Portafolio, y el Portafolio
-- decide el Sector, que entra en el score.
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_comportamiento_cta AS
SELECT
  FNV_HASH(CAST(ba.id AS VARCHAR) || ':' || CAST(ba."index" AS VARCHAR))  AS cod_dw_cta,
  CAST(NULL AS CHAR(1))                                                   AS tipo,
  CASE WHEN fb."bestaccounts.val.frequentbehaviour.val.behaviourdate" IS NOT NULL
       THEN bdm_datos.convert_epoch_to_date(
              CAST(fb."bestaccounts.val.frequentbehaviour.val.behaviourdate" AS BIGINT))
       ELSE NULL
  END                                                                     AS fecha_corte
FROM ds_dba_rncr_batch.edf_views.xpm_bestaccounts ba
INNER JOIN ds_dba_rncr_batch.edf_views.xpm_bestaccounts_val_frequentbehaviour fb
        ON fb.id = ba."bestaccounts.val.frequentbehaviour"
       AND fb."index" IS NOT NULL
WHERE ba."index" IS NOT NULL
WITH NO SCHEMA BINDING;
