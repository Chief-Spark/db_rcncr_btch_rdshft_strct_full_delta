# db_rcncr_btch_rdshft_strct — Estructura Unificación (edf_views)

Paquete **type: struct** — schemas, DDL salida y vistas `bdm_tempo.v_xpm_*` sobre datashare `edf_views`.

## Orden de deploy (`deploy.par`)

| # | Archivo | Contenido |
|---|---------|-----------|
| 1 | `00_prerequisitos_schemas.sql` | `bdm_datos`, `bdm_tempo`, `convert_epoch_to_date` |
| 2 | `01_ddl_unificacion_direccion.sql` | Tabla salida + catálogos locales |
| 3 | `02_vistas_insumo_edf_views.sql` | Vistas lectura datashare (sin copiar XPM) |

Desplegar **antes** de `_pgm` y `_dt`.

## QA DEV

Validado 2026-09-04 — ver `../db_rcncr_btch_rdshft_dt/docs/Evidencias_QA_UNIFICACION_ESCENARIOS_DEV.md`

## Documentación

- Mapa negocio HTML: `../db_rcncr_btch_rdshft_dt/docs/MAPA_UNIFICACION_EDF_VIEWS_NEGOCIO.html`
- Checklist Manuel: `../db_rcncr_btch_rdshft_dt/docs/CHECKLIST_REVISION_MANUEL_DATOS_REALES.md`
