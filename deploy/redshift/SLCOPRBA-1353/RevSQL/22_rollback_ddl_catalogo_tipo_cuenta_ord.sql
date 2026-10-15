-- Rollback 1:1 de 22_ddl_catalogo_tipo_cuenta_ord.sql
-- Las tablas SI admiten IF EXISTS en Redshift (los procedimientos no).
DROP TABLE IF EXISTS bdm_datos.catalogo_tipo_cuenta_ord;
