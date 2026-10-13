-- ============================================================
-- 13_ddl_cert_criterios.sql
-- SLCOPRBA-1355: tablero de certificacion de los 51 criterios de aceptacion.
-- UTF-8 sin BOM. Sin acentos a proposito (igual que el resto de la cadena).
--
-- POR QUE UN CATALOGO Y NO SOLO UNA TABLA DE RESULTADOS:
--   el mismo razonamiento del censo de escenarios. Una fila ausente es
--   ambigua -- no se sabe si el criterio paso, si nadie lo midio o si alguien
--   lo borro de la bateria. Con el catalogo sembrado aqui, QA siempre ve 51
--   filas: las que el gate no evalua salen SIN_EVALUAR de forma explicita.
--
-- FUENTES:
--   Documento de Requerimientos - Unificacion de Direcciones Fisicas
--     (R1-01..R1-08, R2-01..R2-14, R3-01..R3-10, G-01..G-10, GOB-01..GOB-04)
--   Criterios de Aceptacion - Proceso GEO (Regla 3) - Guia de QA
--     (CA-01..CA-05)
--
-- ESTADOS que usa el gate (bdm_datos.cert_resultado.estado):
--   PASSED            la consulta verifico el criterio
--   FAILED            la consulta verifico el criterio y NO se cumple
--   NO_IMPLEMENTADO   la funcionalidad no existe en el codigo
--   SIN_DATO          implementado, pero ningun dato de la bateria lo ejercita
--   BLOQUEADO         depende de un insumo externo (datashare, extracto
--                     Teradata, ArcGIS/S3) que no esta disponible
--   REVISION_MANUAL   es propiedad de diseno o de proceso; no hay consulta
--                     que la pueda afirmar
--   FUERA_DE_ALCANCE  el criterio no es responsabilidad de este desarrollo y
--                     no cuenta para la certificacion QA. Se deja visible para
--                     que el tablero siga mapeando 1:1 con el documento: un
--                     criterio retirado del catalogo seria indistinguible de
--                     uno olvidado.
--   NO_APLICA         el criterio no se evalua en esta fase. Caso tipico: un
--                     escenario de la Regla 2 en un DELTA sobre datos sin
--                     mutar, donde cero unificaciones nuevas es el resultado
--                     CORRECTO y no un fallo. Se certifica en la fase FULL.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- Catalogo de criterios. Es un catalogo de contenido fijo, propiedad de este
-- archivo: se reemplaza completo en cada despliegue para que el enunciado
-- siempre corresponda al documento vigente. Por eso TRUNCATE y no DELETE: no
-- hay predicado que seleccione "las filas viejas" y un DELETE sin WHERE viola
-- la politica [REDSHIFT:232].
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.cert_criterio (
  criterio     VARCHAR(12)  NOT NULL,   -- R1-01 .. GOB-04, CA-01 .. CA-05
  bloque       VARCHAR(24)  NOT NULL,   -- REGLA1|REGLA2|REGLA3|GENERAL|GOBERNANZA|GEO
  prioridad    VARCHAR(12)  NOT NULL,   -- la del documento
  verificable  VARCHAR(16)  NOT NULL,   -- CONSULTA | MANUAL
  enunciado    VARCHAR(700) NOT NULL,
  evidencia    VARCHAR(500)             -- donde mira QA cuando sale FAILED
)
DISTSTYLE ALL
SORTKEY (bloque, criterio);

-- ------------------------------------------------------------
-- Resultado por corrida. Una fila por (lote, modo, criterio).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.cert_resultado (
  lote         INTEGER      NOT NULL,
  modo         VARCHAR(10)  NOT NULL,   -- FULL | DELTA1 | DELTA2 | FULL2 | GEO
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
-- corridas en el tiempo. La bateria corre primero el e2e (lotes 1356601,
-- 1356602, 1356604) y despues la convergencia (1356501..1356504), que son
-- numericamente MENORES. Con MAX(lote) el tablero mostraria la evaluacion del
-- e2e, donde G-06 todavia sale SIN_DATO porque los criterios de convergencia
-- CA-C01..CA-C08 aun no se habian escrito.
--
-- El desempate secundario por lote existe porque el gate es NONATOMIC: cada
-- INSERT es su propia transaccion y dos criterios de la misma llamada pueden
-- quedar con marcas de tiempo distintas por milisegundos.
--
-- WITH NO SCHEMA BINDING: consistente con el resto de las vistas del proyecto,
-- de modo que el orden de despliegue no la rompa.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW bdm_datos.v_cert_ultimo AS
SELECT criterio, estado, detalle, lote, modo, fecha_hora
FROM ( SELECT criterio, estado, detalle, lote, modo, fecha_hora,
              ROW_NUMBER() OVER (PARTITION BY criterio
                                 ORDER BY fecha_hora DESC, lote DESC) AS rn
         FROM bdm_datos.cert_resultado ) u
WHERE rn = 1
WITH NO SCHEMA BINDING;

TRUNCATE TABLE bdm_datos.cert_criterio;

INSERT INTO bdm_datos.cert_criterio
  (criterio, bloque, prioridad, verificable, enunciado, evidencia)
SELECT * FROM (
  -- ---------- REGLA 1: Tipo de Uso + CIIU ----------
  SELECT 'R1-01' AS criterio, 'REGLA1' AS bloque, 'Alta' AS prioridad, 'CONSULTA' AS verificable,
         'CIIU 10 (asalariado): el padre es la direccion LAB o CRR con mayor numero de entidades reportantes.' AS enunciado,
         'unificacion_direccion_mock + arquetipos ARQ 1..5; SP sp_unificacion_r1_esc1' AS evidencia UNION ALL
  SELECT 'R1-02','REGLA1','Alta','CONSULTA',
         'CIIU 81, 82 o 90 (sin actividad): el padre es la direccion RES o CRR con mayor numero de entidades reportantes.',
         'ARQ 6..10 (CIIU 81) y los arquetipos de CIIU 82 y 90; SP sp_unificacion_r1_esc2' UNION ALL
  SELECT 'R1-03','REGLA1','Alta','CONSULTA',
         'CIIU distinto de 10, 81, 82 y 90: gana la direccion con mayor numero de entidades reportantes, sin preferencia de tipo.',
         'ARQ 11..15 (CIIU 47); SP sp_unificacion_r1_esc3' UNION ALL
  SELECT 'R1-04','REGLA1','Alta','CONSULTA',
         'La direccion que pierde la comparacion queda marcada como hija (ind_unificacion = 1).',
         'v_mock_relacion_persona_ubicacion.ind_unificacion derivado de unificacion_direccion_mock' UNION ALL
  SELECT 'R1-05','REGLA1','Alta','CONSULTA',
         'El par padre-hijo queda insertado en unificacion_direccion para trazabilidad.',
         'unificacion_direccion_mock WHERE unifica_atributos = 1' UNION ALL
  SELECT 'R1-06','REGLA1','Alta','CONSULTA',
         'Las direcciones bloqueadas y las que ya son hijas de unificaciones previas no se procesan en esta regla.',
         'filtro ind_unificacion IS NULL AND bloqueado = 0 en sp_unificacion_r1_preparar_insumo' UNION ALL
  SELECT 'R1-07','REGLA1','Alta','CONSULTA',
         'Baseline de CIIU obligatorio: 10 es asalariado; 81, 82 y 90 son sin actividad. No se usan los valores 1-9 ni solo 81 de forma aislada.',
         'literales IN (''81'',''82'',''90'') y NOT IN (''10'',''81'',''82'',''90'') en los SP de R1' UNION ALL
  SELECT 'R1-08','REGLA1','Alta','CONSULTA',
         'Ante empate persistente (mismas entidades, misma fecha) no se toma decision de unificacion: ambas direcciones quedan vigentes.',
         'HAVING COUNT(*) = 1 sobre max_score; arquetipo de empate puro' UNION ALL

  -- ---------- REGLA 2: Complementos ----------
  SELECT 'R2-01','REGLA2','Alta','CONSULTA',
         'Escenario 1 (vacio vs informado): el padre es la direccion con complemento informado.',
         'censo n_id = H1; legado PRO_UnificacionR2.sql linea 201' UNION ALL
  SELECT 'R2-02','REGLA2','Alta','CONSULTA',
         'Escenario 2 (uno incluido en otro): el padre es la direccion con el complemento mas completo.',
         'censo n_id = K2; legado linea 388' UNION ALL
  SELECT 'R2-03','REGLA2','Alta','CONSULTA',
         'Escenario 3 sin NIT (misma nomenclatura, distinto valor): el padre es la direccion con mayor numero de entidades reportantes.',
         'censo n_id = L3; legado linea 1729' UNION ALL
  SELECT 'R2-04','REGLA2','Alta','CONSULTA',
         'Escenario 3 con NIT (persona juridica, misma nomenclatura con distinto valor): se genera una direccion nueva combinando ambos valores.',
         'censo n_id = X4; direccion_fisica_generada_mock; legado linea 1705' UNION ALL
  SELECT 'R2-05','REGLA2','Alta','CONSULTA',
         'Escenario 4 (nomenclaturas distintas, mismo nivel): se consulta el Diccionario de Frecuencias y gana la nomenclatura mas reportada historicamente.',
         'censo n_id = B5; diccionario_complementos; legado linea 2226' UNION ALL
  SELECT 'R2-06','REGLA2','Alta','CONSULTA',
         'Escenario 5 (nomenclaturas distintas, distinto nivel): se genera una direccion nueva que combina ambas y las dos originales quedan como hijas.',
         'censo n_id = A6; legado escenario 5 subcaso 1, lineas 2250-3607' UNION ALL
  SELECT 'R2-07','REGLA2','Alta','CONSULTA',
         'Escenario 6 (ninguna contenida en la otra): se evalua por nivel y frecuencia; segun el subcaso se genera direccion nueva o se usa el diccionario.',
         'censo n_id = A8 (sub1), D9 (sub2), F1 (sub3); legado lineas 4016-5847' UNION ALL
  SELECT 'R2-08','REGLA2','Alta','CONSULTA',
         'Las direcciones nuevas generadas por combinacion quedan marcadas como generadas.',
         'direccion_fisica_generada_mock.generada_enriquecida = 1' UNION ALL
  SELECT 'R2-09','REGLA2','Alta','CONSULTA',
         'Las direcciones generadas tienen registrada su relacion persona-ubicacion.',
         'rpu_generada_mock' UNION ALL
  SELECT 'R2-10','REGLA2','Alta','CONSULTA',
         'Un padre nunca queda marcado como hijo dentro de la misma regla.',
         'interseccion entre cod_dw_persona_ubic y cod_dw_direccion_unificada en unificacion_direccion_mock' UNION ALL
  SELECT 'R2-11','REGLA2','Alta','CONSULTA',
         'Cada direccion hija tiene exactamente un padre asignado.',
         'unificacion_direccion_mock agrupado por cod_dw_persona_ubic HAVING COUNT(DISTINCT padre) > 1' UNION ALL
  SELECT 'R2-12','REGLA2','Alta','CONSULTA',
         'La correccion de complementos garantiza: sin duplicidad, con completitud y con orden logico de los componentes.',
         'direccion_fisica_generada_mock.complemento de los arquetipos del motor' UNION ALL
  SELECT 'R2-13','REGLA2','Alta','CONSULTA',
         'El Diccionario de Frecuencias se construye con frecuencia historica de nomenclaturas reportadas.',
         'bdm_stage.diccionario_complementos; SP sp_unificacion_r2_construir_diccionario_complementos' UNION ALL
  SELECT 'R2-14','REGLA2','Alta','CONSULTA',
         'Ante empate persistente no se toma decision de unificacion.',
         'arquetipos de empate por escenario; censo bucket SIN_RESOLVER' UNION ALL

  -- ---------- REGLA 3: Geolocalizacion ----------
  SELECT 'R3-01','REGLA3','Alta','CONSULTA',
         'La regla aplica exclusivamente a direcciones de tipo Via. Se excluyen Manzana y Rural.',
         'v_xpm_ubicacion_estandarizada.tipo_ubicacion; insumo de sp_unificacion_r3_esc1' UNION ALL
  SELECT 'R3-02','REGLA3','Alta','CONSULTA',
         'Si solo una de las direcciones tiene coordenadas, el padre es la direccion geolocalizada.',
         'geo_atributos.latitud/longitud; insumo de R3' UNION ALL
  SELECT 'R3-03','REGLA3','Alta','CONSULTA',
         'Si ninguna direccion tiene coordenadas, gana la de fecha mas reciente; ante empate, la de mayor numero de entidades reportantes.',
         'fecha_relacion_persona_ubicaci y numero_entidades_reportan en el insumo de R3' UNION ALL
  SELECT 'R3-04','REGLA3','Alta','CONSULTA',
         'Si ambas direcciones tienen coordenadas, se consulta el Diccionario de Via por frecuencia y gana la mas reportada.',
         'Diccionario de Via' UNION ALL
  SELECT 'R3-05','REGLA3','Alta','CONSULTA',
         'Para diferencia en numero de puerta se valida un umbral de mas/menos 2 posiciones.',
         'v_xpm_direccion_fisica.numero_puerta' UNION ALL
  SELECT 'R3-06','REGLA3','Alta','CONSULTA',
         'Si la diferencia en numero de puerta es mayor a 2 no se unifica: se consideran direcciones diferentes.',
         'ausencia de par en unificacion_direccion_mock para el arquetipo de puerta lejana' UNION ALL
  SELECT 'R3-07','REGLA3','Alta','CONSULTA',
         'Las direcciones con modificadores de via (B, C, F, BIS) se excluyen de esta regla.',
         'v_xpm_direccion_fisica.via_principal / via_generadora' UNION ALL
  SELECT 'R3-08','REGLA3','Alta','CONSULTA',
         'Los cuadrantes (N, S, E, O) se omiten para la comparacion numerica pero no excluyen a la direccion de participar en la regla.',
         'v_xpm_direccion_fisica.via_principal; arquetipo con cuadrante' UNION ALL
  SELECT 'R3-09','REGLA3','Alta','CONSULTA',
         'El umbral de mas/menos 2 aplica SOLO en el subcaso donde ambas direcciones tienen coordenadas.',
         'ramas del insumo de R3 por disponibilidad de coordenadas' UNION ALL
  SELECT 'R3-10','REGLA3','Alta','CONSULTA',
         'Ante empate en el diccionario no se toma decision de unificacion.',
         'Diccionario de Via; arquetipo de empate de frecuencia de via' UNION ALL

  -- ---------- GENERALES: comportamiento transversal ----------
  SELECT 'G-01','GENERAL','Alta','CONSULTA',
         'Las reglas se ejecutan en cascada estricta R1 -> R2 -> R3. El resultado de una alimenta la siguiente.',
         'unif_control_etapa_mock ordenado por fecha_hora_inicio' UNION ALL
  SELECT 'G-02','GENERAL','Alta','CONSULTA',
         'Una direccion seleccionada como padre en R1 puede ser evaluada como hija en R2 si otra tiene complemento mas completo.',
         'cruce de unificacion_direccion_mock entre unifica_atributos 1 y 2; ARQ 60 (banda 9600000..9600999)' UNION ALL
  SELECT 'G-03','GENERAL','Alta','CONSULTA',
         'Una direccion marcada como hija en cualquier regla no vuelve a procesarse en reglas posteriores.',
         'filtro ind_unificacion en los insumos de R2 y R3' UNION ALL
  SELECT 'G-04','GENERAL','Alta','CONSULTA',
         'Las direcciones marcadas como bloqueadas (reclamacion del titular) se excluyen de todo el proceso de unificacion.',
         'bloqueado = 1 en el seed mock; ausencia del par en unificacion_direccion_mock' UNION ALL
  SELECT 'G-05','GENERAL','Alta','CONSULTA',
         'Toda unificacion genera registro de trazabilidad: padre, hijo, regla aplicada y fecha de ejecucion.',
         'unificacion_direccion_mock: cod_dw_direccion_unificada, cod_dw_persona_ubic, unifica_atributos, fecha_unificacion, lote' UNION ALL
  SELECT 'G-06','GENERAL','Alta','CONSULTA',
         'El proceso es idempotente: dos ejecuciones consecutivas con los mismos datos producen el mismo resultado sin unificaciones adicionales.',
         'mock_unif_convergencia: checksums de FULL / DELTA1 / DELTA2 / FULL2' UNION ALL
  SELECT 'G-07','GENERAL','Alta','CONSULTA',
         'El sistema nunca compara direcciones de personas diferentes. Toda evaluacion es intra-persona.',
         'unificacion_direccion_mock cruzado con la persona de padre e hija' UNION ALL
  SELECT 'G-08','GENERAL','Alta','CONSULTA',
         'La unificacion es logica: no se eliminan datos. Solo se marcan estados y se registran relaciones padre-hijo.',
         'toda hija y todo padre siguen existiendo en relacion_persona_ubicacion o rpu_generada tras la corrida' UNION ALL
  SELECT 'G-09','GENERAL','Alta','CONSULTA',
         'Las direcciones marcadas como hijas nunca pasan al proceso de Ordenamiento.',
         'insumo de Ordenamiento: COALESCE(ind_unificacion,0) <> 1' UNION ALL
  SELECT 'G-10','GENERAL','Alta','CONSULTA',
         'Las direcciones vigentes (padres y no procesadas) siempre pasan al proceso de Ordenamiento.',
         'conteo del insumo de Ordenamiento contra el universo vigente' UNION ALL

  -- ---------- GOBERNANZA DE MIGRACION ----------
  SELECT 'GOB-01','GOBERNANZA','Alta','CONSULTA',
         'Toda diferencia entre resultados Teradata y Redshift se clasifica en: error de migracion, diferencia de datos, cambio funcional aprobado, o no clasificada.',
         'bitacora de diferencias; requiere el extracto de resultados de Teradata' UNION ALL
  SELECT 'GOB-02','GOBERNANZA','Alta','CONSULTA',
         'Las diferencias clasificadas como no clasificada no pueden aceptarse para paso a produccion.',
         'bitacora de diferencias' UNION ALL
  SELECT 'GOB-03','GOBERNANZA','Alta','EXTERNO',
         'Cualquier evolucion funcional respecto a Teradata requiere aprobacion formal del area de negocio.',
         'acta de aprobacion del area de negocio; fuera del alcance de este desarrollo' UNION ALL
  SELECT 'GOB-04','GOBERNANZA','Alta','CONSULTA',
         'Se mantiene bitacora de diferencias con: ID, regla afectada, caso, resultado Teradata, resultado Redshift, clasificacion, impacto, responsable, decision y aprobador.',
         'bitacora de diferencias' UNION ALL

  -- ---------- GEO (Regla 3): guia de QA ----------
  SELECT 'CA-01','GEO','Alta','CONSULTA',
         'Exportar: se crea un Lote nuevo en geo_lote_control en estado exportado y cada candidato queda en geo_atributos con estado_geo pendiente de geocodificacion y el lote asignado.',
         'geo_lote_control y geo_atributos del ultimo lote' UNION ALL
  SELECT 'CA-02','GEO','Alta','CONSULTA',
         'Cargar Status M: la ubicacion queda estado_geo geocodificada, status_match M y con latitud y longitud pobladas.',
         'geo_atributos WHERE cod_dw_ubic = <U> AND lote = <L>' UNION ALL
  SELECT 'CA-03','GEO','Alta','CONSULTA',
         'Cargar OK: el Lote queda en estado cargado, con fase_fallo y ultimo_error en NULL.',
         'geo_lote_control WHERE lote = <L>' UNION ALL
  SELECT 'CA-04','GEO','Alta','CONSULTA',
         'Reenganche con coordenadas: se invoca la Regla 3, se insertan unificaciones tipo 3 y el Lote mantiene estado cargado.',
         'unificacion_direccion WHERE unifica_atributos = 3; geo_lote_control.estado' UNION ALL
  SELECT 'CA-05','GEO','Alta','CONSULTA',
         'Reenganche sin coordenadas: la Regla 3 se omite como estado esperado, el SP termina OK y no se agregan unificaciones tipo 3 para ese Lote.',
         'el SP no lanza excepcion; conteo de unificaciones tipo 3 del Lote sin cambio'
) c;
