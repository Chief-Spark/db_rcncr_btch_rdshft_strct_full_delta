-- Rollback 05: DDL mock ordenamiento
-- GUARDA DE ESQUEMA, Y SI, EN UN ROLLBACK: DROP TABLE IF EXISTS
-- bdm_stage.x NO tolera que falte el ESQUEMA -- el IF EXISTS cubre la tabla,
-- no el esquema -- y en un ambiente primerizo el RLLBCK_PRECHECK muere con
-- 3F000 schema bdm_stage does not exist (job QA/DATABASE #122).
-- ESTE ARCHIVO CORRE ANTES DE 02a EN rollback.par, de modo que no puede
-- apoyarse en la guarda de aquel: Jenkins los ejecuta uno a uno y cada uno
-- tiene que sobrevivir solo. Crearlo vacio es inocuo -- el DPLY lo crea
-- igual -- y nadie lo borra nunca (DEV #422: bdm_stage es compartido).
CREATE SCHEMA IF NOT EXISTS bdm_stage;

DROP TABLE IF EXISTS bdm_stage.mock_ord_ca_result;
DROP TABLE IF EXISTS bdm_stage.mock_ord_prioridad;
DROP TABLE IF EXISTS bdm_stage.mock_ord_score;
DROP TABLE IF EXISTS bdm_stage.mock_ord_rpu;
DROP TABLE IF EXISTS bdm_stage.mock_ord_escenario;
