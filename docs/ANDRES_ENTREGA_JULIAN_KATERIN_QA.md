# Entrega Andrés → QA (índice)

Usar **un documento por proceso**. No mezclar corridas reales y mock.

| Proceso | Documento | Rama sugerida |
|---------|-----------|---------------|
| **Unificación** R1/R2/R3 | [`ENTREGA_QA_UNIFICACION.md`](ENTREGA_QA_UNIFICACION.md) | `feature/unificacion-edf-views` **o** `feature/ordenamiento` (incluye unif.) |
| **Ordenamiento** DIR/TEL/CEL/EMA | [`ENTREGA_QA_ORDENAMIENTO.md`](ENTREGA_QA_ORDENAMIENTO.md) | `feature/ordenamiento` |
| Prompts real vs mock | [`PROMPT_PRUEBAS_QA_REAL_VS_MOCK.md`](PROMPT_PRUEBAS_QA_REAL_VS_MOCK.md) | — |
| Cierre / pendientes | [`PENDIENTES_Y_CIERRE_2026-09-04.md`](PENDIENTES_Y_CIERRE_2026-09-04.md) | — |
| PRs Bitbucket | [`PLANTILLA_PR_BITBUCKET_ORDENAMIENTO.md`](PLANTILLA_PR_BITBUCKET_ORDENAMIENTO.md) | `feature/ordenamiento` |

**Orden deploy:** `_strct` → `_pgm` → `_dt`  
**Certificación E2E (opcional, post-deploy):**  
`deploy/redshift/SQL/run_reconocer_e2e_unificacion_ordenamiento.sql`  
luego `validacion_gates_cierre_e2e.sql`

### Destinatarios
Julian / Katerin (QA) · Manuel (técnico) · DBA solo para grants (X1)
