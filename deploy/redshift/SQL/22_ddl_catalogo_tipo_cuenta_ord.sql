-- ============================================================
-- 22_ddl_catalogo_tipo_cuenta_ord.sql
-- SLCOPRBA-1355. Catalogo de pesos por tipo de cuenta del Ordenamiento.
-- UTF-8 sin BOM. ASCII sin acentos a proposito.
--
-- ORIGEN: volcado de REC_VISTA.V_Tipo_Cuenta_Ord del Teradata de origen,
-- entregado en CSV (columnas Cod_DW_Beta_Ord_Cel, Cod_Tipo_Cta_Fte, Valor,
-- Cod_DW_Pais). Se persisten las DOS que el legado usa:
--   Caracteristicas.txt:112 -- "ON CAST(CTAP.Cod_Tipo_Cta_Fte AS INTEGER)
--                               = TCO.Cod_Tipo_Cta_Fte" ... "MAX(TCO.Valor)"
-- Cod_DW_Beta_Ord_Cel no se usa en ninguna parte del legado y Cod_DW_Pais
-- vale 1 en las 44 filas: no se traen.
--
-- UNICO CONSUMIDOR: CO01CEL019. Verificado con un grep del arbol completo
-- del legado (src/ y data/): una sola referencia, la de arriba.
--
-- EL DOMINIO NO ESTA COMPLETO, Y ESO NO ES UN ERROR DE CARGA.
--   El catalogo trae 44 codigos. Faltan el 17, 25, 26, 34, 37, 50 y 51.
--   Un hallazgo previo del workspace deja constancia de que el datashare
--   entrega justo '17', '34' y '51' en accounttype, mas un valor vacio.
--
--   El legado los deja caer por LEFT JOIN a NULL, y su CASE de categoria
--   (Caracteristicas.txt:151) no tiene rama IS NULL: las tres comparaciones
--   evaluan UNKNOWN y la fila cae al ELSE 0. Es decir que un fallo de
--   catalogo es INDISTINGUIBLE de un tipo de cuenta de peso minimo: no hay
--   error, no hay NULL aguas abajo y no se pierde la fila.
--
--   Se porta tal cual. Por eso queda escrito aqui: esos siete codigos no
--   van a dar la cara solos en ninguna corrida.
-- ============================================================

CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_tipo_cuenta_ord (
  cod_tipo_cta_fte INTEGER,
  valor            INTEGER
)
DISTSTYLE ALL;   -- 44 filas: replicarlo cuesta menos que redistribuirlo

TRUNCATE TABLE bdm_datos.catalogo_tipo_cuenta_ord;

-- El CAST de la primera rama fija el tipo del nodo UNION ALL.
INSERT INTO bdm_datos.catalogo_tipo_cuenta_ord (cod_tipo_cta_fte, valor)
  SELECT CAST( 1 AS INTEGER), CAST( 10 AS INTEGER) UNION ALL
  SELECT  2, 100 UNION ALL SELECT  3,  80 UNION ALL SELECT  4,  10 UNION ALL
  SELECT  5,  70 UNION ALL SELECT  6,  10 UNION ALL SELECT  7,  90 UNION ALL
  SELECT  8,  10 UNION ALL SELECT  9,  90 UNION ALL SELECT 10,  40 UNION ALL
  SELECT 11,  50 UNION ALL SELECT 12,  10 UNION ALL SELECT 13,  90 UNION ALL
  SELECT 14, 100 UNION ALL SELECT 15,  60 UNION ALL SELECT 16,  70 UNION ALL
  SELECT 18,  40 UNION ALL SELECT 19,  10 UNION ALL SELECT 20,  80 UNION ALL
  SELECT 21,  10 UNION ALL SELECT 22,  10 UNION ALL SELECT 23,  50 UNION ALL
  SELECT 24,  80 UNION ALL SELECT 27,  70 UNION ALL SELECT 28,  10 UNION ALL
  SELECT 29,  10 UNION ALL SELECT 30, 100 UNION ALL SELECT 31,  10 UNION ALL
  SELECT 32,  80 UNION ALL SELECT 33,  50 UNION ALL SELECT 35,  40 UNION ALL
  SELECT 36,  10 UNION ALL SELECT 38,  10 UNION ALL SELECT 39,  10 UNION ALL
  SELECT 40,  10 UNION ALL SELECT 41,  10 UNION ALL SELECT 42,  50 UNION ALL
  SELECT 43,  10 UNION ALL SELECT 44,  90 UNION ALL SELECT 45,  60 UNION ALL
  SELECT 46,  10 UNION ALL SELECT 47,  60 UNION ALL SELECT 48, 100 UNION ALL
  SELECT 49,  50;
