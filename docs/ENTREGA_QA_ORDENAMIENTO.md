# Entrega QA — Ordenamiento (scoring post-unificación)

**Alcance de esta entrega:** solo **Ordenamiento / scoring de contactabilidad** (DIR · TEL · CEL · EMA).  
**Fuera de alcance aquí:** Unificación R1/R2/R3 (ver `ENTREGA_QA_UNIFICACION.md`).

**Fecha:** 2026-09-16  
**Rama Bitbucket (3 repos):** `feature/ordenamiento`  
**Orden deploy:** `_strct` → `_pgm` → `_dt`  
**Precondición:** Unificación ya corrida (hijas excluidas; solo ganadoras entran).

---

## 1. Qué deben configurar en el prompt

Hay **dos modos**. Elegir **uno** por corrida; no mezclar.

| | Modo A — Datos reales (EDF) | Modo B — Datos mockeados |
|--|-----------------------------|---------------------------|
| **Para qué** | Gates de volumen + IDs DEV | **Misma matriz CA** + escenarios que REAL no tiene |
| **DB** | Consumidor Reconocer · `dba_rncr_batch` | Sandbox QA · `dba_batch` / `bdm_stage` |
| **Insumo** | Post-unificación + `edf_views` / `v_xpm_*` | `docs/sql_qa_ordenamiento_mock/` personas **20001–20014** |
| **SPs** | Sufijo `_edf` en **`bdm_datos`** | Seed lab (no CALL `_edf` en esta corrida) |
| **Betas** | Catálogo **RITM5226589** (47) | Mismas 47 (check CA-O02) |
| **Criterios** | [`CRITERIOS_ACEPTACION_ORDENAMIENTO_REAL_Y_MOCK.md`](CRITERIOS_ACEPTACION_ORDENAMIENTO_REAL_Y_MOCK.md) | **Idénticos** CA-O01…CA-O12 |
| **Sign-off** | PASSED obligatorio CA-O01/O02/O03 | PASSED **todos** CA-O01…CA-O12 |
| **HTML ejemplos** | Opcional Caso A/B | **Oficial:** personas mock del seed |

---

## 2. Modo A — Datos reales (Ordenamiento EDF)

### 2.1 Precondición

1. Data Sharing activo (`ds_dba_rncr_batch.edf_views`).
2. Vistas `bdm_tempo.v_xpm_*` desplegadas.
3. Unificación ejecutada → `bdm_datos.unificacion_direccion` con C03/C04 = 0.
4. Catálogos / DDL ordenamiento desplegados (`_strct`).

### 2.2 Artefactos por repo

| Repo | Qué despliega |
|------|----------------|
| `_strct` | DDL + catálogos + vistas contacto/insumo EDF |
| `_pgm` | SPs preparar · scoring DIR/TEL/CEL/EMA · consolidación · drop staging · orquestador |
| `_dt` | `run_ordenamiento_ejecucion_edf.sql` + `validacion_ordenamiento_conteos.sql` |

### 2.3 Stored procedures (nombres exactos)

```sql
-- Orquestador (recomendado)
CALL bdm_datos.sp_ordenamiento_ejecucion_edf(TRUE);

-- Equivalente por pasos (si se valida fase a fase):
-- CALL bdm_datos.sp_ordenamiento_preparar_insumos_edf();
-- CALL bdm_datos.sp_ordenamiento_scoring_dir_edf();
-- CALL bdm_datos.sp_ordenamiento_scoring_tel_edf();
-- CALL bdm_datos.sp_ordenamiento_scoring_cel_edf();
-- CALL bdm_datos.sp_ordenamiento_scoring_ema_edf();
-- CALL bdm_datos.sp_ordenamiento_consolidacion_edf();
-- CALL bdm_datos.sp_ordenamiento_drop_staging_edf();
```

Script DT: `run_ordenamiento_ejecucion_edf.sql`

### 2.4 Salidas a validar

| Objeto | Rol |
|--------|-----|
| `bdm_datos.score_ordenamiento` | Scores por canal |
| `bdm_datos.rpu_orden_prioridad` | Ranking DIR → `orden_prioridad` |
| `bdm_datos.relacion_persona_ubicacion.orden_prioridad` | Campo final en RPU (canal DIR) |

### 2.5 Gates de Ordenamiento (modo real)

Usar `validacion_ordenamiento_conteos.sql` o:

```sql
-- Scores por canal
SELECT canal, COUNT(*) AS scores,
       ROUND(MIN(score::FLOAT), 4) AS min_s,
       ROUND(MAX(score::FLOAT), 4) AS max_s
FROM bdm_datos.score_ordenamiento
GROUP BY 1 ORDER BY 1;

-- Gate hijas (DEBE ser 0)
SELECT COUNT(*) AS hijas_con_orden_incorrecto
FROM bdm_datos.relacion_persona_ubicacion
WHERE COALESCE(ind_unificacion, 0) = 1
  AND orden_prioridad IS NOT NULL;
```

| Gate | Esperado |
|------|----------|
| Scores DIR / TEL / EMA | > 0 (en DEV ~407K c/u) |
| Scores CEL | Puede ser bajo (dato ambiente; en DEV ~258) |
| `rpu_hijas_con_orden_incorrecto` | **0** |
| Fórmulas TEL-02 / EMA-03 / CEL-02 | Alineadas (ya en rama) |
| Betas | **47 filas RITM5226589** en `bdm_datos.beta_ordenamiento` (ver `BETAS_ORDENAMIENTO_RITM5226589.md`) |

**Evidencia DEV (2026-09-04):** total scores **1.223.998** · RPUs con orden **408.624** · hijas mal ordenadas **0**.

**No mezclar** en la misma corrida: path mock `bdm_stage` + path EDF `bdm_datos`.

---

## 3. Modo B — Datos mockeados (suite CA completa)

| Pieza | Valor |
|-------|--------|
| Runbook | `docs/sql_qa_ordenamiento_mock/00_RUNBOOK_ORDENAMIENTO_MOCK.sql` |
| DDL + seed | `01_ddl_…` → `02_seed_escenarios_mock.sql` (20001–20014) |
| Validación | `03_validar_criterios_mock.sql` → veredicto `PASSED_ALL` |
| Criterios | Mismos CA-O01…CA-O12 que Modo A |
| HTML | Tablas del mapa = filas de este seed |

**Obligatorio para sign-off QA** junto con Modo A: MOCK cubre empate, TEL-02, CEL-02, EMA-03 cuando REAL no tiene persona.  
MIG-01 paridad Teradata sigue siendo externo (no se cierra solo con mock).

---

## 4. Prompts listos (copiar)

### Prompt Ordenamiento — datos reales

```
Proceso: ORDENAMIENTO (scoring DIR/TEL/CEL/EMA). No re-evaluar Unificación salvo precondición.

Ambiente: consumidor Reconocer / dba_rncr_batch (Data Sharing).
Precondición: unificación ya corrida; solo RPU ganadoras entran.
SPs: CALL bdm_datos.sp_ordenamiento_ejecucion_edf(TRUE);
Salidas: bdm_datos.score_ordenamiento + rpu_orden_prioridad / orden_prioridad.
Validar: scores por canal > 0; hijas con orden = 0.
Betas: catálogo RITM5226589 (47 coefs) en bdm_datos.beta_ordenamiento.
CEL bajo en DEV es dato del ambiente, no FAIL del SP.
No mezclar bdm_stage mock en esta corrida.
```

### Prompt Ordenamiento — mock (matriz CA)

```
Proceso: ORDENAMIENTO MOCK (suite CA). No mezclar con EDF bdm_datos.

DB/schema: sandbox · bdm_stage.mock_ord_*
Scripts: docs/sql_qa_ordenamiento_mock/  (01 → 02 → 03)
Personas HTML: 20001–20014
Validar: 03_validar_criterios_mock.sql → PASSED_ALL (CA-O01…CA-O12)
Betas: COUNT beta_ordenamiento = 47 (CA-O02)
Sign-off: este modo + Modo A REAL ambos PASSED.
```

---

## 5. Estado en Bitbucket / brechas

| Ítem Ordenamiento | Estado |
|-------------------|--------|
| DDL + vistas (`_strct`) | En `feature/ordenamiento` |
| 8 SPs `_edf` (`_pgm`) incl. TEL/EMA/CEL | En rama |
| `run_` + validación (`_dt`) | En rama |
| Gates E2E + run unif→ord | `validacion_gates_cierre_e2e.sql` · `run_reconocer_e2e_unificacion_ordenamiento.sql` |
| Matriz CA REAL+MOCK | `CRITERIOS_ACEPTACION_ORDENAMIENTO_REAL_Y_MOCK.md` + `sql_qa_ordenamiento_mock/` |
| Validación CA REAL | `validacion_ordenamiento_criterios_aceptacion.sql` |
| `deploy.par` | Corregido 2026-09-23 (sin duplicados; unif validación antes de ord) |
| PRs abiertos / merge | **Pendiente operativo** — plantilla `PLANTILLA_PR_BITBUCKET_ORDENAMIENTO.md` (VPN) |
| Deploy Jenkins QA consumidor | Pendiente post-merge |
| **BETAS** catálogo RITM5226589 | **Cargado** en SQL (`02_carga_betas_ritm5226589.sql`) |
| **MIG-01** paridad Teradata | Pendiente externo (después de betas) |
| **F1-INC** incremental | No en scope Opción A (full refresh) |

---

## 6. Referencias

| Documento | Uso |
|-----------|-----|
| `FASES_ORDENAMIENTO_EXPLICADAS.md` | Fases F0–F4 |
| `GUIA_ORDENAMIENTO_EJEMPLOS_BASICOS.md` | Checklist + ejemplos |
| `Evidencias_ORDENAMIENTO_FORMULAS_DEV.md` | TEL-02 / EMA-03 / CEL-02 |
| `Evidencias_DEV_ORDENAMIENTO_EDF_COMPLETO.md` | E2E DEV |
| `PENDIENTES_Y_CIERRE_2026-09-04.md` | Hecho vs externo |
| `MAPA_ORDENAMIENTO_EDF_VIEWS_NEGOCIO.html` | Mapa negocio |

*Complemento Unificación:* `ENTREGA_QA_UNIFICACION.md`
