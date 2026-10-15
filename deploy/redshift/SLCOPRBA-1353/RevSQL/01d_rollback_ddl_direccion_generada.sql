-- ============================================================
-- 01d_rollback_ddl_direccion_generada.sql
-- Rollback: elimina las tablas destino de las direcciones generadas por el
-- motor de Regla 2 (real y mock).
-- Contrapartida de 01d_ddl_direccion_generada.sql.
-- Codificacion: UTF-8 sin BOM.
-- ------------------------------------------------------------
-- Orden inverso a la creacion: primero las RPU sinteticas (que referencian a
-- las direcciones por FK logico) y luego las direcciones.
-- DROP TABLE IF EXISTS es valido en Redshift (directriz 5 del pipeline).
-- NOTA: no se elimina el schema bdm_datos porque es compartido; un
-- DROP SCHEMA ... CASCADE desde strct arrasa los SP de pgm (incidente DEV #256).
-- ADVERTENCIA: estas tablas contienen DATOS PRODUCIDOS por el motor, no
-- derivados de una corrida. En la via real no se reconstruyen con un FULL:
-- ejecutar este rollback pierde el historico de direcciones generadas.
-- ============================================================

DROP TABLE IF EXISTS bdm_datos.rpu_generada_mock;
DROP TABLE IF EXISTS bdm_datos.direccion_fisica_generada_mock;
DROP TABLE IF EXISTS bdm_datos.rpu_generada;
DROP TABLE IF EXISTS bdm_datos.direccion_fisica_generada;
