-- Rollback 12: control Ordenamiento
-- En orden inverso al CREATE: el hash de la Fase 3 es el ultimo que entra.
DROP TABLE IF EXISTS bdm_datos.ubicacion_atributo_hash_mock;
DROP TABLE IF EXISTS bdm_datos.ubicacion_atributo_hash;
DROP TABLE IF EXISTS bdm_stage.mock_ord_alcance_censo;
DROP TABLE IF EXISTS bdm_datos.ord_alcance_censo;
DROP TABLE IF EXISTS bdm_stage.mock_ord_control_etapa;
DROP TABLE IF EXISTS bdm_stage.mock_ord_control;
DROP TABLE IF EXISTS bdm_datos.ord_control_etapa;
DROP TABLE IF EXISTS bdm_datos.ord_control;
