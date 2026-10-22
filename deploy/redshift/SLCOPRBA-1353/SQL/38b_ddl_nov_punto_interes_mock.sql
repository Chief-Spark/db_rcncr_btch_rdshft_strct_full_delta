-- ============================================================
-- 38b_ddl_nov_punto_interes_mock.sql
-- ESPEJO MOCK de 38_ddl_nov_punto_interes.sql. Generado por
-- sustitucion: el nombre de tabla recibe el sufijo _mock y NADA MAS
-- cambia. El diff contra el real debe salir vacio modulo ese sufijo.
-- Las justificaciones de contrato, llave y divergencias estan en el
-- archivo real y no se duplican aqui: una copia se desincroniza.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- bdm_datos.mat_info_punto_interes_mock  (legado MAT_INFO_PUNTO_INTERES)
-- Las 10 del contrato mas las tres de trazabilidad.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_punto_interes_mock (
  id                               BIGINT,         -- derivada: FNV_HASH de la llave 1:N
  nombre                           VARCHAR(200),
  distancia                        INTEGER,        -- metros
  descripcion_tipo_punto_interes   VARCHAR(1000),  -- valor CRUDO: falta V_TIPO_PUNTO_INTERES
  ubicacion_id                     BIGINT,         -- cod_dw_ubic, NO la relacion persona-ubicacion
  nombre_entidad                   VARCHAR(1000),  -- NULL: falta RELACION_PUNTO_INTERES_X_PERS
  nit_entidad                      VARCHAR(20),    -- NULL: idem
  latitud                          VARCHAR(40),    -- del PUNTO DE INTERES. VARCHAR por el contrato
  longitud                         VARCHAR(40),    -- idem
  tipo                             VARCHAR(30),    -- codigo Linea (catalogo de homologacion)
  lote                             INTEGER,
  fecha_actualizacion              TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                       VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (ubicacion_id)
SORTKEY (ubicacion_id, id);
