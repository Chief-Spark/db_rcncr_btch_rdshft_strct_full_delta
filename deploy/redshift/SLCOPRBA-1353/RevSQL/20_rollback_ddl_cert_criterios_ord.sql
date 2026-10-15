-- Rollback 1:1 de 20_ddl_cert_criterios_ord.sql
--
-- NOTA: no se elimina el schema bdm_datos porque es compartido (incidente
-- DEV #256). Se borra primero la vista, que depende de cert_resultado_ord, y
-- despues las dos tablas en orden inverso al de creacion -- aunque entre
-- ellas no haya FK declarada (Redshift no las obliga): asi el rollback sigue
-- siendo legible si algun dia la hubiera.
DROP VIEW  IF EXISTS bdm_datos.v_cert_ord_ultimo;
DROP TABLE IF EXISTS bdm_datos.cert_resultado_ord;
DROP TABLE IF EXISTS bdm_datos.cert_criterio_ord;
