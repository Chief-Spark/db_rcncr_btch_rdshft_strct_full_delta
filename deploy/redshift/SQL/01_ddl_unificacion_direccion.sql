-- ============================================================
-- 01_ddl_unificacion_direccion.sql  (DEV datasharing / Reconocer)
-- Igual que qa_ifr_data pero catalogos embebidos (sin bdm_stage)
-- Ref: Documentacion/configuracion_ifr_data_qa.md
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- ------------------------------------------------------------
-- SLCOPRBA-1354: se anaden lote_actualizacion y fecha_modificacion a
-- bdm_datos.unificacion_direccion para alinear la persistencia con el legado
-- Teradata (P0020_UNIFICACION_DIRECCION_130.TPT, seccion "Apply Upsert"):
--   * lote               -> lote que CREO la fila (inmutable).
--   * lote_actualizacion -> ultimo lote que la re-toco (UPSERT en Modo_Delta).
--   * fecha_modificacion -> fecha de ese ultimo toque.
-- El legado resuelve la persistencia con 'INSERT FOR MISSING UPDATE ROWS' sobre
-- la Clave_Unificacion (cod_dw_persona_ubic, cod_dw_direccion_unificada) y en el
-- UPDATE NO reescribe Lote: solo Lote_Actualizacion / Usuario_BD /
-- Fecha_Modificacion. Sin estas dos columnas, el UPSERT del Modo_Delta pisa
-- 'lote' y se pierde la trazabilidad de que corrida origino cada unificacion.
-- ------------------------------------------------------------
-- NOTA Redshift -- por que DROP + CREATE y no ALTER TABLE ADD COLUMN:
--   * CREATE TABLE IF NOT EXISTS es no-op sobre una tabla ya existente: NO
--     anade las columnas nuevas en ambientes ya desplegados.
--   * Redshift no admite ALTER TABLE ... ADD COLUMN IF NOT EXISTS, y un ALTER
--     plano aborta con "column already exists" al re-desplegar, rompiendo la
--     idempotencia que exige la directriz 11 del pipeline.
--   * DROP TABLE IF EXISTS SI es valido en Redshift (directriz 5).
--
-- CONSECUENCIA OPERATIVA (leer antes de desplegar):
--   El despliegue de este script deja bdm_datos.unificacion_direccion VACIA.
--   Es admisible porque la tabla es DERIVADA y se reconstruye por completo en
--   la siguiente corrida FULL (que de hecho ya la trunca). Tras desplegar strct
--   hay que ejecutar un FULL antes de consultarla o de correr Ordenamiento.
--   Las vistas que la referencian (04_vistas_insumo_ordenamiento_edf_views.sql)
--   son late-binding (WITH NO SCHEMA BINDING): el DROP no las invalida.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

DROP TABLE IF EXISTS bdm_datos.unificacion_direccion;
CREATE TABLE IF NOT EXISTS bdm_datos.unificacion_direccion (
  cod_dw_persona_ubic BIGINT,
  cod_dw_direccion_unificada BIGINT,
  unifica_atributos INTEGER,
  fecha_unificacion DATE,
  lote INTEGER,                 -- lote que CREO la fila (inmutable, legado: Lote)
  lote_actualizacion INTEGER,   -- ultimo lote que la re-toco (legado: Lote_Actualizacion)
  fecha_modificacion DATE,      -- fecha del ultimo toque (legado: Fecha_Modificacion)
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
