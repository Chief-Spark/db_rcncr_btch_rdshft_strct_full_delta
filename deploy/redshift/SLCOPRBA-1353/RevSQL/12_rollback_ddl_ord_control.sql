-- Rollback 12: control Ordenamiento
-- El censo de alcance va primero: se creo el ultimo.
DROP TABLE IF EXISTS bdm_stage.mock_ord_alcance_censo;
DROP TABLE IF EXISTS bdm_datos.ord_alcance_censo;
DROP TABLE IF EXISTS bdm_stage.mock_ord_control_etapa;
DROP TABLE IF EXISTS bdm_stage.mock_ord_control;
DROP TABLE IF EXISTS bdm_datos.ord_control_etapa;
DROP TABLE IF EXISTS bdm_datos.ord_control;
