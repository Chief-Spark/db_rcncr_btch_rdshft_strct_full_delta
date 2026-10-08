# Plantilla PRs Bitbucket — `feature/ordenamiento`

**Proyecto:** COAWSPPR  
**Orden obligatorio:** 1) `_strct` → 2) `_pgm` → 3) `_dt`  
**VPN:** requerida (`code.experian.local`)

> Al 2026-09-23: push OK. PRs ya existentes hacia `master`:
> - STRCT [#4](https://code.experian.local/projects/COAWSPPR/repos/db_rcncr_btch_rdshft_strct/pull-requests/4)
> - DT [#8](https://code.experian.local/projects/COAWSPPR/repos/db_rcncr_btch_rdshft_dt/pull-requests/8)
> - PGM: verificar/abrir si no existe (mismo sourceBranch)

---

## 1. STRCT — `db_rcncr_btch_rdshft_strct`

**URL create:**  
`https://code.experian.local/projects/COAWSPPR/repos/db_rcncr_btch_rdshft_strct/pull-requests?create&sourceBranch=refs/heads/feature/ordenamiento`

**Title:**
```
feat: DDL unificación + ordenamiento EDF y betas RITM5226589
```

**Description:**
```markdown
## Summary
- DDL unificación (`unificacion_direccion`) + vistas `v_xpm_*` (edf_views)
- DDL / catálogos ordenamiento + vistas contacto/insumo EDF
- Carga betas RITM5226589 (47 coeficientes)
- `deploy.par` sin duplicados; orden de ejecución corregido

## Deploy
STRCT primero. Luego PGM, luego DT.

## Test plan
- [ ] Jenkins STRCT OK en DEV
- [ ] Objetos en `bdm_datos` / `bdm_tempo` creados
- [ ] `SELECT COUNT(*) FROM bdm_datos.beta_ordenamiento` = 47
```

---

## 2. PGM — `db_rcncr_btch_rdshft_pgm`

**URL create:**  
`https://code.experian.local/projects/COAWSPPR/repos/db_rcncr_btch_rdshft_pgm/pull-requests?create&sourceBranch=refs/heads/feature/ordenamiento`

**Title:**
```
feat: SPs unificación R1-R3 + ordenamiento scoring EDF
```

**Description:**
```markdown
## Summary
- 15 SPs unificación por escenario + orquestadores regla1/2/3
- 8 SPs ordenamiento `_edf` (preparar, DIR/TEL/CEL/EMA, consolidación, drop, ejecución)
- Rollback alineado a nombres reales

## Precondición
Merge/deploy STRCT de esta misma rama.

## Test plan
- [ ] Jenkins PGM OK tras STRCT
- [ ] `CALL bdm_datos.sp_unificacion_regla1/2/3`
- [ ] `CALL bdm_datos.sp_ordenamiento_ejecucion_edf(TRUE)`
```

---

## 3. DT — `db_rcncr_btch_rdshft_dt`

**URL create:**  
`https://code.experian.local/projects/COAWSPPR/repos/db_rcncr_btch_rdshft_dt/pull-requests?create&sourceBranch=refs/heads/feature/ordenamiento`

**Title:**
```
feat: run/validación unificación+ordenamiento y docs entrega QA
```

**Description:**
```markdown
## Summary
- `run_unificacion_ejecucion_secuencial` + `run_ordenamiento_ejecucion_edf`
- Validaciones + `validacion_gates_cierre_e2e` + `run_reconocer_e2e_*`
- Docs `ENTREGA_QA_*`, pendientes/cierre, plantillas

## Precondición
STRCT + PGM desplegados.

## Test plan
- [ ] Ejecutar gates E2E; C03=0, C04=0, hijas_orden_incorrecto=0
- [ ] Adjuntar resultado a HU / ticket QA
```

---

## Mensaje corto (Teams / Manuel)

```
Listos los 3 repos en feature/ordenamiento.
Pido abrir/aprobar PRs en orden STRCT → PGM → DT (plantilla en docs/PLANTILLA_PR_BITBUCKET_ORDENAMIENTO.md).
Post-merge: Jenkins + validacion_gates_cierre_e2e.sql.
Fuera de nosotros (escalar): grants datashare, Geo lat/long, ventana PDN, PDF ord firmado.
```
