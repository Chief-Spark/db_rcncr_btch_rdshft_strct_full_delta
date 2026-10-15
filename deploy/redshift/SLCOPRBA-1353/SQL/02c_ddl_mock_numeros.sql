-- ============================================================
-- 02c_ddl_mock_numeros.sql
-- Tabla auxiliar de numeros para la generacion de semillas mock.
-- Objeto permanente en bdm_stage. Codificacion: UTF-8 sin BOM.
-- Nunca GRANT ... TO PUBLIC.
-- Spec: unificacion-full-delta -- certificacion con datos mock
-- ------------------------------------------------------------
-- SLCOPRBA-1354: soporte para generar un volumen mock amplio (objetivo
-- 50.000-100.000 personas) SIN escribir los INSERT uno por uno.
--
-- POR QUE ESTA TABLA Y NO generate_series:
--   En Redshift generate_series es una funcion LEADER-NODE ONLY. En cuanto se
--   combina con tablas de usuario (que viven en los nodos de computo) la
--   consulta aborta. No sirve para poblar tablas, que es justo lo que
--   necesitamos. El patron soportado es materializar los numeros con un
--   producto cartesiano de digitos, que se ejecuta en los nodos de computo.
--
-- POR QUE NO INSERTS LITERALES:
--   Un .sql con ~130.000 INSERT ... VALUES pesa decenas de MB; el pipeline lo
--   ejecuta con rsql y es candidato directo a timeout. Con esta tabla, cada
--   arquetipo de prueba se siembra con un unico INSERT ... SELECT que cruza la
--   plantilla del caso contra mock_numeros, y el archivo de semillas queda en
--   unos cientos de lineas.
--
-- DETERMINISMO: sin RANDOM(). Los identificadores, fechas y textos de las
-- semillas se derivan de 'i', de modo que dos ejecuciones producen exactamente
-- los mismos datos. Es condicion para que la evidencia de QA sea reproducible.
--
-- RANGO: 0..9999 (10.000 valores). Con 55 arquetipos
-- (11 escenarios x 5 posiciones respecto al Watermark) alcanza para
--   N = 1.000 replicas ->  55.000 personas
--   N = 2.000 replicas -> 110.000 personas
-- Ampliar el rango solo requiere anadir un quinto digito al producto.
--
-- DISTSTYLE ALL: 10.000 filas, se replica en cada nodo para que el cruce con
-- las plantillas no genere redistribucion.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_stage;

-- DROP + CREATE en lugar de CREATE IF NOT EXISTS + INSERT condicional:
-- la tabla es un auxiliar puro y reconstruirla completa es la forma mas simple
-- de garantizar idempotencia (directriz 11) sin filas duplicadas al redesplegar.
DROP TABLE IF EXISTS bdm_stage.mock_numeros;
CREATE TABLE bdm_stage.mock_numeros (
  i INTEGER NOT NULL
)
DISTSTYLE ALL
SORTKEY (i);

-- Producto cartesiano de 4 digitos -> 0..9999.
-- Se usan subconsultas derivadas en lugar de una CTE para no depender del
-- soporte de WITH dentro de INSERT: esta forma es la de menor riesgo en rsql.
INSERT INTO bdm_stage.mock_numeros (i)
SELECT d4.n * 1000 + d3.n * 100 + d2.n * 10 + d1.n
FROM      (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d1
CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d2
CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d3
CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d4;
