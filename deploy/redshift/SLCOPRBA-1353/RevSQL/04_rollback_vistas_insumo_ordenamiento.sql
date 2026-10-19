-- Rollback 04: vistas insumo ordenamiento
-- SLCOPRBA-1355: el contrato de la Fase 2, lo ultimo que entra.
DROP VIEW IF EXISTS bdm_tempo.v_xpm_comportamiento_cta;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_cuenta;
DROP VIEW IF EXISTS bdm_tempo.v_xpm_persona_dir_ganadora;
DROP VIEW IF EXISTS bdm_datos.insumo_email;
DROP VIEW IF EXISTS bdm_datos.insumo_celular;
DROP VIEW IF EXISTS bdm_datos.insumo_telefono;
DROP VIEW IF EXISTS bdm_datos.insumo_direccion;
DROP VIEW IF EXISTS bdm_tempo.v_relacion_persona_ubicacion_ord;
DROP VIEW IF EXISTS bdm_tempo.v_rpu_post_unificacion;
-- La tabla va DESPUES de las vistas, que es el orden inverso del SQL/04
-- (la crea en :8). Faltaba, y sobrevivia al rollback: parte del
-- [REDSHIFT:335] del job QA/DATABASE #122.
DROP TABLE IF EXISTS bdm_datos.rpu_orden_prioridad;
