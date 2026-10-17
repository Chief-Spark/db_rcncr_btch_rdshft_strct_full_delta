-- Rollback 1:1 de 33_ddl_cert_criterios_nov.sql
--
-- NOTA: no se elimina el schema bdm_datos porque es compartido (incidente
-- DEV #256). Se borra primero la vista, que depende de cert_resultado_nov, y
-- despues las dos tablas en orden inverso al de creacion.
DROP VIEW  IF EXISTS bdm_datos.v_cert_nov_ultimo;
DROP TABLE IF EXISTS bdm_datos.cert_resultado_nov;
DROP TABLE IF EXISTS bdm_datos.cert_criterio_nov;
