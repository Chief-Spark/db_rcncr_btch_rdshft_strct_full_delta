-- ============================================================
-- 11f_ddl_unif_alcance_censo_mock.sql
-- Espejo mock del censo de ventana (repo strct / db_rcncr_btch_rdshft_strct)
-- Cluster consumidor: reconocerbatch / dba_rncr_batch
-- DDL idempotente (CREATE TABLE IF NOT EXISTS). Objetos permanentes en bdm_datos.
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Spec: unificacion-full-delta
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ============================================================
-- bdm_datos.unif_alcance_censo_mock -- ESPEJO MOCK
--
-- Mismas columnas que bdm_datos.unif_alcance_censo, misma semantica. El motivo
-- de la tabla, el detalle de las dos ramas y por que las ventana_* van en NULL
-- cuando la corrida es FULL estan en 11e_ddl_unif_alcance_censo.sql; aqui no
-- se repiten para que haya UNA sola fuente de verdad que mantener.
--
-- EL SUFIJO ES _mock Y EL ESQUEMA ES bdm_datos, no al reves. Los control de
-- Unificacion y Novedades van asi (unif_control_mock, nov_control_mock); los
-- del Ordenamiento van al contrario y en otro esquema
-- (bdm_stage.mock_ord_alcance_censo). Confundirlos ya costo una consulta vacia.
--
-- ESTA TABLA ENTRA EN reset_mock.sql EN EL MISMO COMMIT QUE ESTE DDL, y en la
-- copia en linea de run_reconocer_e2e_mock_full_delta.sql. El pipeline corre
-- el DPLY dos veces y lo que una pasada escribe sobrevive a la otra: una tabla
-- de control nueva que el reset no borra es exactamente lo que tumbo el job
-- DEV/DATABASE #412.
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.unif_alcance_censo_mock (
  corrida_id              BIGINT       NOT NULL,
  lote                    INTEGER      NOT NULL,
  modo                    VARCHAR(10)  NOT NULL,   -- FULL | DELTA (modo efectivo)
  watermark_usado         DATE,                    -- frontera de partida
  watermark_origen        VARCHAR(20),             -- BOOTSTRAP | CONTROL
  ventana_por_fecha       BIGINT,                  -- relaciones con fecha >= watermark. NULL en FULL
  ventana_por_fecha_nula  BIGINT,                  -- relaciones con fecha IS NULL. NULL en FULL
  ventana_en_la_frontera  BIGINT,                  -- de por_fecha, cuantas con fecha = watermark. NULL en FULL
  ventana_personas        BIGINT,                  -- DISTINCT del driver. NULL en FULL
  universo_relaciones     BIGINT,                  -- relaciones de esas personas
  universo_personas       BIGINT,                  -- DISTINCT de ese universo
  fecha_hora              TIMESTAMP    NOT NULL,
  usuario_bd              VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id);
