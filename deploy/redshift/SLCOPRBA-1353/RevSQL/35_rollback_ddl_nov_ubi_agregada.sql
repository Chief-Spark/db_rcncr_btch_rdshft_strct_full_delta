-- ============================================================
-- 35_rollback_ddl_nov_ubi_agregada.sql
-- Reverso exacto de 35_ddl_nov_ubi_agregada.sql.
-- UTF-8 sin BOM, sin acentos.
--
-- Una sola tabla: las 22 etapas del dominio no son contrato publico, viven
-- dentro del SP y el propio SP las borra al terminar. No hay DDL que
-- revertir para ellas.
--
-- NO se tocan los esquemas: bdm_datos es compartido y un
-- DROP SCHEMA ... CASCADE desde strct es el incidente DEV #256.
-- ============================================================
DROP TABLE IF EXISTS bdm_datos.mat_ubicacion_agregada;
DROP TABLE IF EXISTS bdm_tempo.stg_nov_ubiagr_etapa_final;
