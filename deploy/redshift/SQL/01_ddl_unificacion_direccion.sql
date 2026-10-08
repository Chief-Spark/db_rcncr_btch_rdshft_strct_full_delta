-- ============================================================
-- 01_ddl_unificacion_direccion.sql  (DEV datasharing / Reconocer)
-- Igual que qa_ifr_data pero catálogos embebidos (sin bdm_stage)
-- Ref: Documentacion/configuracion_ifr_data_qa.md
-- ============================================================

CREATE TABLE IF NOT EXISTS bdm_datos.unificacion_direccion (
  cod_dw_persona_ubic BIGINT,
  cod_dw_direccion_unificada BIGINT,
  unifica_atributos INTEGER,
  fecha_unificacion DATE,
  lote INTEGER,
  severidad INTEGER,
  usuario_bd VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (cod_dw_persona_ubic)
SORTKEY (cod_dw_persona_ubic);

CREATE TABLE IF NOT EXISTS bdm_datos.diccionario_complementos (
  cod_dw_ubic BIGINT,
  id_buro_persona INTEGER,
  nomenclatura VARCHAR(50),
  nomen VARCHAR(10),
  valor VARCHAR(50),
  frecuencia INTEGER
)
DISTSTYLE KEY
DISTKEY (cod_dw_ubic)
SORTKEY (cod_dw_ubic, id_buro_persona);

CREATE TABLE IF NOT EXISTS bdm_datos.tipo_ubicacion_dir (
  cod_dw_tipo_ubicacion_dir INTEGER,
  descripcion_tipo_ubicacion_dir VARCHAR(20)
)
DISTSTYLE ALL;

INSERT INTO bdm_datos.tipo_ubicacion_dir (cod_dw_tipo_ubicacion_dir, descripcion_tipo_ubicacion_dir)
SELECT v.cod, v.des
FROM (
  SELECT 1 AS cod, 'RES' AS des UNION ALL
  SELECT 2, 'LAB' UNION ALL
  SELECT 3, 'CRR' UNION ALL
  SELECT 4, 'JUD' UNION ALL
  SELECT 5, 'CCL' UNION ALL
  SELECT 7, 'DIR'
) v
WHERE NOT EXISTS (SELECT 1 FROM bdm_datos.tipo_ubicacion_dir LIMIT 1);

CREATE TABLE IF NOT EXISTS bdm_datos.nomenclatura (
  nomenclatura VARCHAR(10),
  nivel_complemento INTEGER
)
DISTSTYLE ALL;

INSERT INTO bdm_datos.nomenclatura (nomenclatura, nivel_complemento)
SELECT v.nomenclatura, v.nivel_complemento
FROM (
  SELECT 'TO' AS nomenclatura, 4 AS nivel_complemento UNION ALL
  SELECT 'AP', 7 UNION ALL SELECT 'CS', 5 UNION ALL SELECT 'LC', 3 UNION ALL
  SELECT 'OF', 6 UNION ALL SELECT 'BL', 2 UNION ALL SELECT 'IN', 8 UNION ALL
  SELECT 'ED', 2 UNION ALL SELECT 'BR', 1 UNION ALL SELECT 'MZ', 3 UNION ALL
  SELECT 'CA', 4 UNION ALL SELECT 'LT', 5
) v
WHERE NOT EXISTS (SELECT 1 FROM bdm_datos.nomenclatura LIMIT 1);
