-- Catalogos ordenamiento - interim DEV hasta IFR/datashare oficial
-- Reemplazar carga sector_financiero cuando IFR entregue catalogo

CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_sector_financiero (
  id_buro_suscriptor INTEGER ENCODE AZ64,
  sector_financiero  INTEGER ENCODE AZ64
)
DISTSTYLE ALL;

TRUNCATE TABLE bdm_datos.catalogo_sector_financiero;

INSERT INTO bdm_datos.catalogo_sector_financiero (id_buro_suscriptor, sector_financiero)
SELECT DISTINCT
  rep.id_buro_suscriptor,
  CASE WHEN rep.id_buro_suscriptor >= 901 THEN 1 ELSE 0 END
FROM bdm_tempo.v_xpm_reporte_relacion_persona_ubica rep
WHERE rep.id_buro_suscriptor IS NOT NULL;

CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_tipo_cuenta_tel (
  prefijo_operador VARCHAR(3) ENCODE ZSTD,
  tipo_cuenta        VARCHAR(20) ENCODE ZSTD
)
DISTSTYLE ALL;

TRUNCATE TABLE bdm_datos.catalogo_tipo_cuenta_tel;

INSERT INTO bdm_datos.catalogo_tipo_cuenta_tel VALUES
  ('310', 'PREPAGO'), ('311', 'PREPAGO'), ('312', 'PREPAGO'), ('313', 'PREPAGO'),
  ('314', 'PREPAGO'), ('315', 'PREPAGO'), ('316', 'PREPAGO'), ('317', 'PREPAGO'),
  ('318', 'PREPAGO'), ('319', 'PREPAGO'), ('320', 'PREPAGO'), ('321', 'PREPAGO'),
  ('300', 'PREPAGO'), ('301', 'PREPAGO'), ('302', 'PREPAGO'), ('350', 'PREPAGO'),
  ('601', 'FIJA'), ('602', 'FIJA'), ('604', 'FIJA');

-- Catalogo operador celular: REC_VISTA.V_Operador_Ord_Cel REAL (2026-10-20,
-- D-ORD-11). Antes eran 16 valores inventados. Fuente:
-- dt/docs/legado_teradata/reconocer/catalogos/REC_VISTA - V_Operador_Ord_Cel.csv
-- (20 filas, todas Cod_DW_Pais = 1). El legado no trae nombre de operador, de
-- modo que operador va NULL; nadie lo lee. El Valor llega con 10 decimales y
-- aqui se redondea a 4: CEL018 lo multiplica por 100 y lo castea a
-- DECIMAL(18,2) (sp_ordenamiento_scoring_cel_edf.sql:90), asi que la
-- categoria no cambia. Los umbrales de CEL018 (51.11, 61.48, 73.33) son
-- justamente los valores de 312, 321 y 316.
-- El catalogo lo comparte el mock (el scoring CEL es uno solo): mueve los
-- scores de CEL del mock y el ARQ 83, sembrado sobre los valores inventados.
CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_operador_ord_cel (
  cod_operador VARCHAR(3) ENCODE ZSTD,
  operador     VARCHAR(50) ENCODE ZSTD,
  valor        DECIMAL(10,4) ENCODE AZ64
)
DISTSTYLE ALL;

TRUNCATE TABLE bdm_datos.catalogo_operador_ord_cel;

INSERT INTO bdm_datos.catalogo_operador_ord_cel (cod_operador, operador, valor) VALUES
  ('300', NULL, 0.9037), ('301', NULL, 0.8148), ('302', NULL, 0.1037), ('304', NULL, 0.2815),
  ('305', NULL, 0.1111), ('310', NULL, 1.0000), ('311', NULL, 0.6370), ('312', NULL, 0.5111),
  ('313', NULL, 0.6370), ('314', NULL, 0.5185), ('315', NULL, 0.4148), ('316', NULL, 0.7333),
  ('317', NULL, 0.4667), ('318', NULL, 0.4296), ('319', NULL, 0.1556), ('320', NULL, 0.5407),
  ('321', NULL, 0.6148), ('322', NULL, 0.1481), ('323', NULL, 0.0667), ('350', NULL, 0.0519);

SELECT 'catalogo_sector_financiero' AS cat, COUNT(*) AS n FROM bdm_datos.catalogo_sector_financiero
UNION ALL SELECT 'catalogo_tipo_cuenta_tel', COUNT(*) FROM bdm_datos.catalogo_tipo_cuenta_tel
UNION ALL SELECT 'catalogo_operador_ord_cel', COUNT(*) FROM bdm_datos.catalogo_operador_ord_cel;
