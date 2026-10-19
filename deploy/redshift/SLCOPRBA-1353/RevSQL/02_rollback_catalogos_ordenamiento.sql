-- ============================================================
-- 02_rollback_catalogos_ordenamiento.sql
-- Reverso de SQL/02_catalogos_ordenamiento.sql.
--
-- ANTES ERA UN 'SELECT 1;' QUE DECIA "DDL permanente se revierte en 01", Y
-- ERA FALSO: 01_rollback_ddl_ordenamiento.sql no nombra ninguna de las tres.
-- Las tablas sobrevivian al rollback y en un ambiente limpio eso rompe la
-- comparacion DDL_1 vs DDL_3 del pipeline -- job QA/DATABASE #122,
-- [REDSHIFT:335]. En DEV no se veia porque ya existian de antes y aparecian
-- en las dos fotos por igual.
--
-- Las betas no van aqui: su tabla la borra 01_rollback_ddl_ordenamiento.sql,
-- y su carga es un INSERT que se rehace en cada despliegue.
-- UTF-8 sin BOM, sin acentos.
-- ============================================================

DROP TABLE IF EXISTS bdm_datos.catalogo_operador_ord_cel;
DROP TABLE IF EXISTS bdm_datos.catalogo_tipo_cuenta_tel;
DROP TABLE IF EXISTS bdm_datos.catalogo_sector_financiero;
