-- Rollback 02a: DDL bdm_stage insumo mock
-- GUARDA DE ESQUEMA, Y SI, EN UN ROLLBACK. 'DROP TABLE IF EXISTS
-- bdm_stage.x' NO tolera que falte el ESQUEMA: el IF EXISTS cubre la tabla,
-- no el esquema, y en un ambiente limpio el RLLBCK_PRECHECK muere con
-- 3F000 schema "bdm_stage" does not exist -- job QA/DATABASE #122. Crearlo
-- vacio es inocuo: el DPLY lo crea igual, y el reverso del 00 lo borra al
-- final cuando ya no queda nada dentro.
CREATE SCHEMA IF NOT EXISTS bdm_stage;

DROP TABLE IF EXISTS bdm_stage.mock_comportamiento_cta;
DROP TABLE IF EXISTS bdm_stage.mock_cuenta;
DROP TABLE IF EXISTS bdm_stage.contacto_canal;
DROP TABLE IF EXISTS bdm_stage.diccionario_via;
DROP TABLE IF EXISTS bdm_stage.diccionario_complementos;
DROP TABLE IF EXISTS bdm_stage.nomenclatura;
DROP TABLE IF EXISTS bdm_stage.tipo_ubicacion_dir;
DROP TABLE IF EXISTS bdm_stage.ciiu_persona;
DROP TABLE IF EXISTS bdm_stage.reporte_relacion_persona_ubica;
DROP TABLE IF EXISTS bdm_stage.direccion_fisica;
DROP TABLE IF EXISTS bdm_stage.ubicacion_estandarizada;
DROP TABLE IF EXISTS bdm_stage.relacion_persona_ubicacion;
