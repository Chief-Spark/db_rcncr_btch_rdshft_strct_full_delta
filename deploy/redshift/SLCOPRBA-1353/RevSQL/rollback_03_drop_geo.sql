-- Rollback 03: objetos GEO (Enriquecimiento Regla 3)
-- Revierte 03_ddl_geo.sql en orden inverso a la creacion.
-- Nota: NO se hace DROP FUNCTION geo_get_config: Redshift no soporta
-- DROP FUNCTION IF EXISTS y en primer deploy (objeto ausente) aborta con
-- REDSHIFT:112. La funcion se recrea con CREATE OR REPLACE en 03_ddl_geo.sql.
DROP TABLE IF EXISTS bdm_datos.geo_distancias;
DROP TABLE IF EXISTS bdm_datos.geo_atributos;
DROP TABLE IF EXISTS bdm_datos.geo_lote_control;
DROP TABLE IF EXISTS bdm_datos.geo_config;
