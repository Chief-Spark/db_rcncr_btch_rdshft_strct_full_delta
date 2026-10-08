-- Rollback 01: tabla de salida real + catalogos embebidos
-- Revierte 01_ddl_unificacion_direccion.sql
DROP TABLE IF EXISTS bdm_datos.nomenclatura;
DROP TABLE IF EXISTS bdm_datos.tipo_ubicacion_dir;
DROP TABLE IF EXISTS bdm_datos.diccionario_complementos;
DROP TABLE IF EXISTS bdm_datos.unificacion_direccion;
