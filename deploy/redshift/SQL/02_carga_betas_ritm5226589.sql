-- ============================================================
-- 02_carga_betas_ritm5226589.sql
-- Catálogo bdm_datos.beta_ordenamiento desde Teradata REC_VISTA
-- Fuente: LogRITM5226589.txt (John Bueno, 2026-09-15)
-- Vistas: V_Beta_Ordenamiento_Tel / Cel / Email / Dir
-- Acuerdo sesión/mesa: betas = coeficientes en tablas auxiliares/catálogos
-- Decimal EU en el log (114,09942950) → 114.09942950
-- Reemplaza 02_mock_betas.sql (valores ~0.1 eran placeholder)
-- ============================================================

TRUNCATE TABLE bdm_datos.beta_ordenamiento;

-- TEL (11) — Beta_Ord_Tel
INSERT INTO bdm_datos.beta_ordenamiento (canal, cod_caracteristica, valor_beta) VALUES
  ('TEL', 'CO01TEL001', 114.09942950),
  ('TEL', 'CO01TEL019',  68.45965770),
  ('TEL', 'CO01TEL007',  65.19967400),
  ('TEL', 'CO01TEL017', 133.65933170),
  ('TEL', 'CO01TEL003',-130.39934800),
  ('TEL', 'CO01TEL002', -81.49959250),
  ('TEL', 'CO01TEL006', 130.39934800),
  ('TEL', 'CO01TEL025', 179.29910350),
  ('TEL', 'CO01TEL023', 162.99918500),
  ('TEL', 'CO01TEL020', 136.91931540),
  ('TEL', 'CO01TEL010',  61.93969030);

-- CEL (11) — Beta_Ord_Cel
INSERT INTO bdm_datos.beta_ordenamiento (canal, cod_caracteristica, valor_beta) VALUES
  ('CEL', 'CO01CEL014', 124.48132780),
  ('CEL', 'CO01CEL018', 153.52697100),
  ('CEL', 'CO01CEL023', 161.82572610),
  ('CEL', 'CO01CEL015', 107.88381740),
  ('CEL', 'CO01CEL003',  82.98755187),
  ('CEL', 'CO01CEL006', 124.48132780),
  ('CEL', 'CO01CEL017',  41.49377593),
  ('CEL', 'CO01CEL007', 103.73443980),
  ('CEL', 'CO01CEL013', 124.48132780),
  ('CEL', 'CO01CEL019', 186.72199170),
  ('CEL', 'CO01CEL020', 203.31950210);

-- EMA (13) — Beta_Ord_Mail
INSERT INTO bdm_datos.beta_ordenamiento (canal, cod_caracteristica, valor_beta) VALUES
  ('EMA', 'CO01EMA017', -30.56079051),
  ('EMA', 'CO01EMA020',  61.12158101),
  ('EMA', 'CO01EMA025', 161.97218970),
  ('EMA', 'CO01EMA010',  70.28981816),
  ('EMA', 'CO01EMA007',  91.68237152),
  ('EMA', 'CO01EMA021', 113.07492490),
  ('EMA', 'CO01EMA018',  91.68237152),
  ('EMA', 'CO01EMA024', 134.46747820),
  ('EMA', 'CO01EMA016',  85.57021342),
  ('EMA', 'CO01EMA014',-130.80018340),
  ('EMA', 'CO01EMA003',-106.96276680),
  ('EMA', 'CO01EMA023', 180.30866400),
  ('EMA', 'CO01EMA015',  79.45805532);

-- DIR (12) — Beta_Ord_Dir
INSERT INTO bdm_datos.beta_ordenamiento (canal, cod_caracteristica, valor_beta) VALUES
  ('DIR', 'CO00DIR050TO', 100.64516130),
  ('DIR', 'CO00DIR059',   135.48387100),
  ('DIR', 'CO00DIR034FI', 135.48387100),
  ('DIR', 'CO00DIR007TO',  32.25806452),
  ('DIR', 'CO00DIR001IN',  80.64516129),
  ('DIR', 'CO00DIR010FI',  54.83870968),
  ('DIR', 'CO00DIR013OT', 125.80645160),
  ('DIR', 'CO00DIR004RO',  96.77419355),
  ('DIR', 'CO00DIR057',    85.16129032),
  ('DIR', 'CO01DIR009',   -51.61290323),
  ('DIR', 'CO00DIR019',    72.25806452),
  ('DIR', 'CO00DIR017',    29.03225806);

-- Gate carga
SELECT canal, COUNT(*) AS n, MIN(valor_beta) AS min_b, MAX(valor_beta) AS max_b
FROM bdm_datos.beta_ordenamiento
GROUP BY 1
ORDER BY 1;
-- Esperado: DIR=12, TEL=11, CEL=11, EMA=13 → total 47
