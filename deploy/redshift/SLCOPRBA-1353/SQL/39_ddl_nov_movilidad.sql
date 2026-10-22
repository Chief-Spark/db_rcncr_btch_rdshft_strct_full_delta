-- ============================================================
-- 39_ddl_nov_movilidad.sql
-- SLCOPRBA-1399: tabla final del dominio MOVILIDAD de Novedades (d6).
-- Septima y ultima MAT.
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- UTF-8 sin BOM. Sin acentos a proposito.
--
-- LEGADO: PRO_Novedad_Linea_Indic_Movilidad (Novedad.sql:1508-2165) para el
-- lado Novedades, y P0029_INDICADORES_MOVILIDAD (4 archivos, 593 lineas) para
-- la carga del indicador. Los dos estan en el repo.
--
-- QUE ES MOVILIDAD, FUNCIONALMENTE: "esta persona se mudo", respondido en
-- cuatro indicadores que el legado nombra literalmente
-- (P0029_INDICADORES_MOVILIDAD_111.BTQ:62-68): Cambio de Direccion, Cambio de
-- Estrato, Cambio de Ciudad y Cambio de Localidad.
--
-- ------------------------------------------------------------
-- ES UNA TABLA DE EVENTOS, NO DE BANDERAS, Y DE ESO DEPENDE TODO LO DEMAS.
-- Las cuatro ramas del legado son UNION ALL y cada una filtra por SU propio
-- cambio (CambioDir = 1; ... AND CambioEstrato = 1; etc.), de modo que UNA
-- FILA EXISTE SOLO CUANDO ESE CAMBIO SE DETECTO. No hay ninguna fila que diga
-- "no cambio de estrato": la ausencia de fila es "no se detecto".
--   Esto es lo que permite portar tres de los cuatro indicadores sin mentir.
--   Un atributo con poco dato produce MENOS FILAS, no filas falsas, al
--   contrario de lo que pasaria en una tabla de banderas por persona.
--   (Se escribio antes la conclusion contraria y era un error: ver la seccion
--   del estrato en dt/docs/BITACORA_DIFERENCIAS.md.)
--
-- LAS CUATRO RAMAS EXIGEN CambioDir = 1. Ningun indicador se dispara sin un
-- cambio de direccion previo: los otros tres son atributos que se comparan
-- SOBRE ESE MISMO EVENTO, no deltas independientes. Eso abarata el port, y es
-- la razon por la que el disparador es la foto de abajo y no tres deteccciones
-- separadas.
--
-- SE PORTAN TRES DE LOS CUATRO. Falta Cambio de Localidad, y no por descuido:
-- LOCALIDAD / comuna NO EXISTE EN EDF por ninguna via -- buscado en el
-- inventario de 1.072 columnas del datashare y en Confluence (espacios CCBR y
-- EDCLMI, donde las coincidencias son productos y no campos).
--
-- ------------------------------------------------------------
-- EL CONTRATO SON 8 COLUMNAS, del SCHEMA P0035_12 (130.TPT:134-143) menos
-- IN_Severidad. Mas las tres de trazabilidad.
--
-- LAS OCHO SE POBLAN desde el 2026-10-22. Hasta esa fecha eran seis: las
-- dos que faltaban, `descripcion` (VIM.VALOR_INDICADOR_MOVILIDAD,
-- Novedad.sql:1782) y `novedad_2` (V_Hom_Ind_Mov_Linea, :1923-1924), salen
-- de los dos catalogos que llegaron ese dia
-- (26_ddl_catalogo_movilidad.sql).
-- `novedad` ya se poblaba sin catalogo: es el NOMBRE CORTO del indicador y
-- sus valores son los literales que el propio P0029 escribe en su filtro
-- ('Cambio de Direccion', 'Cambio de Estrato', 'Cambio de Ciudad'). Resulta
-- que ademas es la LLAVE con la que los dos catalogos se unen.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- bdm_datos.nov_movilidad_foto -- PERMANENTE, INSERT-ONLY
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
CREATE TABLE IF NOT EXISTS bdm_datos.nov_movilidad_foto (
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
-- bdm_datos.mat_info_movilidad  (legado MAT_INFO_MOVILIDAD)
-- Las 8 del contrato mas las tres de trazabilidad.
--
-- id va BIGINT y no INTEGER como el SCHEMA P0035_12, por lo mismo que en
-- mat_info_basica (D-NOV-04): se deriva de un FNV_HASH de 64 bits.
-- info_basica_id igual: es id_buro_persona.
--
-- DISTKEY info_basica_id y SORTKEY (info_basica_id, novedad): el consumidor
-- parte de la persona y pregunta que le cambio.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.mat_info_movilidad (
  id                     BIGINT,         -- derivada: FNV_HASH(persona|indicador|fecha)
  fecha                  DATE,           -- cuando se detecto el cambio
  descripcion            VARCHAR(100),   -- la FRASE larga del indicador (catalogo)
  novedad                VARCHAR(1000),  -- 'Cambio de Direccion' | 'de Ciudad' | 'de Estrato'
  info_basica_id         BIGINT,         -- id_buro_persona
  novedad_2              VARCHAR(30),    -- codigo Linea: CAM_LOC | CAM_CIU | CAM_EST
  tipo_identificacion    VARCHAR(30),
  numero_identificacion  BIGINT,
  lote                   INTEGER,
  fecha_actualizacion    TIMESTAMP DEFAULT GETDATE(),
  usuario_bd             VARCHAR(100)
)
DISTSTYLE KEY DISTKEY (info_basica_id)
SORTKEY (info_basica_id, novedad);
