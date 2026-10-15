-- ============================================================
-- 00_prerequisitos_dev.sql
-- Consumidor Reconocer DEV — schemas locales + convert_epoch
-- Precondición DBA: CREATE DATABASE ds_dba_rncr_batch FROM DATASHARE ds_reconocer_procesosbatch_dev
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_datos;
CREATE SCHEMA IF NOT EXISTS bdm_tempo;

CREATE OR REPLACE FUNCTION bdm_datos.convert_epoch_to_date(val BIGINT)
RETURNS DATE
STABLE
AS $$
  SELECT DATE(TIMESTAMP 'epoch' + ($1 / 1000) * INTERVAL '1 second')
$$ LANGUAGE SQL;
