-- ============================================================
-- 11e_ddl_unif_alcance_censo.sql
-- Censo de la VENTANA del DELTA de Unificacion (repo strct / db_rcncr_btch_rdshft_strct)
-- Cluster consumidor: reconocerbatch / dba_rncr_batch
-- DDL idempotente (CREATE TABLE IF NOT EXISTS). Objetos permanentes en bdm_datos.
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Spec: unificacion-full-delta
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ============================================================
-- bdm_datos.unif_alcance_censo -- PERMANENTE
--
-- QUE RESPONDE. En un DELTA, por que rama entro cada relacion al universo, y
-- cuantas de las que entraron son ruido de suelo que reentra en TODAS las
-- corridas.
--
-- POR QUE EXISTE. El universo del DELTA son DOS ramas
-- (sp_unificacion_r1_preparar_insumo.sql:32-34, y el r2 identico):
--
--     WHERE p_modo = 'FULL'
--        OR rpu.fecha_relacion_persona_ubicaci >= p_watermark   -- lo nuevo
--        OR rpu.fecha_relacion_persona_ubicaci IS NULL          -- entra SIEMPRE
--
-- y unif_control.relaciones_entrada las SUMA sin separarlas. Esa suma no
-- contesta la unica pregunta que importa de un DELTA -- "entro algo nuevo?" --
-- porque la rama nula entra se haya movido el origen o no. Es la misma leccion
-- que ya cazo NOV-UB-12: un DELTA en cero no prueba que no haya cambios, y un
-- DELTA distinto de cero tampoco prueba que los haya.
--
-- Medido en DEV el 2026-11-16, corrida DELTA del lote 20261117:
--   ventana_por_fecha       96        <- todas en la frontera
--   ventana_por_fecha_nula  1.102
--   ventana_personas        858
--   universo_relaciones     14.984    <- lo que unif_control reportaba a secas
--
-- LA COLUMNA QUE MAS VALOR DA ES ventana_en_la_frontera, y no existia en
-- ningun sitio. El predicado es '>=' INCLUSIVO, de modo que las relaciones
-- fechadas EXACTAMENTE en el watermark vuelven a entrar en todos los DELTA,
-- para siempre. En la corrida de arriba las 96 de la rama por fecha son las 96
-- de la frontera: cero novedad real. Sin esta columna, esos 96 se leen como
-- "entro algo nuevo" y no lo es.
--
-- NO SE TOCA unif_control, y es deliberado: Redshift no admite
-- ALTER TABLE ... ADD COLUMN IF NOT EXISTS (ver 01_ddl_unificacion_direccion.sql:19-22)
-- y el patron del repo para anadir una columna es DROP + CREATE. Sobre
-- unif_control eso seria grave: de ahi sale el watermark
-- (MAX(watermark_nuevo) WHERE estado = 'completado'), y perderlo fuerza un
-- Bootstrap FULL y borra la historia de corridas. Esta tabla es el mismo
-- patron que ord_alcance_censo (12_ddl_ord_control.sql:109), que nacio por el
-- mismo motivo.
--
-- LAS CUATRO ventana_* VAN EN NULL CUANDO LA CORRIDA ES FULL, no en 0. Misma
-- decision que las por_* de ord_alcance_censo: NULL dice "no hay senal que
-- medir" -- en FULL no hay ventana, entra todo -- y 0 diria "la busque y no
-- habia". Un censo que pusiera 0 en FULL mentiria igual que un DELTA en cero.
--
-- DISTSTYLE ALL: una fila por corrida, decenas de filas en total. Se une a
-- unif_control por corrida_id en toda consulta de diagnostico.
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.unif_alcance_censo (
  corrida_id              BIGINT       NOT NULL,
  lote                    INTEGER      NOT NULL,
  modo                    VARCHAR(10)  NOT NULL,   -- FULL | DELTA (modo efectivo)
  watermark_usado         DATE,                    -- frontera de partida
  watermark_origen        VARCHAR(20),             -- BOOTSTRAP | CONTROL
  ventana_por_fecha       BIGINT,                  -- relaciones con fecha >= watermark. NULL en FULL
  ventana_por_fecha_nula  BIGINT,                  -- relaciones con fecha IS NULL. NULL en FULL
  ventana_en_la_frontera  BIGINT,                  -- de por_fecha, cuantas con fecha = watermark. NULL en FULL
  ventana_personas        BIGINT,                  -- DISTINCT del driver stg_unif_delta_personas. NULL en FULL
  universo_relaciones     BIGINT,                  -- relaciones de esas personas (= unif_control.relaciones_entrada)
  universo_personas       BIGINT,                  -- DISTINCT de ese universo
  fecha_hora              TIMESTAMP    NOT NULL,
  usuario_bd              VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (corrida_id);
