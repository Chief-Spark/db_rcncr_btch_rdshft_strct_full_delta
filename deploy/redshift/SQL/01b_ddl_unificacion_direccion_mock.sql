-- ============================================================
-- 01b_ddl_unificacion_direccion_mock.sql
-- Tabla de salida para SPs sp_unificacion_mock_* (Data Sharing)
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- ------------------------------------------------------------
-- SLCOPRBA-1354: espejo exacto de bdm_datos.unificacion_direccion. Se anaden
-- lote_actualizacion y fecha_modificacion para que la via MOCK ejercite la
-- MISMA logica de persistencia que la real (UPSERT fiel al legado Teradata:
-- UPDATE del lote_actualizacion sobre la Clave_Unificacion + INSERT de las
-- faltantes, preservando 'lote'). Si el mock no tuviera estas columnas, no
-- podria certificar el comportamiento que se despliega en datos reales.
--
-- Misma nota Redshift que en 01: se usa DROP + CREATE porque
-- CREATE TABLE IF NOT EXISTS no anade columnas a una tabla ya existente y
-- Redshift no admite ALTER TABLE ... ADD COLUMN IF NOT EXISTS (la idempotencia
-- de la directriz 11 se conserva con DROP TABLE IF EXISTS, directriz 5).
-- La tabla es derivada: la reconstruye la siguiente corrida FULL mock.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

DROP TABLE IF EXISTS bdm_datos.unificacion_direccion_mock;
CREATE TABLE IF NOT EXISTS bdm_datos.unificacion_direccion_mock (
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
