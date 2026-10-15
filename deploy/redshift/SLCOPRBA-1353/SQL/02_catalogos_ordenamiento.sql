-- Catálogos ordenamiento — interim DEV hasta IFR/datashare oficial
-- Reemplazar carga sector_financiero cuando IFR entregue catálogo

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

-- Catálogo operador celular (interim DEV — reemplazar por ifr_data.v_operador_ord_cel)
CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_operador_ord_cel (
  cod_operador VARCHAR(3) ENCODE ZSTD,
  operador     VARCHAR(50) ENCODE ZSTD,
  valor        DECIMAL(10,4) ENCODE AZ64
)
DISTSTYLE ALL;

TRUNCATE TABLE bdm_datos.catalogo_operador_ord_cel;

INSERT INTO bdm_datos.catalogo_operador_ord_cel (cod_operador, operador, valor) VALUES
  ('300', 'COMCEL', 0.55), ('301', 'COMCEL', 0.55), ('302', 'MOVISTAR', 0.58),
  ('310', 'CLARO', 0.62), ('311', 'CLARO', 0.62), ('312', 'CLARO', 0.62),
  ('313', 'CLARO', 0.62), ('314', 'CLARO', 0.62), ('315', 'CLARO', 0.62),
  ('316', 'CLARO', 0.62), ('317', 'CLARO', 0.62), ('318', 'CLARO', 0.62),
  ('319', 'CLARO', 0.62), ('320', 'CLARO', 0.62), ('321', 'CLARO', 0.62),
  ('350', 'MOVISTAR', 0.58);

SELECT 'catalogo_sector_financiero' AS cat, COUNT(*) AS n FROM bdm_datos.catalogo_sector_financiero
UNION ALL SELECT 'catalogo_tipo_cuenta_tel', COUNT(*) FROM bdm_datos.catalogo_tipo_cuenta_tel
UNION ALL SELECT 'catalogo_operador_ord_cel', COUNT(*) FROM bdm_datos.catalogo_operador_ord_cel;
