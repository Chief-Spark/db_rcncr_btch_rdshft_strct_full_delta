-- Rollback 1:1 de 30_ddl_novedades.sql
--
-- NOTA: no se eliminan los schemas bdm_datos ni bdm_tempo porque son
-- compartidos (incidente DEV #256). Las tres tablas se borran en orden
-- inverso al de creacion -- aunque entre ellas no haya FK declarada
-- (Redshift no las obliga): asi el rollback sigue siendo legible si algun
-- dia la hubiera.
DROP TABLE IF EXISTS bdm_datos.mat_info_ubicacion;
DROP TABLE IF EXISTS bdm_tempo.stg_nov_ubica_etapa_2;
DROP TABLE IF EXISTS bdm_tempo.stg_nov_ubica_etapa_9;
