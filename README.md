# Reconocer Redshift — paquete STRCT (estructura)

Unificación de direcciones, Ordenamiento, GEO y Novedades de Experian
Reconocer, migrados de Teradata a Amazon Redshift.

**`type: struct` · `order: 1` · se despliega el PRIMERO de los tres.**

Sólo DDL: schemas, tablas, vistas, catálogos y funciones. Ningún
procedimiento de negocio y ningún dato.

## Qué hay en el paquete

| Ruta | Contenido |
|---|---|
| `deploy/redshift/SLCOPRBA-1353/deploy.par` | el orden de despliegue, una línea por archivo |
| `deploy/redshift/SLCOPRBA-1353/SQL/` | 49 archivos de DDL |
| `deploy/redshift/SLCOPRBA-1353/rollback.par` | el reverso exacto, en orden inverso |
| `deploy/redshift/SLCOPRBA-1353/RevSQL/` | un reverso por archivo |

Cubre las cuatro vertientes: Unificación (`01`–`03`), Ordenamiento
(`04`–`12`, `20`–`27`), GEO (`03`) y Novedades (`30`–`39`), más las siete
tablas dominio `bdm_datos.mat_*` que son la entrega al Batch.

## Orden de despliegue

**`strct` → `pgm` → `dt`.** Las vistas van `WITH NO SCHEMA BINDING`
precisamente para que ese orden no las rompa, pero los procedimientos de
`pgm` sí necesitan que las tablas existan.

## Convenciones que el pipeline exige

| Código | Causa |
|---|---|
| `REDSHIFT:112` | error SQL durante el deploy — es lo único que tumba el build |
| `REDSHIFT:207` | BOM en un `.par` — van en UTF-8 **sin** BOM |
| `REDSHIFT:219` | un archivo de `RevSQL/` con basename distinto al de `rollback.par` |
| `REDSHIFT:232` | `UPDATE`/`DELETE` de nivel superior sin `WHERE` |
| `JENKINS:104/105` | rama sin el ID de la subtarea |

DDL idempotente (`CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE VIEW`),
UTF-8 sin BOM y ASCII sin acentos dentro de `deploy/`. Nunca
`GRANT … TO PUBLIC` ni `DROP SCHEMA … CASCADE`: `bdm_datos` es compartido.

## De dónde sale esto

Este repositorio es **sólo de despliegue**. El trabajo, la bitácora de
divergencias contra el legado, el banco de pruebas local y los validadores
viven en el repositorio de GitHub del equipo; aquí llega únicamente
`deploy/redshift/` y este `.jenkins.yml`.
