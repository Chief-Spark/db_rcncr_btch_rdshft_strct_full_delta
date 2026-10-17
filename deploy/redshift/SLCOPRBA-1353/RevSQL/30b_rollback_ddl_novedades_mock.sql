-- Rollback 1:1 de 30b_ddl_novedades_mock.sql
--
-- Espejo de 30_rollback_ddl_novedades.sql: mismos tres objetos con sufijo
-- _mock, mismo orden inverso. No se eliminan los schemas: son compartidos
-- (incidente DEV #256).
DROP TABLE IF EXISTS bdm_datos.mat_info_ubicacion_mock;
DROP TABLE IF EXISTS bdm_tempo.stg_nov_ubica_etapa_2_mock;
DROP TABLE IF EXISTS bdm_tempo.stg_nov_ubica_etapa_9_mock;
