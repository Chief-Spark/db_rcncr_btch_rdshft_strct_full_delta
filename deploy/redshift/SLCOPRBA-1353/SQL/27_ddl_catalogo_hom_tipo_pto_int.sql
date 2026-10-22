-- ============================================================
-- 27_ddl_catalogo_hom_tipo_pto_int.sql
-- 2026-10-22. Catalogo de homologacion del TIPO DE PUNTO DE INTERES a Linea.
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- UTF-8 sin BOM. ASCII sin acentos a proposito.
--
-- ORIGEN: volcado de REC_VISTA.V_Hom_Tipo_Pto_Int_Linea del Teradata de
-- origen, entregado en CSV por el usuario el 2026-10-22. TREINTA Y CUATRO
-- filas, doce descripciones distintas, sin un solo Valor_Fuente repetido:
-- el join no multiplica.
--
-- SE PERSISTEN LAS DOS QUE EL LEGADO USA (Novedad.sql:4879, :4891):
--   TIPO = h2.Descripcion_Hom_Tipo_Pto_Int_Linea
--   LEFT JOIN V_Hom_Tipo_Pto_Int_Linea h2
--     ON PIET1.Cod_Tipo_Punto_Interes_Host = H2.Valor_Fuente
-- Cod_Dw_Hom_Tipo_Pto_Int_Linea no lo lee nadie y Cod_DW_Pais vale 1 en las
-- treinta y cuatro.
--
-- ------------------------------------------------------------
-- LA LLAVE DEL JOIN ES UNA HIPOTESIS, Y HAY QUE DECIRLO. En el legado,
-- Cod_Tipo_Punto_Interes_Host es una columna de V_TIPO_PUNTO_INTERES
-- (Novedad.sql:4806, :4811), que es el OTRO catalogo de puntos de interes y
-- que NO se ha entregado. Nosotros no lo tenemos, de modo que unimos por
-- geo_distancias.tipo_punto_interes, la col07 del contrato
-- Salida_Distancias, que es el tipo tal y como lo manda ArcGIS.
--   LO QUE SOSTIENE LA HIPOTESIS: los 34 Valor_Fuente son codigos SIC de
--   cuatro digitos y casan con su descripcion uno a uno -- 3578 es cajero
--   (CAJ_ELE), 6000 banca (ENT_FIN), 5800 restaurantes (RESTAU), 5511 y
--   5512 concesionarios (CONSE) --, que es justo la taxonomia con la que
--   ArcGIS clasifica un POI.
--   LO QUE NO ESTA PROBADO: que col07 traiga ese codigo y no la descripcion.
--   No hay con que comprobarlo hoy: en mock geo_distancias esta vacia y en
--   DEV todavia no ha llegado un archivo de distancias real.
--   COMO SE CIERRA, EN UNA CONSULTA, EL DIA QUE LLEGUE UNO:
--     SELECT COUNT(*) AS filas,
--            COUNT(c.descripcion) AS casan
--     FROM bdm_datos.geo_distancias d
--     LEFT JOIN bdm_datos.catalogo_hom_tipo_pto_int c
--       ON c.valor_fuente = d.tipo_punto_interes;
--   Si `casan` sale 0, la llave es otra y el sitio de la correccion es el
--   join de sp_novedades_punto_interes_{edf,mock}.
--
-- EL RIESGO DE CABLEARLO ANTES DE PROBARLO ES NULO, y por eso se cablea: va
-- por LEFT JOIN, de modo que una llave equivocada deja `tipo` en NULL, que
-- es exactamente donde esta hoy. No puede escribir un valor erroneo salvo
-- que los dos sistemas de codigos se solapen, y uno es SIC de cuatro
-- digitos.
--
-- V_Corr_Tipo_Pto_Int_Linea NO SE PIDE NI SE PORTA: el legado la une
-- (Novedad.sql:4886-4887) y no proyecta ni una columna suya. Es un join
-- muerto, como TMP_UBICA_ETAPA_0.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_hom_tipo_pto_int (
  valor_fuente VARCHAR(60),   -- igual que geo_distancias.tipo_punto_interes
  descripcion  VARCHAR(30)    -- igual que mat_info_punto_interes.tipo
)
DISTSTYLE ALL;   -- 34 filas: replicarlo cuesta menos que redistribuirlo

TRUNCATE TABLE bdm_datos.catalogo_hom_tipo_pto_int;

-- El CAST de la primera rama fija el tipo del nodo UNION ALL.
INSERT INTO bdm_datos.catalogo_hom_tipo_pto_int (valor_fuente, descripcion)
  SELECT CAST('3578' AS VARCHAR(60)), CAST('CAJ_ELE' AS VARCHAR(30)) UNION ALL
  SELECT '4493', 'ENTRET' UNION ALL
  SELECT '5511', 'CONSE' UNION ALL
  SELECT '5512', 'CONSE' UNION ALL
  SELECT '5571', 'CONSE' UNION ALL
  SELECT '5800', 'RESTAU' UNION ALL
  SELECT '5813', 'ENTRET' UNION ALL
  SELECT '6000', 'ENT_FIN' UNION ALL
  SELECT '6512', 'CEN_COM' UNION ALL
  SELECT '7832', 'ENTRET' UNION ALL
  SELECT '7929', 'ENTRET' UNION ALL
  SELECT '7933', 'ENTRET' UNION ALL
  SELECT '7940', 'ENTRET' UNION ALL
  SELECT '7947', 'PARQUE' UNION ALL
  SELECT '7985', 'ENTRET' UNION ALL
  SELECT '7992', 'CLUB' UNION ALL
  SELECT '7994', 'ENTRET' UNION ALL
  SELECT '7996', 'ENTRET' UNION ALL
  SELECT '7997', 'ENTRET' UNION ALL
  SELECT '7998', 'ENTRET' UNION ALL
  SELECT '8060', 'SALUD' UNION ALL
  SELECT '8231', 'ENTRET' UNION ALL
  SELECT '8410', 'ENTRET' UNION ALL
  SELECT '9121', 'SER_ADM' UNION ALL
  SELECT '9211', 'SER_ADM' UNION ALL
  SELECT '9221', 'SER_ADM' UNION ALL
  SELECT '9517', 'PARQUE' UNION ALL
  SELECT '9525', 'SER_ADM' UNION ALL
  SELECT '9583', 'SALUD' UNION ALL
  SELECT '9714', 'MENSAJE' UNION ALL
  SELECT '9986', 'TELCO' UNION ALL
  SELECT '9993', 'SER_ADM' UNION ALL
  SELECT '9994', 'SER_ADM' UNION ALL
  SELECT '9996', 'RESTAU';
