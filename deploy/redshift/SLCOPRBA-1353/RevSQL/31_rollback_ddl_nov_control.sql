-- Rollback 1:1 de 31_ddl_nov_control.sql
--
-- NOTA: no se elimina el schema bdm_datos porque es compartido (incidente
-- DEV #256). Se borra primero la tabla de etapa, que referencia por FK
-- logico a nov_control.corrida_id, y despues la cabecera.
DROP TABLE IF EXISTS bdm_datos.nov_control_etapa;
DROP TABLE IF EXISTS bdm_datos.nov_control;
