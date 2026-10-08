# Pendientes y cierre — Unificación + Ordenamiento

**Fecha base:** 2026-09-04 (evidencias DEV) · **Actualizado:** 2026-09-23  
**Rama:** `feature/ordenamiento` (3 repos) · Unificación EDF también en `feature/unificacion-edf-views`

---

## Hecho (nuestro lado — código)

| Ítem | Evidencia |
|------|-----------|
| Unificación R1→R2→R3 (SPs por escenario, `bdm_datos`) | `_pgm` + corrida DEV R2=72.448 · C03/C04=0 |
| Vistas `v_xpm_*` + DDL unificación | `_strct` |
| Ordenamiento DIR/TEL/CEL/EMA + consolidación `_edf` | `_pgm` |
| Betas RITM5226589 (47 coefs) | `_strct` `02_carga_betas_ritm5226589.sql` |
| `run_` + validaciones + E2E gates | `_dt` |
| Docs entrega QA (unif + ord) | `ENTREGA_QA_*.md` |
| `deploy.par` sin duplicados, orden STRCT→PGM→DT | 2026-09-23 |

---

## Nuestro lado — pendiente operativo (cerrar esta semana)

| # | Acción | Quién | Bloquea |
|---|--------|-------|---------|
| N1 | Abrir **3 PRs** Bitbucket `feature/ordenamiento` → base acordada (orden **strct → pgm → dt**) | Andrés / Manuel | Merge + Jenkins |
| N2 | Merge PRs tras review | Reviewer Experian | Deploy QA |
| N3 | Disparar subtareas Jenkins STRCT→PGM→DT en DEV/QA | Ejecutor Jira | Certificación |
| N4 | Correr `validacion_gates_cierre_e2e.sql` y adjuntar resultado a HU | Andrés | Cierre QA |
| N5 | Entregar a Julian/Katerin: `ENTREGA_QA_UNIFICACION.md` + `ENTREGA_QA_ORDENAMIENTO.md` | Andrés | Aceptación |
| N6 | Publicar plantilla Confluence (`contexto_reconocer/06_…`) | Andrés | Doc oficial |

Plantilla de PRs: [`PLANTILLA_PR_BITBUCKET_ORDENAMIENTO.md`](PLANTILLA_PR_BITBUCKET_ORDENAMIENTO.md)

---

## Fuera de nuestro lado (escalar — no bloquea merge de código)

| # | Dependencia | Owner | Impacto |
|---|-------------|-------|---------|
| X1 | Grants Data Sharing / SELECT consumidor → `edf_views` | DBA Experian | Corrida QA/PDN |
| X2 | Lat/long Geo real (unload ArcGIS) | Equipo Geo | R3 real > 0; hoy R3=N/A |
| X3 | Ventana / aprobación CAB PDN | DevSecOps | Promoción prod |
| X4 | PDF reglas negocio Ordenamiento firmado | Producto Experian | Cierre formal QA ord |
| X5 | MIG-01 paridad Teradata formal | Experian + nosotros | Certificación numérica |
| X6 | Amarrar Framework Batch cascada prod | FW Batch | Orquestación E2E automatizada |

**Acuerdo Mesa (Garrido/Manuel):** no bloquear ordenamiento por enriquecimiento Geo; cerrar R3 con lo disponible (0 filas = N/A) y avanzar scoring.

---

## Criterios de “cerrado” para nosotros

1. PRs mergeados en los 3 repos.  
2. Jenkins DEV OK (`deploy.par`).  
3. Gates E2E: C03=0, C04=0, hijas_con_orden_incorrecto=0, betas=47.  
4. Entrega QA enviada (prompts reales vs mock separados).  
5. Lista X1–X6 escalada por ticket/correo (no pendiente de código).
