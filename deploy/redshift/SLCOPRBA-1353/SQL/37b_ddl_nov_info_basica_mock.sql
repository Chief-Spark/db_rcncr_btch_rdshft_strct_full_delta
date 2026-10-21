-- ============================================================
-- 37b_ddl_nov_info_basica_mock.sql
-- ESPEJO MOCK de 37_ddl_nov_info_basica.sql. Generado por sustitucion:
-- el nombre de tabla recibe el sufijo _mock y NADA MAS cambia.
-- El diff contra el real debe salir vacio modulo ese sufijo.
-- Las justificaciones de contrato, tipos y divergencias estan en el
-- archivo real y no se duplican aqui: una copia se desincroniza.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- bdm_datos.mat_info_basica_mock  (legado MAT_INFO_BASICA)
-- Las 22 del contrato mas las tres de trazabilidad.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_basica_mock (
  id                              BIGINT,         -- id_buro_persona. BIGINT y no INTEGER: D-NOV-04
  primer_nombre                   VARCHAR(100),
  segundo_nombre                  VARCHAR(100),
  primer_apellido                 VARCHAR(100),
  segundo_apellido                VARCHAR(100),
  nombre_completo                 VARCHAR(200),
  cod_tipo_ident_fte              VARCHAR(20),
  tipo_identificacion             VARCHAR(30),    -- NULL: falta V_Hom_Tip_Ident_Linea (C37)
  numero_identificacion           BIGINT,
  estado_documento                VARCHAR(20),    -- businessidstatus con LPAD a 2 (D-EDF-13)
  rango_edad                      VARCHAR(25),
  lugar_expedicion                VARCHAR(100),
  fecha_expedicion                DATE,
  genero                          VARCHAR(508),   -- M | F | O | vacio (D-EDF-14). Ancho del contrato
  ciiu                            VARCHAR(20),
  actividad_economica             VARCHAR(500),
  razon_social                    VARCHAR(500),   -- derivada: fullname cuando el tipo es NIT
  pagina_web                      VARCHAR(100),   -- NULL: NO EXISTE EN EDF (CCBR 251264543)
  mosaic_id                       INTEGER,        -- NULL: Mosaic fuera por decision legal (D-NOV-07)
  departamento_expedicion         VARCHAR(100),
  cod_pin_persona                 BIGINT,         -- BIGINT y no INTEGER: D-NOV-04
  rut                             VARCHAR(1),
  lote                            INTEGER,
  fecha_actualizacion             TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                      VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (id)
SORTKEY (id);
