# Criterios de aceptación — Ordenamiento (REAL y MOCK)

**Regla:** QA debe correr **dos modos separados**. Ambos deben **PASSED** en la misma matriz de criterios.  
No mezclar `bdm_datos` (EDF real) con `bdm_stage` (mock) en la misma corrida.

| | Modo A — REAL | Modo B — MOCK |
|--|---------------|---------------|
| DB | `dba_rncr_batch` | sandbox QA / `dba_batch` |
| Schema resultado | `bdm_datos` | `bdm_stage` (`mock_ord_*`) |
| Orquestador | `CALL bdm_datos.sp_ordenamiento_ejecucion_edf(TRUE)` | Seed + validación (`docs/sql_qa_ordenamiento_mock/`) |
| Validación | `validacion_ordenamiento_criterios_aceptacion.sql` (modo REAL) | `03_validar_criterios_mock.sql` |
| HTML / ejemplos | Caso A/B opcionales (volumen) | Personas **20001–20014** (cobertura total) |

---

## Matriz única (mismo ID de criterio en ambos modos)

| ID | Criterio | Esperado | REAL cómo | MOCK cómo |
|----|----------|----------|-----------|-----------|
| **CA-O01** | Pipeline corre / hay scores | DIR·TEL·EMA > 0 (CEL puede ser bajo) | `score_ordenamiento` | `mock_ord_score` |
| **CA-O02** | Betas RITM | **47** filas | `beta_ordenamiento` | misma tabla o snapshot mock 47 |
| **CA-O03** | Hijas sin orden | **0** hijas con `orden_prioridad` | gate E2E | persona **20011** + conteo mock |
| **CA-O04** | RANK-01 mayor score → lugar 1 | lugar 1 = max score | Caso B / muestra | persona **20001** |
| **CA-O05** | F3-02 hija sin score | 0 scores en RPU hija | Caso A RPU 3 | persona **20011** hija |
| **CA-O06** | Canales independientes | DIR/TEL/EMA no mezclan ranking | Caso A | **20001+20004+20008** |
| **CA-O07** | Salida `orden_prioridad` = lugar DIR | orden = lugar DIR | Caso B | **20001** |
| **CA-O08** | RANK-02 empate documentado | 2 DIR mismo score → 2 lugares | búsqueda (puede 0 filas) | persona **20010** (obligatorio) |
| **CA-O09** | TEL-02 TEL020 fuera SUM | score no cambia si solo cambia TEL020 | evidencia SP + betas | persona **20013** (scores iguales) |
| **CA-O10** | EMA-03 003/007/018/025 fuera SUM | score no cambia si solo cambian excluidas | evidencia SP + betas | persona **20014** |
| **CA-O11** | CEL-02 default 0.22 | prefijo sin catálogo usa default | catálogo + muestra | persona **20012** |
| **CA-O12** | Ranking multi-DIR | lugares 1..n sin eliminar ganadoras | Caso B / muestra | **20003** (3 DIR) |

### Sign-off QA

| Modo | Resultado | Evidencia |
|------|-----------|-----------|
| A — REAL | PASSED / FAILED | Adjuntar output gates a HU |
| B — MOCK | PASSED / FAILED | Adjuntar output `03_validar_criterios_mock.sql` |
| **Cierre ordenamiento** | Ambos PASSED | — |

Si REAL no tiene persona para CA-O08…O11, **no se marca PASSED el criterio de escenario** en REAL; se marca **N/A (sin caso)** y el **PASSED obligatorio** de ese criterio lo aporta **MOCK**.  
Los gates de volumen (CA-O01, O02, O03) en REAL son siempre obligatorios.

---

## Personas MOCK (HTML = estos IDs)

| id_buro (mock) | Escenario | Criterio |
|---------------:|-----------|----------|
| 20001 | 2 DIR scores distintos | CA-O04, CA-O07 |
| 20002 | 1 DIR | trivial lugar 1 |
| 20003 | 3 DIR | CA-O12 |
| 20004 | TEL válido vs no válido | CA-O06 |
| 20005 | 1 TEL | trivial |
| 20006 | 2 CEL operadores | CEL ranking |
| 20007 | 1 CEL | trivial |
| 20008 | 2 EMA | CA-O06 |
| 20009 | 1 EMA | trivial |
| 20010 | 2 DIR **mismo** score | CA-O08 |
| 20011 | Padre + hija unificación | CA-O03, CA-O05 |
| 20012 | CEL prefijo sin catálogo | CA-O11 |
| 20013 | TEL020 aislamiento | CA-O09 |
| 20014 | EMA003/007 aislamiento | CA-O10 |

Scripts: [`docs/sql_qa_ordenamiento_mock/`](sql_qa_ordenamiento_mock/00_RUNBOOK_ORDENAMIENTO_MOCK.sql)

---

## Hallazgo de revisión (2026-09-24)

| Pieza | Estado antes | Estado objetivo |
|-------|--------------|-----------------|
| Gates REAL | Existen (`validacion_ordenamiento_conteos` / E2E) | Mantener + matriz CA |
| Suite MOCK `sql/ordenamiento_mock/` | **Referenciada pero ausente** | Creada en `sql_qa_ordenamiento_mock/` |
| Misma matriz CA ambos modos | **No** (mock solo “demo”) | **Sí** — este documento |
| HTML ejemplos | Mezcla REAL + MOCK UP sin seed | Personas **20001–20014** del mock |
