-- ============================================================
-- 33_ddl_cert_criterios_nov.sql
-- SLCOPRBA-1355: tablero de certificacion de NOVEDADES (legado P0035).
-- Gemelo de 13_ddl_cert_criterios.sql (Unificacion) y
-- 20_ddl_cert_criterios_ord.sql (Ordenamiento).
-- (repo strct / db_rcncr_btch_rdshft_strct)
-- UTF-8 sin BOM. Sin acentos a proposito.
--
-- LA FUENTE DE ESTE CATALOGO ES EL CODIGO, NO UN DOCUMENTO, Y HAY QUE DECIRLO.
--   Unificacion y Ordenamiento tienen cada uno su documento de requerimientos
--   y sus criterios salen 1:1 de ahi. Novedades NO tiene documento: lo unico
--   que hay es el legado (Novedad.sql, los cuatro scripts de malla) y un
--   mapeo de migracion. Los criterios de abajo se derivan del codigo, que es
--   la regla 4 del proyecto, y cada uno cita la linea de la que sale.
--   Si aparece un documento funcional, este catalogo se revisa contra el.
--
-- ALCANCE DE ESTA ENTREGA: los dominios UBICACION, ACTIVIDAD ECONOMICA y
--   UBICACION AGREGADA. Los otros CINCO quedan como NO_IMPLEMENTADO --
--   visibles, no ausentes. NOV-HIS-01 y NOV-AGR-01 estaban entre ellos y se
--   retiraron segun se portaba su dominio: una fila que afirma que algo
--   falta envejece peor que el codigo.
--   UBICACION AGREGADA entra con siete de sus ocho criterios en BLOQUEADO:
--   el dominio emite cero filas hasta que llegue V_Hom_Tip_Ident_Linea, y
--   el motivo esta escrito entero sobre el bloque.
--   'mosaic' no figura: fuera de alcance por decision legal.
--
-- ESTADOS que usa el gate (bdm_datos.cert_resultado_nov.estado): los mismos
--   del tablero de Ordenamiento (PASSED, FAILED, NO_IMPLEMENTADO, SIN_DATO,
--   BLOQUEADO, REVISION_MANUAL, FUERA_DE_ALCANCE, NO_APLICA, y SIN_EVALUAR
--   que lo produce el COALESCE del tablero cuando el gate no escribio fila).
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;

-- ------------------------------------------------------------
-- Catalogo de criterios. Contenido fijo, propiedad de este archivo: se
-- reemplaza completo en cada despliegue. TRUNCATE y no DELETE: no hay
-- predicado que seleccione "las filas viejas" y un DELETE sin WHERE viola
-- [REDSHIFT:232].
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bdm_datos.cert_criterio_nov (
  criterio     VARCHAR(12)  NOT NULL,   -- NOV-UB-01 .. NOV-AE-10 .. NOV-G-03
  bloque       VARCHAR(24)  NOT NULL,   -- UBICACION | ACTIVIDAD_ECONOMICA | UBICACION_AGREGADA | OTROS_DOMINIOS | GOBERNANZA
  prioridad    VARCHAR(12)  NOT NULL,
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
CREATE TABLE IF NOT EXISTS bdm_datos.cert_resultado_nov (
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
-- Se ordena por fecha_hora y se desempata por lote: el numero de lote NO
-- ordena las corridas en el tiempo. El desempate secundario existe porque el
-- gate es NONATOMIC y dos criterios de la misma llamada pueden quedar con
-- marcas de tiempo distintas por milisegundos.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW bdm_datos.v_cert_nov_ultimo AS
SELECT criterio, estado, detalle, lote, modo, fecha_hora
FROM ( SELECT criterio, estado, detalle, lote, modo, fecha_hora,
              ROW_NUMBER() OVER (PARTITION BY criterio
                                 ORDER BY fecha_hora DESC, lote DESC) AS rn
         FROM bdm_datos.cert_resultado_nov ) u
WHERE rn = 1
WITH NO SCHEMA BINDING;

-- ------------------------------------------------------------
-- Siembra del catalogo: 48 filas (41 menos NOV-AGR-01, mas los ocho NOV-AG).
-- El CAST de la primera rama del UNION ALL fija el tipo del nodo, de modo que
-- la primera fila castea las seis columnas y las demas no lo repiten.
-- ------------------------------------------------------------
TRUNCATE TABLE bdm_datos.cert_criterio_nov;

INSERT INTO bdm_datos.cert_criterio_nov
  (criterio, bloque, prioridad, verificable, enunciado, evidencia)
SELECT c.criterio, c.bloque, c.prioridad, c.verificable, c.enunciado, c.evidencia
FROM (
  -- ---------- UBICACION: contrato de salida ----------
  SELECT CAST('NOV-UB-01' AS VARCHAR(12)) AS criterio,
         CAST('UBICACION' AS VARCHAR(24)) AS bloque,
         CAST('Alta' AS VARCHAR(12)) AS prioridad,
         CAST('CONSULTA' AS VARCHAR(16)) AS verificable,
         CAST('La etapa 9 debe exponer las 42 columnas del contrato con sus tipos, porque cinco de los otros procedimientos de Novedades la leen.' AS VARCHAR(700)) AS enunciado,
         CAST('contrato en P0035_Extractor_Novedades_130.TPT:28-71 (SCHEMA P0035_8) menos IN_Severidad; DDL en 30_ddl_novedades.sql' AS VARCHAR(700)) AS evidencia UNION ALL
  SELECT 'NOV-UB-02', 'UBICACION', 'Alta', 'CONSULTA',
         'La etapa 2 debe exponer las 15 columnas del contrato: es la unica entrada de Ubi_Agregada.',
         'contrato en Novedad.sql:8625-8639; DDL en 30_ddl_novedades.sql' UNION ALL
  SELECT 'NOV-UB-03', 'UBICACION', 'Alta', 'CONSULTA',
         'La etapa 9 no debe multiplicar filas por cod_dw_persona_ubic. El legado no lleva QUALIFY ni DISTINCT y tres joins pueden abrir: direccion fisica, direccion electronica y bloqueo.',
         'joins en Novedad.sql:7778, :8172 y :8415; se compara COUNT(*) contra COUNT(DISTINCT id)' UNION ALL
  SELECT 'NOV-UB-04', 'UBICACION', 'Alta', 'CONSULTA',
         'El universo base debe traer solo relaciones sin unificar, no bloqueadas y con orden de prioridad no nulo.',
         'filtro de la etapa 1 en Novedad.sql:7589-7593' UNION ALL
  SELECT 'NOV-UB-05', 'UBICACION', 'Alta', 'CONSULTA',
         'Solo deben entrar los registros cuya gestion es VALIDA: en el legado es un INNER JOIN, no un filtro opcional.',
         'Novedad.sql:7679' UNION ALL
  SELECT 'NOV-UB-06', 'UBICACION', 'Alta', 'CONSULTA',
         'La columna DATO debe traer la direccion compuesta cuando el tipo de ubicacion es Geografica y el texto de ubicacion en cualquier otro caso.',
         'Novedad.sql:8349; la composicion de la direccion se arma en :7772' UNION ALL
  SELECT 'NOV-UB-07', 'UBICACION', 'Alta', 'CONSULTA',
         'La columna CLASE debe tomar CEL, EMAIL, DIR o TEL segun el tipo de ubicacion, y NULL en cualquier otro caso.',
         'las cuatro ramas en Novedad.sql:8367-8372' UNION ALL
  SELECT 'NOV-UB-08', 'UBICACION', 'Media', 'CONSULTA',
         'Las banderas de tipo CRR, RES y LAB deben valer 1 o 0 segun el tipo de ubicacion de direccion; PPL, AGN, SUC, EST y CDI son NULL literal en el legado y se portan asi.',
         'Novedad.sql:8375-8382' UNION ALL
  SELECT 'NOV-UB-09', 'UBICACION', 'Alta', 'CONSULTA',
         'Por esta ruta REPORTADO_DESDE, ULTIMO_REPORTE y FUENTE deben salir NULL y los dos contadores 0: el legado los emite como literales y sus valores reales viven en la etapa 2, que esta ruta no consume. Divergencia funcional elevada, no defecto del port.',
         'Novedad.sql:8358-8363; los valores reales en :8635-8639' UNION ALL
  SELECT 'NOV-UB-10', 'UBICACION', 'Alta', 'CONSULTA',
         'La columna ORDEN debe venir del orden de prioridad que produce el Ordenamiento, sin transformar.',
         'Novedad.sql:8347; en Redshift lo escribe sp_ordenamiento_consolidacion_edf en bdm_datos.rpu_orden_prioridad' UNION ALL

  -- ---------- UBICACION: modo FULL y DELTA ----------
  SELECT 'NOV-UB-11', 'UBICACION', 'Alta', 'CONSULTA',
         'En modo FULL toda fila debe salir marcada como alta.',
         'Novedad.sql:8392, rama V_CARGA_FULL IS NULL' UNION ALL
  SELECT 'NOV-UB-12', 'UBICACION', 'Alta', 'CONSULTA',
         'En modo DELTA una relacion nueva desde el watermark debe salir como alta y una modificada como cambio, y la ventana de FECHA debe aportar al menos una fila.',
         'deltas en Novedad.sql:7394-7401 (altas) y :7455-7462 (cambios)' UNION ALL
  -- CORREGIDO (SLCOPRBA-1355). Decia "una ubicacion bloqueada debe salir
  -- marcada como baja", que es lo que el legado PARECE hacer y no hace: la
  -- etapa 1 anti-une V_BLOQUEO y la etapa 9 vuelve a unirla por la misma
  -- llave, asi que FECHA_BLOQUEO es siempre NULL y 'E' no se emite jamas.
  SELECT 'NOV-UB-13', 'UBICACION', 'Media', 'CONSULTA',
         'La baja por bloqueo es codigo muerto en el legado: ninguna fila debe salir marcada como baja.',
         'Novedad.sql:7590-7594 (anti-join) contra :8393 y :8416 (la rama E)' UNION ALL
  SELECT 'NOV-UB-14', 'UBICACION', 'Alta', 'CONSULTA',
         'La tabla final debe recibir el alta y el cambio por la llave de la fila, sin duplicar.',
         'UPSERT del legado en P0035_Extractor_Novedades_130.TPT:573-703' UNION ALL
  -- CORREGIDO (SLCOPRBA-1355), hermano de NOV-UB-13: Severidad=2 sale solo de
  -- FLAG_OP='E' (120.TPT:163), que es codigo muerto, de modo que el UPSERT
  -- del legado nunca borra. El criterio verifica esa paridad.
  SELECT 'NOV-UB-15', 'UBICACION', 'Alta', 'CONSULTA',
         'El AS-IS solo inserta y actualiza: la tabla final no debe perder filas por una baja que el legado no emite.',
         'P0035_Extractor_Novedades_120.TPT:163 y 130.TPT:703' UNION ALL

  -- ---------- UBICACION: bloqueadas por insumo que no existe ----------
  SELECT 'NOV-UB-16', 'UBICACION', 'Media', 'CONSULTA',
         'La columna TIPO debe traer la descripcion homologada del tipo de ubicacion de direccion.',
         'Novedad.sql:8279; BLOQUEADO: no se entrego el catalogo V_Hom_TipoUbic_Dir_Linea' UNION ALL
  SELECT 'NOV-UB-17', 'UBICACION', 'Media', 'CONSULTA',
         'La columna ZONA debe traer la descripcion homologada de la zona.',
         'Novedad.sql:8278; BLOQUEADO: no se entregaron V_ZONA_UBICACION ni V_Hom_Zona_Linea' UNION ALL
  SELECT 'NOV-UB-18', 'UBICACION', 'Media', 'CONSULTA',
         'La columna de tipo de identificacion debe traer la descripcion homologada.',
         'Novedad.sql:8406; el catalogo V_Hom_Tip_Ident_Linea llego el 2026-10-21 (11 filas, bdm_datos.catalogo_hom_tipo_ident) y la columna ya se puebla' UNION ALL
  SELECT 'NOV-UB-19', 'UBICACION', 'Baja', 'CONSULTA',
         'La columna INDICATIVO debe traer el codigo de area del telefono fijo.',
         'Novedad.sql:7968; BLOQUEADO: no se entrego V_TELEFONO_FIJO' UNION ALL
  SELECT 'NOV-UB-20', 'UBICACION', 'Baja', 'CONSULTA',
         'La columna de tipo de cuenta debe traer el primer caracter del tipo de correo.',
         'Novedad.sql:8170; BLOQUEADO: no se entrego V_TIPO_CORREO' UNION ALL
  SELECT 'NOV-UB-21', 'UBICACION', 'Media', 'CONSULTA',
         'Las columnas de barrio y estrato deben traer el atributo geografico de la ubicacion.',
         'Novedad.sql:8063 y :8066; BLOQUEADO: geo_atributos las declara y nunca las escribe, porque su posicion en el contrato de 32 columnas no esta pinada (sp_geo_cargar_georreferenciacion.sql:443-446)' UNION ALL
  SELECT 'NOV-UB-22', 'UBICACION', 'Media', 'CONSULTA',
         'Las columnas de localidad y codigo postal deben traer el atributo geografico de la ubicacion.',
         'Novedad.sql:8064 y :8065; BLOQUEADO: no existe columna en geo_atributos y las dos vienen del contrato GEO sin pinar' UNION ALL

  -- ---------- Los siete dominios no portados ----------
  SELECT 'NOV-CAT-01', 'OTROS_DOMINIOS', 'Alta', 'CONSULTA',
         'El proceso debe preparar los catalogos de la corrida.',
         'legado PRO_Novedad_Linea_Catalogo (Novedad.sql:3). Dominio no portado a Redshift: el evaluador lo marca NO_IMPLEMENTADO' UNION ALL
  SELECT 'NOV-INB-01', 'OTROS_DOMINIOS', 'Alta', 'CONSULTA',
         'El proceso debe producir la informacion basica de la persona.',
         'legado PRO_Novedad_Linea_Info_Basica (Novedad.sql:2166). PORTADO el 2026-10-21 con 20 de las 22 columnas; no son las doce etapas sino una re-especificacion, porque en EDF las secciones best* ya son el registro mas confiable. El filtro Mosaic no le aplica: Mosaic toca Info_Basica en :2482 y queda fuera por decision legal (D-NOV-07)' UNION ALL
  SELECT 'NOV-CON-01', 'OTROS_DOMINIOS', 'Alta', 'CONSULTA',
         'El proceso debe producir la informacion de contactabilidad.',
         'legado PRO_Novedad_Linea_Contact (Novedad.sql:186). PORTADO el 2026-10-21, pero solo 2 de sus 12 columnas se pueblan y las dos con otra semantica (D-NOV-08): la fuente de gestion no existe ni en el datashare ni en la documentacion de EDF. Un PASSED afirma que el dominio produce, no que produce completo' UNION ALL
  SELECT 'NOV-PIN-01', 'OTROS_DOMINIOS', 'Media', 'CONSULTA',
         'El proceso debe producir los puntos de interes cercanos a cada ubicacion.',
         'legado PRO_Novedad_Linea_Punto_Interes (Novedad.sql:4585). PORTADO el 2026-10-21 con 7 de 10 columnas. La nota anterior era FALSA: el contrato de distancias SI trae el nombre, en col08; era geo_distancias la que no tenia columna, y ya la tiene (D-GEO-08)' UNION ALL
  SELECT 'NOV-MOV-01', 'OTROS_DOMINIOS', 'Media', 'CONSULTA',
         'El proceso debe producir los indicadores de movilidad.',
         'legado PRO_Novedad_Linea_Indic_Movilidad (Novedad.sql:1508). PORTADO el 2026-10-21 con 3 de los 4 indicadores. La nota anterior era FALSA: P0029 SI esta en el repo (4 archivos) y el lado Novedades tambien; lo que faltaba era el productor de MTCalcularIndicadoresMovilidad, construido como nov_movilidad_foto. Falta Cambio de Localidad porque LOCALIDAD no existe en EDF' UNION ALL

  -- ---------- ACTIVIDAD ECONOMICA ----------
  -- Segundo dominio portado. El legado es PRO_Novedad_Linea_Historial
  -- (Novedad.sql:1060-1420), que a pesar del nombre produce
  -- MAT_INFO_ACTIVIDAD_ECONOMICA: la nomenclatura del legado esta cruzada y
  -- manda el 120.TPT, no el nombre. Por eso NOV-HIS-01 desaparecio de
  -- OTROS_DOMINIOS: decia "dominio no portado" y dejo de ser cierto.
  --
  -- Cada criterio cita la linea del legado de la que sale, que es la regla
  -- de este catalogo: no hay documento funcional de Novedades.
  SELECT 'NOV-AE-01', 'ACTIVIDAD_ECONOMICA', 'Alta', 'CONSULTA',
         'La etapa 1 debe exponer las 9 columnas del contrato y la tabla final las 8 del contrato mas las 3 de control, porque el contrato es publico y un CTAS lo cambiaria sin avisar.',
         'contrato en 34_ddl_nov_actividad_economica.sql; origen en P0035_Extractor_Novedades_120.TPT:176-199' UNION ALL
  SELECT 'NOV-AE-02', 'ACTIVIDAD_ECONOMICA', 'Alta', 'CONSULTA',
         'La etapa 1 no debe multiplicar filas por el par (ciiu, info_basica_id): el legado cierra con un QUALIFY ROW_NUMBER sobre ese par.',
         'QUALIFY en Novedad.sql:1379. La via mock lo necesita de verdad: v_mock_ciiu_persona lee bdm_stage.ciiu_persona SIN DISTINCT' UNION ALL
  SELECT 'NOV-AE-03', 'ACTIVIDAD_ECONOMICA', 'Alta', 'CONSULTA',
         'Solo deben entrar personas con CIIU informado: el legado filtra el codigo de actividad no nulo.',
         'filtro en Novedad.sql:1377; insumo v_xpm_ciiu_persona (02_vistas_insumo_edf_views.sql:364-370)' UNION ALL
  SELECT 'NOV-AE-04', 'ACTIVIDAD_ECONOMICA', 'Alta', 'CONSULTA',
         'En modo FULL toda fila debe salir marcada como alta.',
         'gemelo de NOV-UB-11; el modo decide el flag_op en sp_novedades_actividad_economica_edf.sql' UNION ALL
  SELECT 'NOV-AE-05', 'ACTIVIDAD_ECONOMICA', 'Alta', 'CONSULTA',
         'En modo DELTA la ventana debe acotar por FECHA y no solo por la rama de fecha nula: al menos una fila tiene que entrar por fecha.',
         'gemelo de NOV-UB-12, y por el mismo motivo. La ventana es fecha_reporte >= watermark OR fecha IS NULL (sp_novedades_actividad_economica_edf.sql:149-151): un criterio que solo cuenta filas da PASSED sin haber mirado la ventana, que es lo que tumbo el job DEV/DATABASE #409' UNION ALL
  SELECT 'NOV-AE-06', 'ACTIVIDAD_ECONOMICA', 'Media', 'CONSULTA',
         'Las columnas de descripcion de la actividad y de version deben traer el valor del catalogo de CIIU.',
         'el legado las toma de V_ACTIVIDAD_ECONO_CIIU (Novedad.sql:1352-1354), catalogo que NO se entrego. Peticion en docs/PETICION_CATALOGOS_NOVEDADES.md seccion 6' UNION ALL
  SELECT 'NOV-AE-07', 'ACTIVIDAD_ECONOMICA', 'Media', 'CONSULTA',
         'La columna de tipo de identificacion debe traer la descripcion homologada.',
         'mismo catalogo que NOV-UB-18: V_Hom_Tip_Ident_Linea, que llego el 2026-10-21 y ya se consume' UNION ALL
  SELECT 'NOV-AE-08', 'ACTIVIDAD_ECONOMICA', 'Alta', 'CONSULTA',
         'El AS-IS de este dominio solo inserta: ninguna fila debe salir marcada como baja y la tabla final no debe perder filas.',
         'el DELETE del 130.TPT:753 exige Severidad=2 y el CASE de 120.TPT:186-197 no tiene rama que la devuelva: tres ramas dan 1 y el ELSE da -1. Mismo patron que el flag_op=E de Ubicacion' UNION ALL
  SELECT 'NOV-AE-09', 'ACTIVIDAD_ECONOMICA', 'Alta', 'CONSULTA',
         'El id de la tabla final se asigna como el maximo vivo mas la posicion de la fila y no puede repetirse.',
         'Max_ID + SUM(1) OVER (ROWS UNBOUNDED PRECEDING) en 120.TPT:177-179, sobre un CROSS JOIN con COALESCE(MAX(ID),0)' UNION ALL
  SELECT 'NOV-AE-10', 'ACTIVIDAD_ECONOMICA', 'Alta', 'CONSULTA',
         'Toda fila con Severidad 1 debe llegar a la tabla final; las de Severidad -1 no.',
         'filtro Severidad <> -1 en 130.TPT:215; gemelo de NOV-UB-14' UNION ALL

  -- ---------- UBICACION AGREGADA ----------
  -- Tercer dominio portado. El legado es PRO_Novedad_Linea_Ubi_Agregada
  -- (Novedad.sql:5032-7200), 22 etapas. Por eso NOV-AGR-01 desaparecio de
  -- OTROS_DOMINIOS: decia "dominio no portado" y dejo de ser cierto. Misma
  -- correccion que NOV-HIS-01 en la entrega anterior.
  --
  -- SIETE DE LOS OCHO ESTAN BLOQUEADOS POR UN CATALOGO, Y CONVIENE LEER POR
  -- QUE ANTES DE INVESTIGARLO.
  --   tipo_identificacion sale NULL en TODA fila
  --   (sp_novedades_ubicacion_edf.sql:362, "falta V_Hom_Tip_Ident_Linea"), y
  --   la etapa 5 del legado une por igualdad en esa columna
  --   (Novedad.sql:5431). NULL = NULL es falso, de modo que el join vacia la
  --   cadena entera: medido en el banco, las etapas 1 a 4 traen 8.500 filas y
  --   la 5 trae cero.
  --   EL PORT ES FIEL: el legado no pone centinela ahi y la etapa 2 arrastra
  --   la columna cruda (:8624). No hay COALESCE que portar, y meter uno
  --   fundiria filas que el legado no funde -- cambiaria un bloqueo visible
  --   por un defecto silencioso.
  --   Lo que falta es un volcado de dos columnas. El mismo catalogo que ya
  --   bloquea NOV-AE-07 y NOV-UB-18, que ahora bloquea un dominio entero.
  --
  -- NOV-AG-01 SI SE EVALUA, y a proposito: mira el contrato en
  -- information_schema, que no depende de que haya filas. Es el unico que
  -- cazaria una deriva del contrato mientras el resto espera al catalogo.
  SELECT 'NOV-AG-01', 'UBICACION_AGREGADA', 'Alta', 'CONSULTA',
         'La etapa final debe exponer las 30 columnas del contrato y la tabla final las 32, porque las dos son contrato publico y un CTAS dejaria que el tipo lo infiriera la consulta.',
         'contrato en 35_ddl_nov_ubi_agregada.sql; origen en P0035_Extractor_Novedades_130.TPT:1033-1147' UNION ALL
  SELECT 'NOV-AG-02', 'UBICACION_AGREGADA', 'Alta', 'CONSULTA',
         'La tabla final no debe tener dos filas con la misma llave de siete columnas.',
         'la llave del UPSERT es info_basica, tipo_identificacion, numero_identificacion y el trio ubicacion_dato / ubicacion_codigodane / ubicacion_ciudad / ubicacion_departamento (130.TPT:1060-1066). Las etapas 5, 6 y 7 del legado unen SIN info_basica (Novedad.sql:5431-5436): si el par (tipo, numero) no la determina, la salida se multiplica y nada falla' UNION ALL
  SELECT 'NOV-AG-03', 'UBICACION_AGREGADA', 'Alta', 'CONSULTA',
         'Las tres columnas agregadas por concatenacion deben traer la lista completa y ordenada, no un solo valor.',
         'el legado las arma con tres WITH RECURSIVE (Novedad.sql:5700-6100); nuestro port usa LISTAGG con WITHIN GROUP, que es el idioma de Redshift para lo mismo' UNION ALL
  SELECT 'NOV-AG-04', 'UBICACION_AGREGADA', 'Alta', 'CONSULTA',
         'El orden de la ubicacion debe numerarse por persona y clase, sin huecos ni empates.',
         'ROW_NUMBER sobre PARTITION BY info_basica, ubicacion_clase en sp_novedades_ubi_agregada_edf.sql; el desempate final por MD5(ubicacion_dato) existe para que el numero sea estable entre corridas' UNION ALL
  SELECT 'NOV-AG-05', 'UBICACION_AGREGADA', 'Alta', 'CONSULTA',
         'Las cinco columnas de reporte deben venir pobladas, al reves que en el dominio UBICACION.',
         'reportdesde, ultreporte, numentidades, numreportes y fuente. En UBICACION salen NULL y 0 literales (Novedad.sql:8358-8363) porque esa ruta no consume la etapa 2; esta SI la consume, de modo que aqui un NULL es un defecto y alli no. Es el contraste que NOV-UB-09 vigila del otro lado' UNION ALL
  SELECT 'NOV-AG-06', 'UBICACION_AGREGADA', 'Alta', 'CONSULTA',
         'Ninguna fila debe salir marcada como baja y la tabla final no debe perder filas.',
         'la Severidad compara 19 columnas con tres centinelas (120.TPT:406-442) y solo devuelve 1 o -1: ninguna rama da 2, de modo que el DELETE del 130.TPT:1135-1147 es inalcanzable. Tercera vez que el borrado es codigo muerto en este proceso, tras NOV-UB-13 y NOV-AE-08' UNION ALL
  SELECT 'NOV-AG-07', 'UBICACION_AGREGADA', 'Alta', 'CONSULTA',
         'Una segunda corrida sobre los mismos datos no debe hacer crecer la tabla final.',
         'este dominio es el unico de los tres cuyo UPSERT ACTUALIZA (130.TPT:1036-1059, UPDATE mas INSERT FOR MISSING). Nuestro DELETE de las llaves que vuelven a entrar mas INSERT es equivalente porque el UPDATE pisa todas las columnas que no son llave' UNION ALL
  SELECT 'NOV-AG-08', 'UBICACION_AGREGADA', 'Media', 'CONSULTA',
         'El codigo de pais debe seguir en blanco mientras no exista su catalogo.',
         'el CROSS JOIN contra V_PAIS (Novedad.sql:7175-7178) no se porta: contra una vista inexistente dejaria la etapa vacia. Gemelo de NOV-UB-09: el criterio verifica que SIGA en blanco, no que se llene' UNION ALL

  -- ---------- Gobernanza ----------
  SELECT 'NOV-G-01', 'GOBERNANZA', 'Alta', 'CONSULTA',
         'El procedimiento real y su espejo mock deben diferir unicamente en las fuentes que leen.',
         'diff entre sp_novedades_ubicacion_edf.sql y sp_novedades_ubicacion_mock.sql' UNION ALL
  SELECT 'NOV-G-02', 'GOBERNANZA', 'Alta', 'MANUAL',
         'El control de lote y watermark de Novedades es diseno propio, no un port: el del legado esta inoperativo porque la corrida borra su propio log al arrancar y el cierre de lote nunca se ejecuta.',
         'P0035_Extractor_Novedades_111.BTQ:64-65 borra el log; _140.BTQ:47-61 declara el cierre y :853-858 no lo llama. Diseno propio en 31_ddl_nov_control.sql' UNION ALL
  SELECT 'NOV-G-03', 'GOBERNANZA', 'Media', 'MANUAL',
         'Hay que decidir el equivalente en Redshift del patron de recarga del legado, que clona las tablas finales, apunta las vistas al clon, vacia las originales y las repone al terminar.',
         'P0035_Extractor_Novedades_111.BTQ:474-844 y _140.BTQ:108-410 y :804-851. Decision de arquitectura, no de codigo'
) c;
