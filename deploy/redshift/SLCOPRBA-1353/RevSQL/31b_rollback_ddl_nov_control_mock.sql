-- Rollback 1:1 de 31b_ddl_nov_control_mock.sql
--
-- Espejo de 31_rollback_ddl_nov_control.sql: mismos dos objetos con sufijo
-- _mock, mismo orden inverso. No se elimina el schema: es compartido
-- (incidente DEV #256).
DROP TABLE IF EXISTS bdm_datos.nov_control_etapa_mock;
DROP TABLE IF EXISTS bdm_datos.nov_control_mock;
