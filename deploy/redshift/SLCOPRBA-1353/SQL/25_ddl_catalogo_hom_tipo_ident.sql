-- ============================================================
-- 25_ddl_catalogo_hom_tipo_ident.sql
-- 2026-10-21. Catalogo de homologacion del TIPO DE IDENTIFICACION a Linea.
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- UTF-8 sin BOM. ASCII sin acentos a proposito.
--
-- ORIGEN: volcado de REC_VISTA.V_Hom_Tip_Ident_Linea del Teradata de origen,
-- entregado en CSV por el usuario el 2026-10-21 (columnas
-- Cod_Dw_Hom_Tip_Ident_Linea, Descripcion_Hom_Tip_Ident_Linea, Valor_Fuente,
-- Cod_DW_Pais). ONCE filas.
--
-- SE PERSISTEN LAS DOS QUE EL LEGADO USA, igual que en el catalogo de tipo de
-- cuenta: el join es por Valor_Fuente y lo que se lee es la descripcion
--   Novedad.sql:3475-3476 -- "LEFT JOIN V_Hom_Tip_Ident_Linea h1
--     ON COALESCE(COD_TIPO_IDENT_FTE_2, COD_TIPO_IDENT_FTE) = h1.Valor_Fuente"
--   Novedad.sql:3455 -- "h1.Descripcion_Hom_Tip_Ident_Linea AS TIPO_IDENTIFICACION"
-- Cod_Dw_Hom_Tip_Ident_Linea no lo usa nadie y Cod_DW_Pais vale 1 en las
-- once: no se traen.
--
-- VALOR_FUENTE VA VARCHAR Y NO INTEGER, y no es un detalle. El legado une
-- contra COD_TIPO_IDENT_FTE, que en PRO_UnificacionR2.sql es
-- CAST(NULL AS VARCHAR(20)) y se usa como llave de texto; nuestras vistas lo
-- exponen igual, VARCHAR(20), por la leccion del job #293 (un personidtype
-- de mas de diez digitos aborta el cast a INTEGER). Declararlo INTEGER aqui
-- forzaria un cast en cada join y reabriria ese fallo.
--
-- TRES CONSUMIDORES, y los tres escribian NULL hasta hoy:
--   1. mat_info_basica.tipo_identificacion        (d4)
--   2. stg_nov_ubica_etapa_9.tipo_identificacion  (NOV-UB-18)
--   3. stg_nov_acteco_etapa_1.tipo_identificacion (NOV-AE-07)
--
-- EL DOMINIO ES COMPLETO para lo que el datashare entrega, al contrario del
-- catalogo de tipo de cuenta: los once Valor_Fuente cubren 0..10 sin huecos,
-- de modo que cualquier personidtype de un digito casa. Un valor fuera de
-- ese rango caeria por LEFT JOIN a NULL, que es lo que hace el legado.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_hom_tipo_ident (
  valor_fuente VARCHAR(20),
  descripcion  VARCHAR(30)
)
DISTSTYLE ALL;   -- 11 filas: replicarlo cuesta menos que redistribuirlo

TRUNCATE TABLE bdm_datos.catalogo_hom_tipo_ident;

-- El CAST de la primera rama fija el tipo del nodo UNION ALL.
INSERT INTO bdm_datos.catalogo_hom_tipo_ident (valor_fuente, descripcion)
  SELECT CAST('0' AS VARCHAR(20)), CAST('OTS' AS VARCHAR(30)) UNION ALL
  SELECT  '1', 'CC'      UNION ALL
  SELECT  '2', 'NIT'     UNION ALL
  SELECT  '3', 'NIT_EXT' UNION ALL
  SELECT  '4', 'CE'      UNION ALL
  SELECT  '5', 'PA'      UNION ALL
  SELECT  '6', 'CDP'     UNION ALL
  SELECT  '7', 'TI'      UNION ALL
  SELECT  '8', 'DNI'     UNION ALL
  SELECT  '9', 'PEP'     UNION ALL
  SELECT '10', 'RC';
