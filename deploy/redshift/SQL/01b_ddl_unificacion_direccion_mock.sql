-- ============================================================
-- 01b_ddl_unificacion_direccion_mock.sql
-- Tabla de salida para SPs sp_unificacion_mock_* (Data Sharing)
-- ============================================================

CREATE TABLE IF NOT EXISTS bdm_datos.unificacion_direccion_mock (
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
