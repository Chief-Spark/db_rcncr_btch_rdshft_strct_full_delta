-- ============================================================
-- 39b_ddl_nov_movilidad_mock.sql
-- ESPEJO MOCK de 39_ddl_nov_movilidad.sql. Generado por sustitucion:
-- los nombres de tabla reciben el sufijo _mock y NADA MAS cambia.
-- El diff contra el real debe salir vacio modulo ese sufijo.
-- Las justificaciones viven en el archivo real.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- bdm_datos.nov_movilidad_foto_mock -- PERMANENTE, INSERT-ONLY
-- ES LA PIEZA QUE FALTABA: el equivalente de
-- REC_STAGE.MTCalcularIndicadoresMovilidad, cuyo productor NO esta en el
-- material entregado (MANIFIESTO.md:68 ya lo listaba como hueco).
--
-- POR QUE HACE FALTA UNA TABLA NUEVA Y NO SIRVE ubicacion_atributo_hash:
-- esa tabla de la Fase 3 dice QUE algo cambio -- una segunda fila con otro
-- hash -- pero no QUE cambio: guarda el MD5, no los atributos. Para decir si
-- lo que cambio fue la ciudad o el estrato hay que haber guardado la ciudad y
-- el estrato. Anadirselos a ella seria tocar una tabla certificada de otra
-- fase; esta es de Novedades y se queda en Novedades.
--
-- INSERT-ONLY Y SOLO CUANDO CAMBIA, igual que la tabla de hash de la Fase 3 y
-- por el mismo motivo: si escribiera una fila por corrida y por ubicacion
-- creceria sin tope y sin informacion. Una fila nueva ES el evento.
--   La comparacion es entre las DOS fotos mas recientes de la misma
--   (persona, ubicacion). Con una sola foto no hay evento: una persona vista
--   por primera vez no "se mudo".
--
-- DISTKEY cod_dw_persona_ubic y SORTKEY (cod_dw_persona_ubic, fecha_foto):
-- la consulta que la lee siempre ordena por fecha dentro de la ubicacion.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.nov_movilidad_foto_mock (
  cod_dw_persona_ubic  BIGINT       NOT NULL,
  id_buro_persona      BIGINT       NOT NULL,
  cod_pin_persona      BIGINT,
  fecha_foto           DATE         NOT NULL,   -- la fecha de la corrida que la tomo
  -- Los tres atributos que se comparan. dato es el texto de la direccion y es
  -- el que decide CambioDir, del que dependen los otros dos.
  dato                 VARCHAR(201),
  codigo_dane          VARCHAR(20),
  ciudad               VARCHAR(30),
  estrato              VARCHAR(10),
  -- Arrastre, para no volver a unir a la etapa 9 al construir la MAT.
  tipo_identificacion  VARCHAR(30),
  lote                 INTEGER,
  fecha_actualizacion  TIMESTAMP DEFAULT GETDATE(),
  usuario_bd           VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (cod_dw_persona_ubic)
SORTKEY (cod_dw_persona_ubic, fecha_foto);

-- ------------------------------------------------------------
-- bdm_datos.mat_info_movilidad_mock  (legado MAT_INFO_MOVILIDAD)
-- Las 8 del contrato mas las tres de trazabilidad.
--
-- id va BIGINT y no INTEGER como el SCHEMA P0035_12, por lo mismo que en
-- mat_info_basica (D-NOV-04): se deriva de un FNV_HASH de 64 bits.
-- info_basica_id igual: es id_buro_persona.
--
-- DISTKEY info_basica_id y SORTKEY (info_basica_id, novedad): el consumidor
-- parte de la persona y pregunta que le cambio.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_movilidad_mock (
  id                     BIGINT,         -- derivada: FNV_HASH(persona|indicador|fecha)
  fecha                  DATE,           -- cuando se detecto el cambio
  descripcion            VARCHAR(100),   -- NULL: falta V_INDICADOR_MOVILIDAD
  novedad                VARCHAR(1000),  -- 'Cambio de Direccion' | 'de Ciudad' | 'de Estrato'
  info_basica_id         BIGINT,         -- id_buro_persona
  novedad_2              VARCHAR(30),    -- NULL: falta V_Hom_Ind_Mov_Linea
  tipo_identificacion    VARCHAR(30),
  numero_identificacion  BIGINT,
  lote                   INTEGER,
  fecha_actualizacion    TIMESTAMP DEFAULT GETDATE(),
  usuario_bd             VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (info_basica_id)
SORTKEY (info_basica_id, novedad);
