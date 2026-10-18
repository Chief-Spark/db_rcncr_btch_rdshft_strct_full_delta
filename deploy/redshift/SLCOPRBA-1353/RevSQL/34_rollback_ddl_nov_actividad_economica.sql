-- ============================================================
-- 34_rollback_ddl_nov_actividad_economica.sql
-- Reverso exacto de 34_ddl_nov_actividad_economica.sql.
-- UTF-8 sin BOM, sin acentos.
--
-- Orden inverso al del deploy. Tablas y vistas SI admiten IF EXISTS en
-- Redshift; es el DROP PROCEDURE el que no (lecciones #10 y #12).
--
-- NO se tocan los esquemas: bdm_datos y bdm_tempo son compartidos y un
-- DROP SCHEMA ... CASCADE desde strct es el incidente DEV #256.
-- ============================================================
DROP TABLE IF EXISTS bdm_datos.mat_info_actividad_economica;
DROP TABLE IF EXISTS bdm_tempo.stg_nov_acteco_etapa_1;
