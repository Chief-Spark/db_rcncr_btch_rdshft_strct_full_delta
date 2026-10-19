-- ============================================================
-- 04_vistas_sin_copia_productor.sql
-- Reemplaza materializacion de RPU e insumos: lectura via datashare.
-- PRECONDICION: unificacion ejecutada (unificacion_direccion poblada).
-- ============================================================

-- Salida ordenamiento: solo prioridad por RPU (no copiar universo XPM)
CREATE TABLE IF NOT EXISTS bdm_datos.rpu_orden_prioridad (
  cod_dw_persona_ubic  BIGINT  ENCODE AZ64,
  id_buro_persona      BIGINT  ENCODE AZ64,
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
WHERE c.contact_type IN ('4', '5', '8')
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
WHERE c.contact_type = '9'
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
WHERE c.contact_type = '10'
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
-- SLCOPRBA-1355 -- v_xpm_cuenta: EL CONTRATO DE LA FASE 2, SIN FUENTE TODAVIA
--
-- LEER ESTO ANTES DE "ARREGLARLA": LA VISTA DEVUELVE CERO FILAS A PROPOSITO.
--
-- La Fase 2 necesita las nueve columnas del clasificador Portafolio
-- (PRO_ORD_CTA_TOTALES_PERSONAS_2.sql:304-375). El candidato del datashare es
-- edf_views.xpm_bestaccounts (~80 columnas), y sobre el hay una decision ya
-- tomada y escrita en docs/MAPEO_DESBLOQUEO_DATASHARE_ORDENAMIENTO.md:184-188:
--
--   "Lo que no se hace: escribir nada sobre xpm_bestaccounts todavia. Su
--    relacion con xpm_location por accountnumber esta sin verificar, y el
--    legado advierte que la llave natural de una cuenta no es
--    (accountnumber, accounttype) sino al menos
--    (Num_Cta, Cod_Tipo_Cta_Fte, Id_Buro_Suscriptor)."
--
-- Adivinar ese mapeo para que el SP "tenga de donde leer" seria justo lo que
-- esa decision prohibe, y una llave mal elegida colapsaria cuentas igual que
-- el (id, index) colapsa contactos en Unificacion.
--
-- ASI QUE SE DECLARA EL CONTRATO Y SE DEJA LA FUENTE PENDIENTE. Cero filas
-- hace que la via REAL de la Fase 2 no produzca nada -- que es exactamente lo
-- cierto hoy -- en vez de reventar al primer CALL, y mantiene la paridad con
-- el espejo mock, que SI tiene datos. El dia que la llave se verifique, se
-- cambia el FROM de esta vista y no se toca ni una linea de los dos SP.
--
-- WITH NO SCHEMA BINDING como todas las de este archivo.
-- ============================================================

CREATE OR REPLACE VIEW bdm_tempo.v_xpm_cuenta AS
SELECT
  CAST(NULL AS BIGINT)        AS cod_dw_cta,
  CAST(NULL AS BIGINT)        AS id_buro_persona,
  CAST(NULL AS BIGINT)        AS cod_pin_persona,
  CAST(NULL AS CHAR(6))       AS cod_suscriptor,
  CAST(NULL AS VARCHAR(10))   AS cod_tipo_cta_fte,
  CAST(NULL AS VARCHAR(10))   AS cod_tipo_obligacion_fte,
  CAST(NULL AS VARCHAR(10))   AS cod_tipo_rel_con_cta_fte,
  CAST(NULL AS VARCHAR(10))   AS cod_clase_garantia_buro_fte,
  CAST(NULL AS INTEGER)       AS num_cuotas_pactadas,
  CAST(NULL AS DATE)          AS fecha_nov,
  CAST(NULL AS DECIMAL(18,2)) AS valor_saldo,
  CAST(NULL AS DECIMAL(18,2)) AS valor_cuota_mensual,
  CAST(NULL AS INTEGER)       AS numero_dias_mora,
  CAST(NULL AS INTEGER)       AS num_cuotas_pagadas
FROM bdm_stage.mock_numeros
WHERE 1 = 0
WITH NO SCHEMA BINDING;

-- Mismo trato para el comportamiento: el contrato declarado, la fuente
-- pendiente. El legado lo tiene en dos tablas y las lee como "existe fila".
CREATE OR REPLACE VIEW bdm_tempo.v_xpm_comportamiento_cta AS
SELECT
  CAST(NULL AS BIGINT)  AS cod_dw_cta,
  CAST(NULL AS CHAR(1)) AS tipo,
  CAST(NULL AS DATE)    AS fecha_corte
FROM bdm_stage.mock_numeros
WHERE 1 = 0
WITH NO SCHEMA BINDING;
