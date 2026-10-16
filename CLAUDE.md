# Reconocer - repo de ESTRUCTURA (strct)

Unificacion de direcciones y Ordenamiento (scoring de contactabilidad) de
Experian Reconocer, migrados de Teradata a Amazon Redshift.

Este repo tiene `global.type = structure`: **solo DDL**. Tablas, vistas,
catalogos y funciones. Ningun procedimiento de negocio, ningun dato.
**Se despliega primero** de los tres.

## Donde esta que

| Pieza | Archivo |
|---|---|
| Schemas y funciones base | `deploy/redshift/SQL/00_prerequisitos_schemas.sql` |
| DDL de Unificacion | `01_ddl_unificacion_direccion.sql` (+ `01b` mock) |
| Vistas de insumo sobre el datashare | `02_vistas_insumo_edf_views.sql` |
| Tabla de numeros del mock | `02c_ddl_mock_numeros.sql` |
| GEO | `03_ddl_geo.sql` |
| DDL de Ordenamiento | `01_ddl_ordenamiento.sql`, `05_ddl_ordenamiento_mock.sql` |
| Betas del scoring (47, RITM5226589) | `02_carga_betas_ritm5226589.sql` |
| Censo de escenarios | `11c` / `11d_ddl_unif_escenario_censo*.sql` |
| Tablero de certificacion | `13_ddl_cert_criterios.sql` |

## Fuentes de verdad del negocio

- Unificacion: `PRO_UnificacionR2.sql` (legado Teradata).
- Ordenamiento F4: **`Caracteristicas.txt`** (~160 sentencias; ese archivo *es*
  el modelo de scoring). F1-F3: `Prc_Ordenamiento2.sql`.

## Reglas que no se negocian

1. **Nunca cambiar la firma de un SP.** El Framework Batch exige 6 parametros
   VARCHAR en los orquestadores, en este orden: `in_solicitud`,
   `in_nit_suscriptor`, `in_path_archivo`, `in_nemotecnico` (= MODO),
   `in_id_facturacion` (= LOTE), `in_fecha_ejecucion` (= FECHA). Los tres
   primeros no se usan y aun asi forman parte de la firma. Los gates NO usan
   esta firma: van `(VARCHAR, INTEGER)`.
2. **Rama `claude/elegant-carson-tqhcku`.** Nunca empujar a otra sin permiso
   explicito.
3. **No crear pull requests** salvo peticion expresa.
4. **Revisar el codigo de Teradata antes de decidir.** El documento funcional
   se equivoca; el codigo manda. Verificado tres veces en Unificacion y tres
   veces mas en Ordenamiento (EMA014, EMA025, DIR017).
5. **Certificar solo con datos mock.**
6. **Orden de despliegue: strct -> pgm -> dt.**

## El banco de pruebas local

`dt/banco/` replica el job de Jenkins sobre **PostgreSQL 16**, que esta
instalado en el contenedor. Corre los tres `deploy.par` en orden, archivo a
archivo. Existe porque Redshift **no compila el cuerpo de un procedimiento al
crearlo** y Jenkins era el unico modo de ejecutar una linea de SQL.

```
cd dt/banco && ./banco.sh init nueva && ./banco.sh fase strct
./banco.sh foto tras_pgm      # y ./banco.sh desde tras_pgm para re-correr en 2 s
```

**EL BANCO YA NO ES EL GATE.** Desde que el pipeline de Jenkins despliega y
corre la bateria **en Redshift real** (job DEV/DATABASE #370: e2e completo,
tablero y asercion final), la prueba que manda es esa. El banco se queda como
**chequeo previo de dos minutos** -- `./banco.sh fase pgm`, que compila los 74
archivos y verifica los 80 objetos -- y ahi es donde sigue siendo rentable:
caza en dos minutos lo que en Jenkins cuesta commit, push, traslado y job, y
sin dejar DEV a medias. La bateria larga de 45 minutos se corre cuando
interesa una hipotesis barata, no para certificar.

**Un verde del banco NO certifica.** Degrada un `[REDSHIFT:112]` de
"desconocido" a "especifico de Redshift". Postgres es mas permisivo que Redshift
en cinco formas y mas estricto en tres; `banco/README.md` las lista una por una,
y la disciplina es: **un fallo local es una hipotesis hasta trazarlo al legado o
a la documentacion de Redshift. Nunca cambiar codigo correcto en Redshift para
contentar a Postgres.**

El banco pone de su lado un `ANALYZE` y unos indices sobre las tablas sembradas.
Es compensacion del motor, no un parche al repo: Redshift resuelve esos joins
por fuerza bruta columnar y Postgres en un nodo no.

## Politicas del pipeline

| Codigo | Causa | Como se evita |
|---|---|---|
| `REDSHIFT:112` | error SQL durante el deploy | **es lo unico que tumba el build hoy** |
| `REDSHIFT:207` | BOM en un `.par` | UTF-8 **sin** BOM |
| `REDSHIFT:219` | basename de `RevSQL/` distinto a la linea de `rollback.par` | mismo nombre, sin sufijo `_rev` |
| `REDSHIFT:232` | `UPDATE`/`DELETE` de nivel superior sin `WHERE` | `WHERE` explicito, o `TRUNCATE` |
| `JENKINS:104/105` | rama sin ID de subtarea | nombrar la rama con la subtarea |

**EL TRASLADO A BITBUCKET LLEVA SOLO `deploy/redshift/`.** Nada de
`CLAUDE.md`, `validar.sh`, `docs/` ni `banco/`: Bitbucket es el repo de
despliegue y Jenkins solo lee `sourcePath`, `orderFile` y `sqlFolder`, todos
dentro del paquete. La secuencia de `./migra418.sh traslado <id>` ya lo hace
bien; **la linea de `git checkout ... -- validar.sh CLAUDE.md` fue un anadido
mio y es un error**: ensucia el diff que alguien tiene que revisar. Decision
del equipo, SLCOPRBA-1355. Consecuencia asumida: los chequeos de `validar.sh`
viven solo en el repo de trabajo; si alguna vez hacen falta del lado de
Bitbucket, el sitio es un paso del pipeline, no el repo.

**EL `[REDSHIFT:419]` NO SALE Y EL JOB MUERE: LO VERIFICADO Y LO QUE NO.**
Cuando el detector encuentra el paquete imprime
`[REDSHIFT:419] Paquete detectado en 'deploy/redshift/<id>'`; cuando no, cae
en silencio a la ruta legacy y el job muere con
`NoSuchFileException: .../deploy/redshift/deploy.par`, antes del stage de
despliegue y **sin tocar DEV**. Eso esta comprobado en los jobs #372, #373 y
#374, que fallan los tres con la misma firma.

**La causa raiz NO esta establecida, y tres explicaciones mias ya cayeron.**
Estan aqui para que nadie las vuelva a pagar:

| Hipotesis | Estado |
|---|---|
| "El paquete desaparecio de la rama" | falsa segun `git ls-files`: 151 archivos, ruta correcta. Pero ojo al parrafo de abajo: esa comprobacion no valia |
| "El commit no toca `deploy/redshift/`" | **sostenida solo para el #372** (`6a125a7` cambiaba unicamente `CLAUDE.md` y `validar.sh`): un commit asi tumba el build en vez de no hacer nada |
| "Un `push --force` deja a Jenkins sin changeset" | **caida con el #374**, que fallo igual |

**LA LECCION QUE SI VALE, Y ES DE METODO: `git ls-files` NO SIRVE PARA ESTO.**
Lee el indice local; Jenkins construye el remoto de Bitbucket. La comprobacion
correcta es
`git ls-tree -r --name-only origin/<rama> -- deploy/redshift`, y hay que
correrla **despues del push**, en el clon de Bitbucket.

**Y hay un modo de fallo real en la secuencia del traslado** (`migra418.sh:88-92`):
`git rm -r --cached deploy/redshift` borra el paquete del indice *antes* de que
`git checkout github/<rama> -- deploy/redshift` lo reponga. PowerShell no
encadena con `&&`, asi que si la copia falla, el `git commit` y el `git push`
siguientes se ejecutan igual y **suben el borrado**. Verificar con
`git ls-files` entre el `checkout` y el `commit`, y con `git ls-tree` contra el
remoto despues del `push`.

**Nunca reescribir la rama de Bitbucket entre despliegues**, y repuesto lo que
falte, seguir siempre con un commit normal hacia adelante que toque un archivo
del paquete.

`rollback.par` es el reverso exacto de `deploy.par`, modulo el prefijo
`NN_rollback_` en los archivos numerados. Todo archivo sin prefijo numerico
conserva su nombre en `RevSQL/`.

## Convenciones de codigo

- **UTF-8 sin BOM. ASCII sin acentos**, a proposito, en todo el repo.
- `NONATOMIC` en toda la cadena de `CALL`. Mezclar modos rompe con
  *"P0001: created in one transaction mode cannot be invoked from another"*.
- Rollback de procedimientos: `DROP PROCEDURE nombre(<firma exacta>);`
  **sin `IF EXISTS`** (Redshift da `syntax error at or near "EXISTS"`).
  Tablas y vistas si usan `IF EXISTS`.
- **Nunca `GRANT ... TO PUBLIC`.** Nunca `DROP SCHEMA ... CASCADE` desde
  `strct` (incidente DEV #256): `bdm_datos` es compartido.
- DDL idempotente: `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE VIEW`.
- Vistas con `WITH NO SCHEMA BINDING`, para que el orden de despliegue no las
  rompa.
- Tablas pequenas en `DISTSTYLE ALL`, con la justificacion escrita.
- **Paridad real <-> mock** en todo SP que se toque. El mock se genera por
  sustitucion de fuentes y debe regenerarse identico.
  **CUALES TIENEN ESPEJO Y CUALES NO, que es donde se falla:**
  `sp_ordenamiento_preparar_insumos_edf` **SI** tiene su `_mock`; los cuatro
  `sp_ordenamiento_scoring_*_edf` y `sp_ordenamiento_consolidacion_edf`
  **NO** -- el mock reutiliza los reales. Anadir una columna al insumo real
  y no al espejo tumba la bateria entera en el primer ciclo con
  `column "..." does not exist`, y pasa `validar.sh` sin una queja porque es
  un error semantico, no de sintaxis. Ya se pago (SLCOPRBA-1355). El
  `diff` de la rama tocada entre los dos archivos tiene que salir vacio.

## Trampas de Redshift ya pagadas

- `generate_series` es **leader-node only** -> usar `bdm_stage.mock_numeros`.
- `REGEXP_*` exige patrones **literales**, no derivados de columna.
- `EXISTS` no vale en la lista del `SELECT` (en el `WHERE` si).
- `UPDATE ... FROM`: el destino **no admite alias**.
- `CAST(fecha AS INTEGER)` no existe -> `(anio-1900)*10000 + mes*100 + dia`
  con `DATE_PART`.
- `CASE`/`COALESCE` no mezclan INTEGER y VARCHAR.
- **Todos los `LISTAGG` del MISMO `SELECT` comparten `WITHIN GROUP`** (por
  `SELECT`, no por sentencia). Es lo que tumbo el job #341.
- `LISTAGG(DISTINCT ...)` no convive con `COUNT(DISTINCT ...)` en el mismo
  `SELECT`.
- `COUNT(DISTINCT)` no vale como funcion de ventana -> `MIN()/MAX() OVER`.
- `REPLACE(x, NULL, '')` devuelve **NULL**.
- `SUM()` sobre cero filas devuelve **NULL**, no 0 -> guarda `COUNT(*) = 0`
  primero, y `COALESCE` despues. Sin eso, un criterio vacio sale PASSED.
- Subconsulta escalar en la proyeccion dentro de una agregacion: Redshift no la
  resuelve de forma fiable -> `CROSS JOIN`.
- El `DISTKEY` tiene que ser una columna de la **lista del SELECT**, no un
  alias (job #315).
- El `CAST` de la primera rama de un `UNION ALL` fija el tipo del nodo.
- **`ORDER BY ... DESC` pone `NULLS FIRST` por defecto** (Teradata hace lo
  contrario). Escribir `NULLS LAST` explicito.
- **`DELTA` es palabra reservada en Redshift** -- viene de los codificados
  `DELTA` / `DELTA32K` -- **y en PostgreSQL no lo es**. Un `AS delta` pasa el
  banco entero sin una queja y Redshift lo rechaza al desplegar:
  `42601: syntax error at or near "delta" in context "(g.delta"`. Tumbo el job
  DEV/DATABASE #366 en el archivo 73 de 74. Es el punto ciego del banco en
  estado puro, y por eso `validar.sh` lleva ahora el chequeo 8, que barre la
  familia entera (`RAW`, `ENCODE`, `TOP`, `TAG`, `PERCENT`, `SYSDATE`,
  `DISTKEY`, `SORTKEY`, `LZO`, `BYTEDICT`, `MOSTLY13`...).
- **El `RAISE` de Redshift admite VARIABLES, no expresiones.** La gramatica
  es `RAISE level 'format' [, variable [, ...]];` y una funcion en la lista
  de argumentos es un error de **sintaxis** en el propio `CREATE`:
  `42601: syntax error at or near "NULLIF"`. PostgreSQL si admite cualquier
  expresion ahi, de modo que el banco la ejecuta sin una queja: **segundo
  punto ciego del banco**, hermano de `DELTA`, y en el mismo sitio -- tumbo
  el job DEV/DATABASE #367 en el archivo 74 de 74, el siguiente al que mato
  al #366. La salida es mover la expresion al `SELECT` que alimenta la
  variable, que es SQL normal. `validar.sh` lleva el chequeo 9, que une cada
  sentencia `RAISE` hasta su `;`, descarta la cadena de formato (lleva
  parentesis propios) y falla si queda un `(` en la cola.
- `CREATE OR REPLACE PROCEDURE` **difiere la SEMANTICA, no la SINTAXIS.**
  *(Esta linea decia antes, en redondo, que "no compila el cuerpo: los errores
  salen en la primera invocacion". El job #366 lo desmiente a medias, y el
  #367 lo confirma: su error de sintaxis salto en el `CREATE` sin que el
  procedimiento llegara a invocarse nunca.)*
  Una tabla o columna que no existe si espera a la primera invocacion; un
  error de sintaxis salta en el propio `CREATE`. La consecuencia buena: un
  deploy verde de `pgm` SI garantiza que los 74 cuerpos parsean en Redshift.
- **Un literal mas largo que su columna es un `[REDSHIFT:112]`**, y
  `CREATE TABLE IF NOT EXISTS` lo esconde: si la tabla ya existe con la columna
  ancha de una version anterior, el `INSERT` pasa en DEV y falla en el primer
  despliegue sobre ambiente limpio. Encontrado asi con la evidencia de `R2-07`
  (688 caracteres contra `VARCHAR(500)`), que nunca llego a desplegarse.

## Lecciones numeradas (estaban dispersas en cabeceras)

| # | Leccion |
|---|---|
| #5 | `deploy.par` y `rollback.par` con paridad de lineas |
| #7 | Framework Batch: 6 params VARCHAR obligatorios |
| #9 | `.par` en UTF-8 sin BOM y en orden inverso |
| #10 | Redshift no soporta `DROP FUNCTION IF EXISTS`; usar firma exacta y asumir el fallo si no existe |
| #11 | Firma exacta del Framework Batch, en ese orden |
| #12 | Redshift no soporta `DROP PROCEDURE IF EXISTS` |
| #13 | `NONATOMIC` en toda la cadena de `CALL` |
| #14 | El `DROP` debe repetir la firma **exacta** del `CREATE`, incluido el `INOUT` |

*(#1-#4, #6 y #8 no estan citadas en ningun archivo del repo: se perdieron.)*

## Antes de empujar

```
./validar.sh
```
Chequea ASCII, BOM, `$$` y parentesis balanceados, simetria de los `.par`, que
toda entrada tenga su archivo, `WHERE` en `UPDATE`/`DELETE`, y `LISTAGG` con el
mismo `WITHIN GROUP` por `SELECT`. Sale distinto de cero si algo falla.

## Como responder en este proyecto

Corto, claro y contundente. Quien lee necesita decidir, no leer.

- **La conclusion primero**, en negrita. Luego la evidencia.
- **Tablas** en vez de prosa cuando hay mas de dos cosas que comparar.
- **Maximo 15 lineas**, salvo entregables (un plan, un informe, un documento).
- **Cita `archivo:linea`** al afirmar algo del codigo. Una afirmacion sin cita
  es una hipotesis, y hay que decir que lo es.
- No recapitular lo ya dicho. No narrar lo que se va a hacer: hacerlo y
  reportar.
- No enumerar opciones que no se van a tomar. Recomendar una.
- Nada de disculpas ni de rumiar errores propios: corregir en una linea y
  seguir.
- Un hallazgo son tres lineas: **que** es, **donde** esta, **que impacto**
  tiene. Si hay varios, tabla.

Y lo que mas importa en este proyecto: **si una afirmacion anterior resulta
falsa, corregirla en cuanto se sepa, sin preambulo.** Ha pasado ya con el gate
que se creia que tumbaba el build y no lo hacia.
