-- ============================================================
-- 00_rollback (prerequisitos): es la ULTIMA entrada de rollback.par, de modo
-- que cuando corre ya no queda ningun objeto nuestro en pie.
--
-- bdm_datos y bdm_tempo NO se borran. Alojan los SP de pgm y un
-- DROP SCHEMA ... CASCADE los arrasa: incidente strct #256, que dejo a dt
-- cayendo con 42883. CREATE SCHEMA IF NOT EXISTS en el DPLY es suficiente.
--
-- bdm_stage SI, Y SIN CASCADE. Es nuestro y solo tiene semillas mock; el
-- DPLY lo crea y hasta ahora nadie lo borraba, de modo que en un ambiente
-- limpio sobrevivia al rollback y rompia la comparacion DDL_1 vs DDL_3 del
-- pipeline (job QA/DATABASE #122, [REDSHIFT:335]).
--
-- SIN CASCADE ES LA PARTE QUE IMPORTA, y es lo que lo separa del #256: si
-- alguien dejo un objeto dentro, la sentencia FALLA en vez de arrasar con el.
-- Esa es exactamente la propiedad que se quiere de un rollback.
-- UTF-8 sin BOM, sin acentos.
-- ============================================================

DROP SCHEMA IF EXISTS bdm_stage;

SELECT 1;
