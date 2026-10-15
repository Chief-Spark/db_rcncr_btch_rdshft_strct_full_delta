-- Rollback 1:1 de 23_ddl_catalogo_portafolio_ord.sql
-- Las tablas SI admiten IF EXISTS en Redshift (los procedimientos no).
DROP TABLE IF EXISTS bdm_datos.catalogo_portafolio_ve;
DROP TABLE IF EXISTS bdm_datos.catalogo_portafolio_prefijo;
