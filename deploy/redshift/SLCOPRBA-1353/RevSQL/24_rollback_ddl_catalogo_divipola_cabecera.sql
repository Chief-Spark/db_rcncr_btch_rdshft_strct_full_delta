-- Rollback 1:1 de 24_ddl_catalogo_divipola_cabecera.sql
-- Las tablas SI admiten IF EXISTS en Redshift (los procedimientos no).
DROP TABLE IF EXISTS bdm_datos.catalogo_divipola_cabecera;
