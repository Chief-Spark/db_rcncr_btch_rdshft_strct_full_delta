-- Rollback 00: NO hacer DROP SCHEMA CASCADE.
-- bdm_datos/bdm_tempo alojan SP de pgm; CASCADE los borra (dt #257+ 42883
-- tras strct #256). CREATE SCHEMA IF NOT EXISTS es suficiente en DPLY.
SELECT 1;
