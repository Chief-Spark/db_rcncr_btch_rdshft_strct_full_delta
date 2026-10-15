-- ============================================================
-- 06_vistas_mock_post_unificacion.sql
-- Vista RPU post-unificacion para la via MOCK.
-- Objeto en bdm_tempo. Codificacion: UTF-8 sin BOM.
-- Nunca GRANT ... TO PUBLIC.
-- Spec: unificacion-full-delta -- certificacion con datos mock
-- ------------------------------------------------------------
-- SLCOPRBA-1354: espejo mock de bdm_tempo.v_rpu_post_unificacion
-- (04_vistas_insumo_ordenamiento_edf_views.sql).
--
-- PARA QUE SIRVE:
--   Es el puente Unificacion -> Ordenamiento en la via mock. Hoy
--   sp_ordenamiento_ejecucion_mock carga sus propias semillas desde
--   bdm_stage.mock_ord_* y NO consume unificacion_direccion_mock, por lo que
--   la cadena mock esta partida en dos y el Ordenamiento no ve el resultado de
--   la Unificacion. Esta vista cierra ese puente (el SP se re-apunta aqui en la
--   fase 3).
--
-- ind_unificacion: 1 si la RPU aparece como HIJA en unificacion_direccion_mock
--   (misma semantica que el flag Ind_Unificacion del legado Teradata, que
--   marca las direcciones que ya pasaron por el proceso).
--
-- orden_prioridad: se toma de bdm_stage.mock_ord_prioridad, contrapartida mock
--   de bdm_datos.rpu_orden_prioridad. Es SALIDA del Ordenamiento, por lo que
--   queda NULL hasta que el Ordenamiento mock corra.
--
-- WITH NO SCHEMA BINDING (late binding): obligatorio para que un DROP/CREATE
-- de las tablas base no invalide la vista ni aborte el despliegue.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_tempo;

DROP VIEW IF EXISTS bdm_tempo.v_mock_rpu_post_unificacion;
CREATE OR REPLACE VIEW bdm_tempo.v_mock_rpu_post_unificacion AS
SELECT
  rpu.cod_dw_persona_ubic,
  rpu.cod_pin_persona,
  rpu.id_buro_persona,
  rpu.cod_dw_ubic,
  op.orden_prioridad,
  rpu.fecha_relacion_persona_ubicaci,
  CASE WHEN u.cod_dw_persona_ubic IS NOT NULL THEN 1 ELSE 0 END AS ind_unificacion
FROM bdm_tempo.v_mock_relacion_persona_ubicacion rpu
LEFT JOIN bdm_datos.unificacion_direccion_mock u
  ON u.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
LEFT JOIN (
  SELECT cod_dw_persona_ubic, MIN(orden_prioridad) AS orden_prioridad
  FROM bdm_stage.mock_ord_prioridad
  GROUP BY 1
) op
  ON op.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic
WITH NO SCHEMA BINDING;
