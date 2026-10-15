-- Rollback 04: vistas insumo ordenamiento
DROP VIEW IF EXISTS bdm_tempo.v_xpm_persona_dir_ganadora;
DROP VIEW IF EXISTS bdm_datos.insumo_email;
DROP VIEW IF EXISTS bdm_datos.insumo_celular;
DROP VIEW IF EXISTS bdm_datos.insumo_telefono;
DROP VIEW IF EXISTS bdm_datos.insumo_direccion;
DROP VIEW IF EXISTS bdm_tempo.v_relacion_persona_ubicacion_ord;
DROP VIEW IF EXISTS bdm_tempo.v_rpu_post_unificacion;
