-- ============================================================
-- 13_rollback_ddl_cert_criterios.sql
-- Rollback: elimina el tablero de certificacion de los 51 criterios
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- Contrapartida de 13_ddl_cert_criterios.sql.
-- Codificacion: UTF-8 sin BOM.
-- ------------------------------------------------------------
-- NOTA: no se elimina el schema bdm_datos porque es compartido.
-- Se borra primero el resultado y despues el catalogo, en el orden inverso
-- al de creacion, aunque entre ambos no hay FK declarada (Redshift no las
-- obliga): asi el rollback sigue siendo legible si algun dia la hubiera.
-- ============================================================

-- La vista primero: depende de cert_resultado.
DROP VIEW IF EXISTS bdm_datos.v_cert_ultimo;

DROP TABLE IF EXISTS bdm_datos.cert_resultado;
DROP TABLE IF EXISTS bdm_datos.cert_criterio;
