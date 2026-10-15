-- ============================================================
-- 20_ddl_cert_criterios_ord.sql
-- SLCOPRBA-1355: tablero de certificacion de ORDENAMIENTO (scoring de
-- contactabilidad). Gemelo de 13_ddl_cert_criterios.sql, que hace lo mismo
-- para Unificacion.
-- UTF-8 sin BOM. Sin acentos a proposito (igual que el resto de la cadena).
--
-- POR QUE UNA TABLA APARTE Y NO FILAS NUEVAS EN cert_criterio:
--   son dos procesos con documentos, ciclos de vida y alcances distintos.
--   Mezclarlos obligaria a filtrar por bloque en todas partes y romperia el
--   titular de Unificacion, que hoy cuenta 51 filas y resta GEO y GOB-03.
--   Separadas, cada tablero se lee solo y ninguno arrastra al otro.
--
-- POR QUE UN CATALOGO SEMBRADO:
--   una fila ausente es ambigua -- no se sabe si el criterio paso, si nadie
--   lo midio o si alguien lo borro de la bateria. Con el catalogo aqui, QA
--   siempre ve 90 filas: las que el gate no evalua salen SIN_EVALUAR de
--   forma explicita.
--
-- FUENTE:
--   Documento de Requerimientos - Proceso de Ordenamiento (Scoring de
--   Contactabilidad), sus 90 criterios:
--     F1-01..F1-08    Fase 1  Materializacion BTT + REC          (8)
--     F2-01..F2-10    Fase 2  Atributos de Cuenta                (10)
--     F3-01..F3-11    Fase 3  Ubicaciones                        (11)
--     F4-01..F4-09    Fase 4  Scoring, generales                 (9)
--     F4-DIR-01..06 / F4-TEL-01..05 / F4-CEL-01..06 / F4-EMA-01..04  (21)
--     RG-01..RG-10    Reglas generales transversales             (10)
--     G-01..G-06      Gobernanza de migracion                    (6)
--     CA-F01..F06 / CA-M01..M04 / CA-T01..T05                    (15)
--
-- ALCANCE DE ESTA ENTREGA: las Fases 1, 2 y 3 NO estan portadas a Redshift
--   (verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero
--   coincidencias en los tres repos). Son 29 criterios que el evaluador
--   marca NO_IMPLEMENTADO -- visibles, no ausentes. Lo que se certifica es
--   la Fase 4, que en el legado es un proceso SEPARABLE: vive integra en
--   Caracteristicas.txt, no en Prc_Ordenamiento2.sql, y corre desde otra
--   malla (BTEQ_CURSOR_131.BTQ) con los cuatro canales en paralelo.
--
-- ESTADOS que usa el gate (bdm_datos.cert_resultado_ord.estado):
--   PASSED            la consulta verifico el criterio
--   FAILED            la consulta verifico el criterio y NO se cumple
--   NO_IMPLEMENTADO   la funcionalidad no existe en el codigo
--   SIN_DATO          implementado, pero ningun dato de la bateria lo ejercita
--   BLOQUEADO         depende de un insumo externo no disponible
--   REVISION_MANUAL   propiedad de diseno o de proceso; no hay consulta
--   FUERA_DE_ALCANCE  no es responsabilidad de este desarrollo
--   NO_APLICA         no se evalua en esta fase (p.ej. DELTA sin mutacion)
--   SIN_EVALUAR       no es un estado almacenado: lo produce el COALESCE del
--                     tablero cuando el gate no escribio fila. En el tablero
--                     significa "defecto del gate", no "no hay dato".
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- Catalogo de criterios. Contenido fijo, propiedad de este archivo: se
-- reemplaza completo en cada despliegue para que el enunciado siempre
-- corresponda al documento vigente. TRUNCATE y no DELETE: no hay predicado
-- que seleccione "las filas viejas" y un DELETE sin WHERE viola [REDSHIFT:232].
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.cert_criterio_ord (
  criterio     VARCHAR(12)  NOT NULL,   -- F1-01 .. CA-T05
  bloque       VARCHAR(24)  NOT NULL,   -- FASE1|FASE2|FASE3|FASE4|REGLA_GRAL|GOBERNANZA|CA_FUNC|CA_MIGR|CA_TECN
  prioridad    VARCHAR(12)  NOT NULL,   -- la del documento
  verificable  VARCHAR(16)  NOT NULL,   -- CONSULTA | MANUAL | EXTERNO
  enunciado    VARCHAR(700) NOT NULL,
  evidencia    VARCHAR(700)             -- donde mira QA cuando sale FAILED
)
DISTSTYLE ALL
SORTKEY (bloque, criterio);

-- ------------------------------------------------------------
-- Resultado por corrida. Una fila por (lote, modo, criterio).
-- Sin PK forzada: Redshift no fuerza constraints.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.cert_resultado_ord (
  lote         INTEGER      NOT NULL,
  modo         VARCHAR(10)  NOT NULL,   -- FULL | DELTA1 | DELTA2 | FULL2
  criterio     VARCHAR(12)  NOT NULL,
  estado       VARCHAR(20)  NOT NULL,
  detalle      VARCHAR(1024),
  fecha_hora   TIMESTAMP    NOT NULL,
  usuario_bd   VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (lote, criterio);

-- ------------------------------------------------------------
-- Ultimo veredicto de cada criterio.
--
-- POR QUE NO 'WHERE lote = MAX(lote)': el numero de lote NO ordena las
-- corridas en el tiempo, igual que en el tablero de Unificacion. Se ordena
-- por fecha_hora y se desempata por lote.
--
-- El desempate secundario existe porque el gate es NONATOMIC: cada INSERT es
-- su propia transaccion y dos criterios de la misma llamada pueden quedar con
-- marcas de tiempo distintas por milisegundos.
--
-- WITH NO SCHEMA BINDING: consistente con el resto de las vistas del
-- proyecto, de modo que el orden de despliegue no la rompa.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW bdm_datos.v_cert_ord_ultimo AS
SELECT criterio, estado, detalle, lote, modo, fecha_hora
FROM ( SELECT criterio, estado, detalle, lote, modo, fecha_hora,
              ROW_NUMBER() OVER (PARTITION BY criterio
                                 ORDER BY fecha_hora DESC, lote DESC) AS rn
         FROM bdm_datos.cert_resultado_ord ) u
WHERE rn = 1
WITH NO SCHEMA BINDING;

-- ------------------------------------------------------------
-- Siembra del catalogo: 90 filas, 1:1 con el documento.
-- ------------------------------------------------------------
TRUNCATE TABLE bdm_datos.cert_criterio_ord;

INSERT INTO bdm_datos.cert_criterio_ord
  (criterio, bloque, prioridad, verificable, enunciado, evidencia)
SELECT c.criterio, c.bloque, c.prioridad, c.verificable, c.enunciado, c.evidencia
FROM (
  SELECT 'F1-01' AS criterio, 'FASE1' AS bloque, 'Alta' AS prioridad, 'CONSULTA' AS verificable,
         'El sistema debe identificar que personas tuvieron lotes nuevos en el modelo BTT (cuentas, comportamiento crediticio) desde la ultima ejecucion.' AS enunciado,
         'legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' AS evidencia UNION ALL
  SELECT 'F1-02','FASE1','Alta','CONSULTA',
         'El sistema debe identificar que personas tuvieron lotes nuevos en el modelo REC (ubicaciones, bloqueos, unificacion) desde la ultima ejecucion.',
         'legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F1-03','FASE1','Alta','CONSULTA',
         'La unificacion de ambos modelos (BTT + REC) no debe generar duplicados: cada combinacion persona-buro debe ser unica en unifica_btt_reconocer.',
         'legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F1-04','FASE1','Alta','CONSULTA',
         'Si no hay lotes nuevos en ningun modelo, la tabla de trabajo debe quedar vacia y no se ejecuta reproceso.',
         'legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F1-05','FASE1','Alta','CONSULTA',
         'Al finalizar, las 14 tablas intermedias de paso deben eliminarse automaticamente.',
         'legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F1-06','FASE1','Alta','CONSULTA',
         'Se debe registrar inicio y fin de la fase en el log de ejecucion con timestamp.',
         'legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F1-07','FASE1','Media','CONSULTA',
         'El universo a ordenar se establece por fecha parametrica al proceso o por la fecha de ultimo ordenamiento almacenada en tabla de control.',
         'legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F1-08','FASE1','Alta','CONSULTA',
         'Los cambios identificados incluyen: carga o actualizacion de ubicaciones, estandarizacion de direcciones, unificacion de direcciones, bloqueos de direcciones, registros nuevos en cuentas y cambios en comportamientos o endeudamiento.',
         'legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F2-01','FASE2','Alta','CONSULTA',
         'Solo se deben extraer cuentas de personas identificadas en la Fase 1 (materializacion).',
         'legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F2-02','FASE2','Alta','CONSULTA',
         'Se debe calcular una ventana temporal de 12 meses hacia atras desde la fecha de novedad.',
         'legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F2-03','FASE2','Alta','CONSULTA',
         'Se debe extraer el comportamiento activo dentro de esa ventana.',
         'legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F2-04','FASE2','Alta','CONSULTA',
         'Se debe extraer el comportamiento pasivo dentro de esa ventana.',
         'legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F2-05','FASE2','Alta','CONSULTA',
         'Cada cuenta se debe clasificar en uno de 9 portafolios: CO, RO, VE, HP, IN, OT, CC, AH, CT. No puede haber valores fuera de este catalogo.',
         'legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F2-06','FASE2','Alta','CONSULTA',
         'No puede haber portafolios vacios (NULL).',
         'legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F2-07','FASE2','Alta','CONSULTA',
         'Se debe generar un hash MD5 de exactamente 32 caracteres por cada registro para detectar cambios entre ejecuciones.',
         'legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F2-08','FASE2','Alta','CONSULTA',
         'El campo concatena no puede ser vacio ni NULL.',
         'legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F2-09','FASE2','Alta','CONSULTA',
         'Se debe registrar inicio y fin de la fase en el log de ejecucion.',
         'legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F2-10','FASE2','Alta','CONSULTA',
         'Se generan 3 fechas de insumo por cada Persona - Cuenta - Suscriptor para el calculo de numero de meses de reporte.',
         'legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F3-01','FASE3','Alta','CONSULTA',
         'Se deben excluir automaticamente los registros bloqueados.',
         'legado Prc_Ordenamiento2.sql:1123-1126 (anti-join contra bloqueo). NO existe filtro de bloqueo en el Ordenamiento de Redshift.' UNION ALL
  SELECT 'F3-02','FASE3','Alta','CONSULTA',
         'Se deben excluir los registros unificados (hijos). Solo se procesan direcciones vigentes (ind_unificacion IS NULL).',
         'legado PRO_ORD_CALC_UBICACIONES_2 (Prc_Ordenamiento2.sql:1127, b.Ind_Unificacion IS NULL). PARCIAL en Redshift: el filtro existe en sp_ordenamiento_preparar_insumos_edf (7 veces) y en consolidacion, pero sin la persistencia por hash de la fase.' UNION ALL
  SELECT 'F3-03','FASE3','Alta','CONSULTA',
         'Tipo persona se debe clasificar correctamente (no puede haber tipo_persona NULL).',
         'legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F3-04','FASE3','Alta','CONSULTA',
         'Se debe generar un hash MD5 de 32 caracteres por cada direccion.',
         'legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F3-05','FASE3','Alta','CONSULTA',
         'Los registros nuevos se deben insertar en ubicacion_atributo_hash.',
         'legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F3-06','FASE3','Alta','CONSULTA',
         'Los registros modificados (donde el hash difiere) se deben actualizar. Los registros sin cambios no se tocan.',
         'legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F3-07','FASE3','Alta','CONSULTA',
         'La llave de deteccion de cambios es: cod_pin_persona + id_buro_persona + cod_dw_persona_ubic.',
         'legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F3-08','FASE3','Alta','CONSULTA',
         'Se debe registrar inicio y fin de la fase en el log de ejecucion.',
         'legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F3-09','FASE3','Alta','CONSULTA',
         'Solo se ordenan ubicaciones con cuentas activas para la fuente ICBDIR (Suscriptor). Para otras fuentes no se asocian cuentas a las personas y sus ubicaciones.',
         'legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F3-10','FASE3','Alta','CONSULTA',
         'No se ordenan ubicaciones que no sean validas (resultado de algoritmo de estandarizacion).',
         'legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'F3-11','FASE3','Alta','CONSULTA',
         'No se ordenan ubicaciones que hayan sido unificadas (resultado del algoritmo de unificacion).',
         'mismo predicado que F3-02; se evalua junto a el.' UNION ALL
  SELECT 'F4-01','FASE4','Alta','CONSULTA',
         'El score se debe calcular para 4 canales: Direccion (DIR), Telefono Fijo (TEL), Celular (CEL) y Email (EMA).',
         'score_ordenamiento agrupado por canal; SP sp_ordenamiento_scoring_{dir,tel,cel,ema}_edf' UNION ALL
  SELECT 'F4-02','FASE4','Alta','CONSULTA',
         'La formula es: (categoria / max_categoria) x Beta por cada caracteristica del canal.',
         'legado Caracteristicas.txt, las 47 tablas *_Peso; el divisor es un LITERAL por caracteristica, no un MAX calculado' UNION ALL
  SELECT 'F4-03','FASE4','Alta','CONSULTA',
         'Los coeficientes Beta se deben leer siempre de la tabla beta_ordenamiento, nunca hardcodeados en el codigo.',
         'LEFT JOIN a bdm_datos.beta_ordenamiento en los 4 SP de scoring; cero literales de beta en el codigo' UNION ALL
  SELECT 'F4-04','FASE4','Alta','CONSULTA',
         'El ranking (lugar) se calcula como ROW_NUMBER ordenado por score descendente, agrupado por persona dentro de cada canal.',
         'ROW_NUMBER() OVER (PARTITION BY id_buro_persona ORDER BY score DESC) en los 4 SP; legado Caracteristicas.txt:105,79,72,88' UNION ALL
  SELECT 'F4-05','FASE4','Alta','CONSULTA',
         'El score no puede ser NULL para ningun dato vigente.',
         'score_ordenamiento WHERE score IS NULL debe dar 0. En el legado la suma no lleva COALESCE y un beta ausente anula el canal entero' UNION ALL
  SELECT 'F4-06','FASE4','Alta','CONSULTA',
         'El valor orden_prioridad resultante se debe escribir en la tabla relacion_persona_ubicacion.',
         'bdm_datos.rpu_orden_prioridad, escrita por sp_ordenamiento_consolidacion_edf' UNION ALL
  SELECT 'F4-07','FASE4','Alta','CONSULTA',
         'Solo los datos vigentes (no hijos de Unificacion) reciben score.',
         'predicado COALESCE(ind_unificacion,0) <> 1 en preparar_insumos y en consolidacion' UNION ALL
  SELECT 'F4-08','FASE4','Alta','CONSULTA',
         'El proceso es idempotente: ejecutar 2 veces consecutivas produce el mismo resultado sin duplicar registros.',
         'comparacion FULL vs FULL2 del mismo universo; exige desempate determinista en el ORDER BY' UNION ALL
  SELECT 'F4-09','FASE4','Alta','CONSULTA',
         'Los Betas deben permanecer parametrizados y versionables; no deben quedar embebidos en la logica de scoring.',
         '02_carga_betas_ritm5226589.sql, 47 filas; ningun valor de beta en los SP' UNION ALL
  SELECT 'F4-DIR-01','FASE4','Alta','CONSULTA',
         'Se deben calcular 12 caracteristicas: DIR001IN, DIR004RO, DIR007TO, DIR010FI, DIR013OT, DIR017, DIR019, DIR034FI, DIR050TO, DIR057, DIR059, DIR009.',
         'sp_ordenamiento_scoring_dir_edf; 12 terminos en la suma' UNION ALL
  SELECT 'F4-DIR-02','FASE4','Alta','CONSULTA',
         'DIR001IN = meses desde primer reporte de la direccion.',
         'legado Caracteristicas.txt:241 (origen :226, :172)' UNION ALL
  SELECT 'F4-DIR-03','FASE4','Alta','CONSULTA',
         'DIR009 = entidades distintas reportando la direccion.',
         'legado Caracteristicas.txt:201; unico DIR con prefijo CO01' UNION ALL
  SELECT 'F4-DIR-04','FASE4','Alta','CONSULTA',
         'DIR017 = tipo ubicacion (RES=1, LAB=2, CRR=3).',
         'DIVERGENCIA DEL RF: en el legado (Caracteristicas.txt:147) DIR015 cuenta RES, DIR016 cuenta CRR y DIR017 cuenta LAB. Son tres contadores, no un codigo. Ademas las etiquetas de salida Laboral y Correspondecia estan cruzadas en Orden_Direcc (:159). Para bitacora G-03.' UNION ALL
  SELECT 'F4-DIR-05','FASE4','Alta','CONSULTA',
         'La categorizacion debe usar los rangos y umbrales definidos en el modelo de scoring vigente.',
         'legado Caracteristicas.txt: umbrales LITERALES dentro de cada CASE WHEN de las tablas *_Cat; no hay tabla de parametros' UNION ALL
  SELECT 'F4-DIR-06','FASE4','Alta','CONSULTA',
         'Los Betas utilizados deben tener prefijo CO00DIR o CO01DIR.',
         '02_carga_betas_ritm5226589.sql: 11 CO00DIR + 1 CO01DIR (DIR009)' UNION ALL
  SELECT 'F4-TEL-01','FASE4','Alta','CONSULTA',
         'Se deben calcular 11 caracteristicas: TEL001 a TEL025.',
         'sp_ordenamiento_scoring_tel_edf; 11 calculadas, 10 en la suma (TEL020 fuera, igual que el legado)' UNION ALL
  SELECT 'F4-TEL-02','FASE4','Alta','CONSULTA',
         'TEL010 = porcentaje de reportes con coincidencia geografica.',
         'legado Caracteristicas.txt:249. En Redshift coincidencia_geo esta fijada a 0 (preparar_insumos_edf:234), de modo que TEL010 es constante' UNION ALL
  SELECT 'F4-TEL-03','FASE4','Alta','CONSULTA',
         'TEL020 = indicador binario de coincidencia geografica (1 si no tiene, 4 si tiene).',
         'legado Caracteristicas.txt:174 y :37. Confirmado FUERA de la suma (:238): la paridad es deliberada' UNION ALL
  SELECT 'F4-TEL-04','FASE4','Alta','CONSULTA',
         'Solo se deben considerar reportes validos (se excluyen los marcados como NO VALIDA).',
         'legado Caracteristicas.txt:46 y :160. En Redshift NO excluye: degrada el numerador (scoring_tel_edf:30-38)' UNION ALL
  SELECT 'F4-TEL-05','FASE4','Alta','CONSULTA',
         'Los Betas utilizados deben tener prefijo CO01TEL.',
         '02_carga_betas_ritm5226589.sql: 11 CO01TEL' UNION ALL
  SELECT 'F4-CEL-01','FASE4','Alta','CONSULTA',
         'Se deben calcular 11 caracteristicas: CEL003 a CEL023.',
         'sp_ordenamiento_scoring_cel_edf; las 11 en la suma' UNION ALL
  SELECT 'F4-CEL-02','FASE4','Alta','CONSULTA',
         'CEL013 = operador principal identificado por prefijos (310-314).',
         'scoring_cel_edf:32. Los prefijos estan HARDCODEADOS en el SP y duplican el catalogo catalogo_tipo_cuenta_tel, que los marca PREPAGO' UNION ALL
  SELECT 'F4-CEL-03','FASE4','Alta','CONSULTA',
         'CEL014 = indicador de si la persona tiene cuenta POSPAGO.',
         'DIVERGENCIA DEL RF, REAPUNTADA (SLCOPRBA-1355): CEL014 no mira el tipo de cuenta -- es la cuota de reportes de mas de 24 meses (Caracteristicas.txt:2450-2453). La que SI depende del tipo de cuenta es CEL019: MAX del peso de V_Tipo_Cuenta_Ord (:112). El criterio se evalua ahora sobre CEL019, que es donde vive el enunciado. Para bitacora G-03.' UNION ALL
  SELECT 'F4-CEL-04','FASE4','Alta','CONSULTA',
         'CEL018 = valor del operador segun tabla de mapeo V_Operador_Ord_Cel.',
         'legado Caracteristicas.txt:80, lookup por SUBSTR(texto,1,3). En Redshift: bdm_datos.catalogo_operador_ord_cel (interim DEV)' UNION ALL
  SELECT 'F4-CEL-05','FASE4','Alta','CONSULTA',
         'Los Betas utilizados deben tener prefijo CO01CEL.',
         '02_carga_betas_ritm5226589.sql: 11 CO01CEL' UNION ALL
  SELECT 'F4-CEL-06','FASE4','Alta','CONSULTA',
         'Cuando el operador no se encuentra en la tabla de mapeo, se debe asignar un valor por defecto definido funcionalmente (operador no mapeado).',
         'DIVERGENCIA: el legado asigna 0 (Caracteristicas.txt:80) y ademas EXCLUYE el celular del ranking (WHERE CO01CEL018 <> 0, :79). Redshift asigna 0.22 y no excluye. El 0.22 no aparece en el legado. Para bitacora G-03.' UNION ALL
  SELECT 'F4-EMA-01','FASE4','Alta','CONSULTA',
         'Se deben calcular 13 caracteristicas: EMA003 a EMA025.',
         'sp_ordenamiento_scoring_ema_edf; 13 calculadas, 9 en la suma (EMA003/007/018/025 fuera, igual que el legado)' UNION ALL
  SELECT 'F4-EMA-02','FASE4','Alta','CONSULTA',
         'EMA014 = indicador de dominio conocido (gmail, hotmail, yahoo, outlook).',
         'DIVERGENCIA DEL RF: el dominio conocido es EMA018 (Caracteristicas.txt:94) y la lista tiene CINCO elementos (hotmail, gmail, yahoo, live, outlook). EMA014 es el porcentaje de reportes de mas de 24 meses (:142). Ademas EMA018 esta FUERA de la suma. Para bitacora G-03.' UNION ALL
  SELECT 'F4-EMA-03','FASE4','Alta','CONSULTA',
         'EMA025 = ratio de recencia calculado como (min_meses / max_meses x 100).',
         'DIVERGENCIA DEL RF: EMA025 es la LONGITUD DEL BUZON (local-part) bucketizada en campana, con pico en 9-12 caracteres (Caracteristicas.txt:170 y :91). No es un ratio de recencia. Y esta fuera de la suma. Para bitacora G-03.' UNION ALL
  SELECT 'F4-EMA-04','FASE4','Alta','CONSULTA',
         'Los Betas utilizados deben tener prefijo CO01EMA.',
         '02_carga_betas_ritm5226589.sql: 13 CO01EMA' UNION ALL
  SELECT 'RG-01','REGLA_GRAL','Alta','CONSULTA',
         'Las fases se ejecutan siempre en secuencia: F1 -> F2 -> F3 -> F4 (hay dependencia de tablas intermedias).',
         'En Redshift solo existe F4. En el legado el scoring corre desde OTRA malla (BTEQ_CURSOR_131.BTQ) y con los 4 canales en PARALELO; ORDENAMIENTO_242_131.BTQ solo cubre F1-F3.' UNION ALL
  SELECT 'RG-02','REGLA_GRAL','Alta','CONSULTA',
         'Los coeficientes Beta deben coincidir exactamente con los valores vigentes en la tabla beta_ordenamiento.',
         'bdm_datos.beta_ordenamiento, 47 filas del RITM5226589' UNION ALL
  SELECT 'RG-03','REGLA_GRAL','Alta','CONSULTA',
         'El proceso es idempotente: 2 ejecuciones consecutivas producen exactamente el mismo resultado.',
         'FULL vs FULL2. Exige desempate determinista: el legado no lo tiene y NO es reproducible ni en Teradata' UNION ALL
  SELECT 'RG-04','REGLA_GRAL','Alta','CONSULTA',
         'Las cuentas bloqueadas se excluyen del calculo de atributos.',
         'pertenece a la Fase 2. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'RG-05','REGLA_GRAL','Alta','CONSULTA',
         'Solo direcciones vigentes (no hijas) reciben score.',
         'se evalua junto a F4-07' UNION ALL
  SELECT 'RG-06','REGLA_GRAL','Alta','CONSULTA',
         'El hash MD5 debe producir una salida consistente y deterministica para los mismos datos de entrada.',
         'pertenece a las Fases 2 y 3. No hay MD5 en el Ordenamiento de Redshift. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'RG-07','REGLA_GRAL','Alta','CONSULTA',
         'Todos los esquemas son fijos (rec_stage, rec_datos). No se utiliza SQL dinamico.',
         'en Redshift son bdm_datos / bdm_tempo / bdm_stage, fijos. El legado SI usa SQL dinamico con cursores (Ordenamiento.sql:244); nuestro port lo elimina: divergencia FAVORABLE, para bitacora' UNION ALL
  SELECT 'RG-08','REGLA_GRAL','Alta','CONSULTA',
         'Cada fase registra inicio y fin con timestamp en la tabla de log de ejecucion.',
         'bdm_datos.ord_control_etapa / bdm_stage.mock_ord_control_etapa' UNION ALL
  SELECT 'RG-09','REGLA_GRAL','Alta','EXTERNO',
         'Para un mismo corte funcional, Redshift debe reproducir el resultado Teradata o explicar una diferencia aprobada.',
         'exige un extracto Teradata del mismo corte; no disponible. Se certifica con la bitacora de divergencias' UNION ALL
  SELECT 'RG-10','REGLA_GRAL','Alta','EXTERNO',
         'No se debe aprovechar el cambio de plataforma para modificar umbrales, redefinir caracteristicas, alterar Betas, introducir nuevas senales o cambiar exclusiones sin decision funcional explicita.',
         'acta del area funcional. Las divergencias detectadas estan listadas en los criterios F4-DIR-04, F4-CEL-06, F4-EMA-02 y F4-EMA-03' UNION ALL
  SELECT 'G-01','GOBERNANZA','Alta','EXTERNO',
         'Toda diferencia entre el comportamiento Teradata y la construccion Redshift debe clasificarse como: (a) Paridad de migracion, (b) Cambio funcional aprobado, o (c) Asunto tecnico pendiente de validacion.',
         'acta de aprobacion del area funcional. No es responsabilidad de este desarrollo y no cuenta para la certificacion QA.' UNION ALL
  SELECT 'G-02','GOBERNANZA','Alta','EXTERNO',
         'Las diferencias clasificadas como cambio funcional requieren aprobacion explicita del area funcional antes de certificacion.',
         'acta de aprobacion del area funcional. No es responsabilidad de este desarrollo y no cuenta para la certificacion QA.' UNION ALL
  SELECT 'G-03','GOBERNANZA','Alta','EXTERNO',
         'Se debe mantener una bitacora de diferencias que registre: tipo de diferencia, descripcion, decision tomada, fecha y responsable.',
         'acta de aprobacion del area funcional. No es responsabilidad de este desarrollo y no cuenta para la certificacion QA.' UNION ALL
  SELECT 'G-04','GOBERNANZA','Alta','EXTERNO',
         'Si se cambia el algoritmo durante la migracion, la iniciativa deja de ser solo migracion y pasa a ser migracion mas evolucion funcional, requiriendo aprobacion adicional.',
         'acta de aprobacion del area funcional. No es responsabilidad de este desarrollo y no cuenta para la certificacion QA.' UNION ALL
  SELECT 'G-05','GOBERNANZA','Alta','EXTERNO',
         'La validacion principal debe comparar resultados funcionales para un mismo corte de datos y mismos parametros.',
         'acta de aprobacion del area funcional. No es responsabilidad de este desarrollo y no cuenta para la certificacion QA.' UNION ALL
  SELECT 'G-06','GOBERNANZA','Media','EXTERNO',
         'Los Betas deben poder versionarse y auditarse: cada ejecucion debe registrar que version de Betas utilizo.',
         'acta de aprobacion del area funcional. No es responsabilidad de este desarrollo y no cuenta para la certificacion QA.' UNION ALL
  SELECT 'CA-F01','CA_FUNC','Alta','CONSULTA',
         'Cada dato de contacto vigente tiene un orden_prioridad calculado dentro de su canal.',
         'rpu_orden_prioridad contra score_ordenamiento' UNION ALL
  SELECT 'CA-F02','CA_FUNC','Alta','CONSULTA',
         'Los datos marcados como hijos en Unificacion (ind_unificacion = 1) NO reciben score ni ranking.',
         'arquetipo de hija unificada en la matriz mock de Ordenamiento' UNION ALL
  SELECT 'CA-F03','CA_FUNC','Alta','CONSULTA',
         'El score se calcula estrictamente con la formula de regresion logistica usando los Betas vigentes de beta_ordenamiento.',
         'recalculo independiente del score de un arquetipo conocido' UNION ALL
  SELECT 'CA-F04','CA_FUNC','Alta','CONSULTA',
         '0 scores duplicados para el mismo dato de contacto en el mismo canal (garantia de idempotencia).',
         'COUNT(*) vs COUNT(DISTINCT) por (cod_dw_persona_ubic, canal)' UNION ALL
  SELECT 'CA-F05','CA_FUNC','Alta','CONSULTA',
         'Los coeficientes Beta utilizados coinciden exactamente con los valores vigentes en beta_ordenamiento.',
         'se evalua junto a RG-02' UNION ALL
  SELECT 'CA-F06','CA_FUNC','Alta','CONSULTA',
         'El ranking refleja correctamente la prioridad: valor 1 = mayor probabilidad relativa de contacto.',
         'el lugar 1 de cada persona y canal es el de score maximo' UNION ALL
  SELECT 'CA-M01','CA_MIGR','Alta','EXTERNO',
         'Para el mismo corte funcional y mismos parametros, Redshift debe reproducir el resultado de Teradata.',
         'BLOQUEADO: faltan las vistas frontera V_DIRECCIONES_TEMP_{TF,TM,DF,ML} y V_Operador_Ord_Cel, y las Fases 1-3 no estan portadas. Sin los mismos insumos no hay paridad numerica demostrable.' UNION ALL
  SELECT 'CA-M02','CA_MIGR','Alta','EXTERNO',
         'Toda diferencia detectada debe estar documentada en la bitacora de diferencias con su clasificacion y aprobacion.',
         'bitacora de G-03' UNION ALL
  SELECT 'CA-M03','CA_MIGR','Alta','EXTERNO',
         'No se introducen cambios funcionales implicitos durante la migracion.',
         'acta del area funcional' UNION ALL
  SELECT 'CA-M04','CA_MIGR','Alta','EXTERNO',
         'Las cuatro fases conservan su dependencia funcional: Fase 1 -> Fase 2 -> Fase 3 -> Fase 4.',
         'solo F4 esta portada; la dependencia no es verificable hasta que existan F1-F3' UNION ALL
  SELECT 'CA-T01','CA_TECN','Alta','CONSULTA',
         'El hash MD5 produce una salida consistente y deterministica de 32 caracteres.',
         'pertenece a las Fases 2 y 3. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no.' UNION ALL
  SELECT 'CA-T02','CA_TECN','Alta','CONSULTA',
         'Cada fase registra inicio y fin con timestamp en el log de ejecucion.',
         'se evalua junto a RG-08' UNION ALL
  SELECT 'CA-T03','CA_TECN','Alta','CONSULTA',
         'Las tablas intermedias se eliminan al finalizar cada fase.',
         'sp_ordenamiento_drop_staging_edf, 12 tablas bdm_tempo.stg_*' UNION ALL
  SELECT 'CA-T04','CA_TECN','Alta','CONSULTA',
         'Los esquemas son fijos (rec_stage, rec_datos). No se utiliza SQL dinamico.',
         'se evalua junto a RG-07' UNION ALL
  SELECT 'CA-T05','CA_TECN','Alta','CONSULTA',
         'El proceso soporta ejecucion incremental (solo personas con cambios) y no requiere reprocesar todo el universo.',
         'stg_ord_personas_alcance en modo DELTA contra FULL'
) c;
