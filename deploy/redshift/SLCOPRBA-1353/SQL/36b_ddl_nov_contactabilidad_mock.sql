-- ============================================================
-- 36b_ddl_nov_contactabilidad_mock.sql
-- ESPEJO MOCK de 36_ddl_nov_contactabilidad.sql. Generado por
-- sustitucion: el nombre de tabla recibe el sufijo _mock y NADA MAS
-- cambia. El diff contra el real debe salir vacio modulo ese sufijo.
-- Las justificaciones de contrato y divergencia (D-NOV-08) estan en el
-- archivo real y no se duplican aqui a proposito: una copia se
-- desincroniza.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- bdm_datos.mat_info_contactabilidad_mock  (legado MAT_INFO_CONTACTABILIDAD)
-- Las 12 del contrato mas las tres de trazabilidad.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_contactabilidad_mock (
  id                              BIGINT,         -- NULL: es COD_DW_CONTACTABILIDAD, la llave del evento de gestion
  contactabilidad                 VARCHAR(2),     -- NULL: necesita V_CONTACTO_EFECTIVO y el indicador de efectividad
  fecha_ultimo_contacto           TIMESTAMP,      -- SI se puebla, con OTRA semantica: ContactEventLastUpdated
  fecha_gestion                   TIMESTAMP,      -- NULL: no hay eventos de gestion
  mejor_dia_gestion               VARCHAR(10),    -- NULL: se deriva de fecha_gestion
  mejor_hora_gestion              VARCHAR(20),    -- NULL: pide hora del dia, que EDF no trae
  reportado_por                   INTEGER,        -- SI se puebla, con OTRA semantica: quien REPORTO, no quien gestiono
  sector                          VARCHAR(100),   -- NULL: falta V_PERSONA_CLASE_BURO y v_clase_buro
  ubicacion_id                    BIGINT,         -- SI se puebla: cod_dw_persona_ubic
  peso                            BIGINT,         -- NULL: es COUNT(*) de eventos de gestion
  mejor_resultado_3meses          VARCHAR(100),   -- NULL: codigo GESTION de la ventana de 3 meses
  mejor_resultado_6meses          VARCHAR(100),   -- NULL: idem, 6 meses
  lote                            INTEGER,
  fecha_actualizacion             TIMESTAMP DEFAULT GETDATE(),
  usuario_bd                      VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (ubicacion_id)
SORTKEY (ubicacion_id);
