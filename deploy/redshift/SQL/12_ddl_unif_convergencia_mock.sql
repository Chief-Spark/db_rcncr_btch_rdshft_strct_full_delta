-- SLCOPRBA-1354: M5 -- soporte del gate de convergencia FULL -> DELTA -> DELTA.
--
-- El gate necesita comparar el ESTADO de las tablas de salida entre corridas.
-- No se guarda el contenido completo (33 000 filas por corrida), sino una
-- huella por objeto: conteo mas un checksum independiente del orden.
--
-- El checksum es SUM(FNV_HASH(columnas concatenadas)) casteado a DECIMAL(38,0):
-- FNV_HASH devuelve BIGINT y sumar decenas de miles desbordaria, por eso el
-- acumulador es DECIMAL. Es independiente del orden de las filas, que es lo que
-- se quiere: dos corridas pueden producir las mismas filas en otro orden.
--
-- Tablas de staging del mock: DROP + CREATE, no hay dato productivo que perder.
DROP TABLE IF EXISTS bdm_stage.mock_unif_convergencia;
CREATE TABLE IF NOT EXISTS bdm_stage.mock_unif_convergencia (
  etiqueta    VARCHAR(32)   NOT NULL,  -- FULL | DELTA1 | DELTA2 | FULL2 ...
  secuencia   INTEGER       NOT NULL,  -- orden de la corrida dentro de la prueba
  objeto      VARCHAR(64)   NOT NULL,  -- tabla observada
  filas       BIGINT,
  checksum    DECIMAL(38,0),
  lote        INTEGER,
  fecha_snap  TIMESTAMP     DEFAULT GETDATE()
)
DISTSTYLE ALL
SORTKEY (secuencia, objeto);

DROP TABLE IF EXISTS bdm_stage.mock_unif_ca_result;
CREATE TABLE IF NOT EXISTS bdm_stage.mock_unif_ca_result (
  criterio_ca VARCHAR(16)  NOT NULL,
  estado      VARCHAR(16)  NOT NULL,
  detalle     VARCHAR(1024),
  fecha_check TIMESTAMP    DEFAULT GETDATE()
)
DISTSTYLE ALL;
