-- ============================================================
-- 26_ddl_catalogo_movilidad.sql
-- 2026-10-22. Los DOS catalogos de INDICADORES DE MOVILIDAD (d6).
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- UTF-8 sin BOM. ASCII sin acentos a proposito.
--
-- ORIGEN: volcado de REC_VISTA.V_INDICADOR_MOVILIDAD (5 filas) y de
-- REC_VISTA.V_Hom_Ind_Mov_Linea (4 filas) del Teradata de origen, entregado
-- en CSV por el usuario el 2026-10-22. Son dos de los catalogos que
-- docs/PETICION_CATALOGOS_NOVEDADES.md pedia y que
-- sp_novedades_movilidad_edf.sql nombraba en redondo:
--   "descripcion y novedad_2 van NULL: faltan V_INDICADOR_MOVILIDAD y
--    V_Hom_Ind_Mov_Linea".
--
-- ------------------------------------------------------------
-- LOS NOMBRES DE LAS COLUMNAS DEL LEGADO ESTAN CRUZADOS, Y HAY QUE SABERLO
-- ANTES DE CABLEAR NADA. En V_INDICADOR_MOVILIDAD:
--   Descripcion_Indicador_Movilida  lleva el NOMBRE CORTO ('Cambio de Ciudad')
--   Valor_Indicador_Movilidad       lleva la FRASE LARGA  ('Indica un ...')
-- y el legado los reparte al reves de lo que sugieren esos nombres
-- (Novedad.sql:1782-1783):
--   DESCRIPCION = VIM.VALOR_INDICADOR_MOVILIDAD       -> la frase larga
--   NOVEDAD     = VIM.DESCRIPCION_INDICADOR_MOVILIDA  -> el nombre corto
-- Nuestro port ya escribia el nombre corto en `novedad`, de modo que esa
-- columna estaba bien; la que faltaba es `descripcion`, y es la frase.
--
-- EN V_Hom_Ind_Mov_Linea PASA LO MISMO:
--   Valor_Fuente                   lleva el nombre corto (la llave del join)
--   Descripcion_Hom_Ind_Mov_Linea  lleva el CODIGO de Linea ('CAM_EST')
-- y el join es NOVEDAD = h1.Valor_Fuente (Novedad.sql:1923-1924), con
-- NOVEDAD_2 = h1.Descripcion_Hom_Ind_Mov_Linea (:1991).
--
-- ------------------------------------------------------------
-- V_INDICADOR_MOVILIDAD TRAE CINCO FILAS Y CUATRO INDICADORES: 'Cambio de
-- Direccion' viene DOS VECES, 71948 y 77295, con la frase identica salvo la
-- tilde de direccion. El legado no lo nota porque une por
-- COD_DW_INDICADOR_MOVILIDAD, que es unico; nosotros no tenemos ese codigo
-- -- las ramas salen de literales -- y tenemos que unir por el nombre corto,
-- que con las cinco filas MULTIPLICARIA cada evento de direccion por dos.
-- Es el mismo fan-out que ya se pago con v_xpm_contacto_canal.
--   SE DESEMPATA POR MIN(Cod_DW_Indicador_Movilidad) = 71948, que ademas es
--   el de la banda 719xx de los otros tres (71947, 71949, 71950) y el unico
--   cuyo texto es ASCII. 77295 es un alta posterior, de la misma banda 77xxx
--   que los codigos de homologacion. Se descarta y queda escrito aqui.
--
-- ANCHOS: descripcion va VARCHAR(100) porque esa es la del contrato
-- (IN_DESCRIPCION VARCHAR(100), 130.TPT:137) y la de
-- mat_info_movilidad.descripcion. La frase mas larga es la de Localidad, 95
-- caracteres: entra por cinco. Declararla mas ancha aqui esconderia un
-- [REDSHIFT:112] hasta el INSERT de la tabla final.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- V_INDICADOR_MOVILIDAD: nombre corto -> frase larga.
-- La llave es el nombre corto porque es lo que nuestras ramas producen.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_indicador_movilidad (
  novedad     VARCHAR(1000),   -- Descripcion_Indicador_Movilida (nombre corto)
  descripcion VARCHAR(100)     -- Valor_Indicador_Movilidad (frase larga)
)
DISTSTYLE ALL;   -- 4 filas: replicarlo cuesta menos que redistribuirlo

TRUNCATE TABLE bdm_datos.catalogo_indicador_movilidad;

-- El CAST de la primera rama fija el tipo del nodo UNION ALL.
INSERT INTO bdm_datos.catalogo_indicador_movilidad (novedad, descripcion)
  SELECT CAST('Cambio de Direccion' AS VARCHAR(1000)),
         CAST('Indica un cambio de direccion durante una ventana de tiempo' AS VARCHAR(100))
  UNION ALL
  SELECT 'Cambio de Ciudad',
         'Indica un cambio de ciudad durante una ventana de tiempo'
  UNION ALL
  SELECT 'Cambio de Estrato',
         'Indica un cambio de estrato durante una ventana de tiempo'
  UNION ALL
  SELECT 'Cambio de Localidad',
         'Indica un cambio de localidad o comuna, dentro de la misma ciudad durante una ventana de tiempo';

-- ------------------------------------------------------------
-- V_Hom_Ind_Mov_Linea: nombre corto -> codigo de Linea.
--
-- CAM_LOC SALE DOS VECES, Y ESO CAMBIA LO QUE CUESTA EL INDICADOR QUE NO
-- PORTAMOS. 'Cambio de Direccion' y 'Cambio de Localidad' homologan los dos
-- a CAM_LOC, de modo que Linea NO distingue uno de otro. Y como las CUATRO
-- ramas del legado exigen CambioDir = 1
-- (P0029_INDICADORES_MOVILIDAD_111.BTQ:62-68), toda fila de Localidad
-- convive con una de Direccion de la misma persona: la rama que nos falta
-- no aporta ni un codigo de Linea nuevo, solo un CAM_LOC repetido para un
-- subconjunto. Los tres indicadores portados cubren los TRES codigos
-- distintos que el catalogo define.
--   Aqui no hay fan-out: los cuatro Valor_Fuente son distintos entre si.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_hom_ind_mov (
  valor_fuente VARCHAR(1000),  -- el nombre corto, llave del join
  descripcion  VARCHAR(30)     -- Descripcion_Hom_Ind_Mov_Linea (codigo Linea)
)
DISTSTYLE ALL;   -- 4 filas

TRUNCATE TABLE bdm_datos.catalogo_hom_ind_mov;

INSERT INTO bdm_datos.catalogo_hom_ind_mov (valor_fuente, descripcion)
  SELECT CAST('Cambio de Ciudad' AS VARCHAR(1000)), CAST('CAM_CIU' AS VARCHAR(30)) UNION ALL
  SELECT 'Cambio de Estrato',   'CAM_EST' UNION ALL
  SELECT 'Cambio de Direccion', 'CAM_LOC' UNION ALL
  SELECT 'Cambio de Localidad', 'CAM_LOC';
