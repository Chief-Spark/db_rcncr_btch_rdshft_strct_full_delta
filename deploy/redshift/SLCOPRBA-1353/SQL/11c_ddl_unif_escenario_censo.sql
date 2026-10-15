-- ============================================================
-- 11c_ddl_unif_escenario_censo.sql
-- Censo de escenarios de la Regla 2 (repo strct / db_rcncr_btch_rdshft_strct)
-- Cluster consumidor: reconocerbatch / dba_rncr_batch
-- DDL idempotente (CREATE TABLE IF NOT EXISTS). Objetos permanentes en bdm_datos.
-- Codificacion: UTF-8 sin BOM. Nunca GRANT ... TO PUBLIC.
-- Spec: unificacion-full-delta
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ============================================================
-- bdm_datos.unif_escenario_censo -- PERMANENTE
--
-- QUE RESPONDE. Cuantas direcciones resolvio CADA escenario de la Regla 2 en
-- una corrida, y cuantas no resolvio ninguno.
--
-- POR QUE EXISTE. La Regla 2 sella cada direccion con N_ID segun la etapa que
-- la unifico (H1 esc1, K2 esc2, L3 esc3, X4 motor, B5 esc4, C7 esc5). Ese
-- sello vive en bdm_tempo.stg_regla2_e2, que se dropea al cerrar la regla, y
-- la tabla final bdm_datos.unificacion_direccion solo guarda el PAR
-- (direccion, padre): sabe QUE se unifico, no POR QUE.
--
-- El legado tampoco lo persiste: tambien lo deja morir en staging. Esta tabla
-- NO corrige una infidelidad, AGREGA observabilidad que el legado nunca tuvo.
-- Para una migracion es justo lo que hace falta: el legado no tenia que
-- demostrar que hacia lo correcto, nosotros si.
--
-- PARA QUE SIRVE EN CONCRETO. Hay dos partes del legado sin implementar -- el
-- sitio 2 ('A6', etapa 5.1) y el criterio con que esc6 rompe empates -- y
-- ninguna de las dos produce ERROR: produce CERO filas, en silencio. Este
-- censo es la unica forma de medir cuanto del universo real cae ahi, o sea de
-- pasar de "no sabemos" a un numero con el que decidir.
--
-- HISTORICO ACUMULATIVO: una fila por (corrida, escenario), nunca se
-- sobrescribe. El escenario viaja DESCRITO, no solo sellado, para que la tabla
-- se lea sin tener que ir al codigo.
--
-- DISTSTYLE ALL: diez filas por corrida; replicarla abarata cualquier lectura.
-- Sin PK forzada: Redshift no fuerza constraints.
-- ============================================================
CREATE TABLE IF NOT EXISTS bdm_datos.unif_escenario_censo (
  lote           INTEGER      NOT NULL,   -- Lote_Corrida externo
  modo           VARCHAR(10)  NOT NULL,   -- FULL | DELTA (modo efectivamente aplicado)
  n_id           VARCHAR(10),             -- sello de la etapa; NULL = no lo resolvio nadie
  escenario      VARCHAR(120) NOT NULL,   -- que regla es, en texto legible
  ref_legado     VARCHAR(80)  NOT NULL,   -- donde vive en PRO_UnificacionR2.sql, o por que no
  direcciones    BIGINT       NOT NULL,   -- filas de stg_regla2_e2 con ese sello
  personas       BIGINT       NOT NULL,   -- distinct id_buro_persona
  fecha_hora     TIMESTAMP    NOT NULL,
  usuario_bd     VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (lote, n_id);
