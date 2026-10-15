-- ============================================================
-- 23_ddl_catalogo_portafolio_ord.sql
-- SLCOPRBA-1355. El clasificador Portafolio_Nuevo del Ordenamiento.
-- UTF-8 sin BOM. ASCII sin acentos a proposito.
--
-- ORIGEN: PRO_ORD_CTA_TOTALES_PERSONAS_2.sql:378-389 (identico en
-- Prc_Ordenamiento2.sql:3586-3597). Son ONCE ramas y DIEZ dependen solo del
-- prefijo de dos digitos del cod_suscriptor; la undecima, 'CO', necesita
-- ademas el tipo de cuenta y las banderas de comportamiento (:316-318).
--
-- Se persisten las dos cosas que el legado tiene escritas como DATO:
--   1) el mapa de prefijos (abajo, 10 ramas mas el ELSE 'OT')
--   2) la lista de 66 codigos de SEIS digitos reclasificados a 'VE', que en
--      el legado va a mano dentro del CASE
-- El Sector NO lleva catalogo: es un colapso de cinco vias sobre
-- Portafolio_Nuevo (:391-396) y se escribe como CASE en el insumo.
--
-- LA RAMA 'CO' NO SE CONSTRUYE, Y NO ES UN OLVIDO.
--   Exige Flag_Comp_Cta_Activo = 'Y', Flag_Comp_Cta_Pasivo <> 'Y' y
--   Cod_Tipo_Rel_Con_Cta_Fte = 'C', que salen de las tablas de
--   comportamiento de cuenta de la Fase 2, sin portar. Sin ella una cuenta
--   que deberia ser 'CO' cae a la rama de su prefijo.
--   NO afecta a DIR001IN (prefijo 05) ni a DIR004RO (02/03). SI puede
--   contaminar DIR010FI y DIR013OT en produccion; en el mock no, porque la
--   siembra la controlamos.
--
-- EL ORDEN DE LAS RAMAS ES PARTE DE LA DEFINICION, NO UN DETALLE.
--   El CASE del legado evalua en este orden:
--     CO, RO, IN, VE, HP, FR, CC, CP, RC, RS, CT, ELSE OT
--   y 'VE' va en CUARTO lugar, despues de RO y de IN pero ANTES de HP, FR,
--   CC, CP, RC, RS y CT. Dos consecuencias que hay que reproducir:
--     - los codigos VE con prefijo 04, 18, 20 y 45 SI ganan a su prefijo,
--       porque RC, RS y FR vienen despues;
--     - el codigo 050058, que esta en la lista VE del legado, NUNCA LA
--       ALCANZA: el prefijo 05 dispara 'IN' en la rama anterior. Es un
--       condicional muerto del legado y se porta tal cual, de modo que
--       050058 clasifica 'IN'. Queda escrito para que nadie lo "arregle".
--   Quien consulte estos catalogos mira primero RO e IN por prefijo, luego
--   la lista VE, y solo despues el resto de prefijos.
--
-- TRAMPA DE PORTABILIDAD, pagada una vez ya.
--   En el legado TODOS los literales del CASE son numericos sin comillas
--   --IN (02,03), IN (040003, ...)-- mientras cod_suscriptor es caracter, de
--   modo que Teradata coacciona a numero y los ceros a la izquierda dan
--   igual. Aqui el catalogo guarda el prefijo como texto de DOS caracteres y
--   el codigo VE como texto de SEIS, y quien consulte debe normalizar con
--   LPAD por el lado del hecho. Comparar texto sin normalizar da otro
--   resultado. En todo src/teradata/ no hay un solo LPAD.
-- ============================================================

CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_portafolio_prefijo (
  prefijo    VARCHAR(2),
  portafolio VARCHAR(2)
)
DISTSTYLE ALL;   -- 50 filas: replicarlo cuesta menos que redistribuirlo

TRUNCATE TABLE bdm_datos.catalogo_portafolio_prefijo;

-- El CAST de la primera rama fija el tipo del nodo UNION ALL.
INSERT INTO bdm_datos.catalogo_portafolio_prefijo (prefijo, portafolio)
  SELECT CAST('02' AS VARCHAR(2)), CAST('RO' AS VARCHAR(2)) UNION ALL
  SELECT '03','RO' UNION ALL
  SELECT '05','IN' UNION ALL
  SELECT '13','HP' UNION ALL
  SELECT '07','FR' UNION ALL SELECT '14','FR' UNION ALL SELECT '17','FR' UNION ALL
  SELECT '18','FR' UNION ALL SELECT '20','FR' UNION ALL SELECT '48','FR' UNION ALL
  SELECT '49','FR' UNION ALL
  SELECT '23','CC' UNION ALL SELECT '24','CC' UNION ALL
  SELECT '06','CP' UNION ALL SELECT '27','CP' UNION ALL
  SELECT '04','RC' UNION ALL SELECT '09','RC' UNION ALL SELECT '10','RC' UNION ALL
  SELECT '11','RC' UNION ALL SELECT '19','RC' UNION ALL SELECT '22','RC' UNION ALL
  SELECT '28','RC' UNION ALL SELECT '32','RC' UNION ALL SELECT '34','RC' UNION ALL
  SELECT '35','RC' UNION ALL SELECT '37','RC' UNION ALL SELECT '39','RC' UNION ALL
  SELECT '45','RC' UNION ALL SELECT '47','RC' UNION ALL
  SELECT '08','RS' UNION ALL SELECT '12','RS' UNION ALL SELECT '15','RS' UNION ALL
  SELECT '16','RS' UNION ALL SELECT '21','RS' UNION ALL SELECT '25','RS' UNION ALL
  SELECT '26','RS' UNION ALL SELECT '29','RS' UNION ALL SELECT '30','RS' UNION ALL
  SELECT '31','RS' UNION ALL SELECT '33','RS' UNION ALL SELECT '36','RS' UNION ALL
  SELECT '38','RS' UNION ALL SELECT '40','RS' UNION ALL SELECT '41','RS' UNION ALL
  SELECT '42','RS' UNION ALL SELECT '43','RS' UNION ALL SELECT '44','RS' UNION ALL
  SELECT '46','RS' UNION ALL
  SELECT '51','CT' UNION ALL SELECT '01','CT';

-- Los 66 codigos que el legado reclasifica a 'VE' por encima de su prefijo.
-- Es dato escrito a mano en el CASE, no logica: por eso va a catalogo.
CREATE TABLE IF NOT EXISTS bdm_datos.catalogo_portafolio_ve (
  cod_suscriptor VARCHAR(20)
)
DISTSTYLE ALL;   -- 66 filas

TRUNCATE TABLE bdm_datos.catalogo_portafolio_ve;

INSERT INTO bdm_datos.catalogo_portafolio_ve (cod_suscriptor)
  SELECT CAST('040003' AS VARCHAR(20)) UNION ALL
  SELECT '040022' UNION ALL
  SELECT '040039' UNION ALL
  SELECT '040076' UNION ALL
  SELECT '040099' UNION ALL
  SELECT '040125' UNION ALL
  SELECT '040127' UNION ALL
  SELECT '040129' UNION ALL
  SELECT '040131' UNION ALL
  SELECT '040142' UNION ALL
  SELECT '040188' UNION ALL
  SELECT '040189' UNION ALL
  SELECT '040190' UNION ALL
  SELECT '040195' UNION ALL
  SELECT '040199' UNION ALL
  SELECT '040218' UNION ALL
  SELECT '040249' UNION ALL
  SELECT '040290' UNION ALL
  SELECT '040301' UNION ALL
  SELECT '040368' UNION ALL
  SELECT '040390' UNION ALL
  SELECT '040468' UNION ALL
  SELECT '040507' UNION ALL
  SELECT '040657' UNION ALL
  SELECT '040803' UNION ALL
  SELECT '040895' UNION ALL
  SELECT '040909' UNION ALL
  SELECT '040980' UNION ALL
  SELECT '041153' UNION ALL
  SELECT '041336' UNION ALL
  SELECT '041409' UNION ALL
  SELECT '041901' UNION ALL
  SELECT '042027' UNION ALL
  SELECT '042627' UNION ALL
  SELECT '043410' UNION ALL
  SELECT '050058' UNION ALL
  SELECT '180007' UNION ALL
  SELECT '180015' UNION ALL
  SELECT '180110' UNION ALL
  SELECT '180114' UNION ALL
  SELECT '180151' UNION ALL
  SELECT '180185' UNION ALL
  SELECT '189905' UNION ALL
  SELECT '200059' UNION ALL
  SELECT '450028' UNION ALL
  SELECT '450030' UNION ALL
  SELECT '450031' UNION ALL
  SELECT '450032' UNION ALL
  SELECT '450033' UNION ALL
  SELECT '450034' UNION ALL
  SELECT '450035' UNION ALL
  SELECT '450036' UNION ALL
  SELECT '450039' UNION ALL
  SELECT '450041' UNION ALL
  SELECT '450042' UNION ALL
  SELECT '450043' UNION ALL
  SELECT '450044' UNION ALL
  SELECT '450045' UNION ALL
  SELECT '450048' UNION ALL
  SELECT '450049' UNION ALL
  SELECT '450050' UNION ALL
  SELECT '450051' UNION ALL
  SELECT '450052' UNION ALL
  SELECT '450053' UNION ALL
  SELECT '450074' UNION ALL
  SELECT '450112';
