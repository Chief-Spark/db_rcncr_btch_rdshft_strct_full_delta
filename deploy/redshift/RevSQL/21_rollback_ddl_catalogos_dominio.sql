-- Rollback 1:1 de 21_ddl_catalogos_dominio.sql
-- Tablas y vistas SI admiten IF EXISTS en Redshift (los procedimientos no).
DROP TABLE IF EXISTS bdm_datos.catalogo_fuente_dato;
DROP TABLE IF EXISTS bdm_datos.catalogo_razon_bloqueo;
DROP TABLE IF EXISTS bdm_datos.catalogo_gestion_registro;
DROP TABLE IF EXISTS bdm_datos.catalogo_fuente;
