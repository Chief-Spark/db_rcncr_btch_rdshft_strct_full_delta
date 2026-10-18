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

**EL PIPELINE CORRE LA BATERIA DOS VECES Y EL BANCO UNA. CUARTO PUNTO CIEGO
(job DEV/DATABASE #412).** El ciclo controlado de Jenkins es
`RLLBCK_PRECHECK -> DDL_1 -> DPLY -> DDL_2 -> RLLBCK_FINAL -> DDL_3 -> compare
-> DPLY`: el **DPLY aparece dos veces** y la bateria entera corre dos veces
sobre el mismo cluster. Todo lo que una corrida escribe y el reset no borra
sobrevive de una pasada a la otra, de modo que **la primera sale verde y la
segunda falla**. El banco corre la bateria una sola vez y no ve nada.

Lo pago Novedades: `reset_mock.sql` -- que es el archivo **1 de deploy.par** --
no borraba una sola tabla suya. El FULL de la segunda pasada salio con
`bootstrap=f`, los DELTA siguientes leyeron el `MAX(watermark_nuevo)` de la
primera (`2026-06-15`) por encima del que ese FULL acababa de sembrar
(`2026-03-01`), la ventana por fecha se quedo vacia y `NOV-UB-12` lo cazo.

**La regla que queda: LO QUE UNA CORRIDA ESCRIBE, EL RESET LO BORRA**, y una
tabla de control nueva entra en `reset_mock.sql` **en el mismo commit que su
DDL**. Para reproducir a Jenkins en el banco hay que correr `fase dt` **dos
veces seguidas**; una sola pasada no prueba esto.

**Y el reset estaba DUPLICADO, que es lo que dejo que derivara.**
`run_reconocer_e2e_mock_full_delta.sql` lleva su propia copia en linea -- para
poder correr suelto -- y decia *"Mismo contenido que reset_mock.sql"* cuando ya
le faltaban el diccionario de via, el censo de escenarios, los siete
`mock_ord_*` y `cert_resultado`. Hoy las dos listas son identicas y asi hay que
mantenerlas: el `diff` de los `TRUNCATE` de los dos archivos tiene que salir
vacio.

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

**EL `[REDSHIFT:419]` NO SALE: ES DEL PIPELINE, NO DEL REPO.** Lo cierra una
prueba que no admite lectura alternativa: **STRCT desplego verde un dia y al
siguiente fallo identico, con el mismo paquete y sin un commit de por medio.**
Cuatro hipotesis mias cayeron por buscar la causa en el repo. Escalado a
DevSecOps. El paquete esta verificado contra el remoto de Bitbucket: 151
archivos bajo `deploy/redshift/SLCOPRBA-1353/`.

**EL CLUSTER DE DEV YA NO SE PAUSA: ESTA SIEMPRE ARRIBA (SLCOPRBA-1355).**
Hasta ahora esta seccion decia que se pausaba a diario sobre las 19:00 de
Bogota y que ahi terminaba la ventana de despliegue. **Ya no hay ventana**: se
puede lanzar a cualquier hora. Lo que sigue en pie es el dato historico, que
es lo unico que esa nota aportaba al 419: el #372, el #373 y el #374 se
lanzaron entre las 18:00 y las 19:00 **con el cluster arriba**, de modo que la
pausa nunca explico esos fallos.

**LO QUE SE COMPROBO SOBRE EL 419, Y LO QUE NO.**
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

## El ciclo GEO mock: que se certifica y que no (SLCOPRBA-1355)

**Los cinco criterios GEO estaban bloqueados por permisos, no por logica.** El
rol IAM `rcncr-batch-redshift-geo` no esta asociado al cluster DEV, de modo
que ni el `UNLOAD` escribe en S3 ni el `COPY` lee. Eso tumbaba CA-01 y dejaba
CA-02..CA-05 sin forma de ejercitarse.

**La salida fue sustituir el viaje a S3, no simular mal el resto.** Cuatro
piezas nuevas y un interruptor:

| Pieza | Que es |
|---|---|
| `s3_enabled` en `geo_config_mock` | vale `'0'` y hace que `sp_geo_exportar_insumo_mock` **omita** el `UNLOAD`. El Lote queda en `exportado` en vez de `fallido`, y **CA-01 se desbloquea solo**: el evaluador ya tenia `WHEN lc.estado = 'exportado' THEN 'PASSED'` |
| `bdm_stage.mock_geo_respuesta` | **es el archivo de vuelta**, con las mismas 32 columnas crudas del contrato |
| `sp_geo_simular_arcgis_mock` | el doble del sistema EXTERNO. No es un port, y el nombre lo dice |
| `sp_geo_cargar_georreferenciacion_mock` | espejo del cargador. **Difiere en UNA sentencia**: el `COPY` pasa a `INSERT ... SELECT` |
| `sp_geo_reenganchar_r3_mock` | espejo del reenganche. Solo cambian tres nombres |

El alcance del tablero paso de **45 a 50** criterios.

**CERRADO EN REDSHIFT REAL: job DEV/DATABASE #402, tablero en 50 de 50 y
cero pendientes.** Los cinco pasaron con estos numeros: `CA-01` Lote
`exportado` con 103.000 candidatos; `CA-02` 14.000 geocodificadas y 89.000
`U`; `CA-03` Lote `cargado` con `fase_fallo` y `ultimo_error` en NULL;
`CA-04` 14.000 aptas entraron a la Regla 3; `CA-05` cero aptas y Regla 3
omitida sin excepcion. Y lo que mas importaba: **`tipo 3 = 5000 contra 5000`
antes del ciclo**, con `R3-01..R3-10` intactos.

**Con eso, GEO ENTRO EN EL GATE.** `sp_cert_asercion_final.sql` ya no lleva
`bloque <> 'GEO'`: un FAILED en cualquiera de los cinco tumba el build.

**Y SE RETIRO EL BLOQUE QUE LOS DABA POR BLOQUEADOS.**
`sp_cert_evaluar_criterios_mock` insertaba `CA-02..CA-05` como BLOQUEADO en
cada fase. Con el ciclo mock certificandolos, esas filas eran falsas: el
titular daba PASSED y el pivote por fase seguia diciendo BLOQUEADO en el
mismo informe. **Un tablero que se contradice a si mismo no se cree ni cuando
acierta.** Ahora los escribe solo `sp_cert_geo_mock`, con `modo = 'GEO'`, y
el pivote tiene su columna `geo` -- columna aparte, no una quinta fase, porque
el ciclo GEO corre una vez y no por fase.

**LO QUE SIGUE SIN CERTIFICARSE, y hay que repetirlo cada vez que alguien lea
el 50/50:** que el `UNLOAD` escriba de verdad en S3 y que el `COPY` lo lea.
Son dos sentencias cuyo riesgo es de permisos. Todo lo demas -- gates de
estado y de conteo, conciliacion de tipos, los tres rechazos, los tres
`UPDATE` por Status y las dos ramas del reenganche -- es el mismo SQL.

**EL CABLEADO YA EXISTIA Y NADIE LO SABIA.**
`02b_vistas_insumo_mock.sql` define `v_mock_ubicacion_estandarizada` con un
`COALESCE` de la latitud propia con la de `geo_atributos_mock` por `LEFT
JOIN`. O sea que lo que el cargador mock escribe entra en la Regla 3 por el
mismo camino que en produccion. Faltaba quien escribiera, no por donde.

**LA TRAMPA QUE CASI CUESTA EL TABLERO DE UNIFICACION.** Un simulador que
geocodificara las ~103.000 ubicaciones candidatas le daria a la Regla 3
coordenadas que antes no tenia, apareceria con pares nuevos y moveria los
conteos exactos de `R3-02`..`R3-10`, que estan en PASSED. Certificar GEO
rompiendo Unificacion no es certificar. Por eso el modo `'M'` **solo devuelve
geocodificada la ubicacion que YA tenia coordenadas en el mock, y con esas
mismas coordenadas**. El insumo de la Regla 3 queda byte a byte igual.

**Y UNA DE ORDEN:** el ciclo GEO mock corre **entre la convergencia y el
tablero**, nunca dentro del e2e. El cargador mueve el Lote a `cargado` y CA-01
exige verlo en `exportado`: metido dentro, CA-01 se caeria por un efecto de
orden y no por un defecto.

**Al generar un espejo por sustitucion, anclar el corte de cabecera a
principio de linea.** Un `t.index('CREATE OR REPLACE PROCEDURE')` engancha la
primera aparicion, que esta **dentro de un comentario** (`-- Objeto en
bdm_datos; idempotente (CREATE OR REPLACE PROCEDURE).`), parte la linea en dos
y deja un `)` suelto. Lo caza el chequeo de parentesis de `validar.sh`, no el
de sintaxis.

`rollback.par` es el reverso exacto de `deploy.par`, modulo el prefijo
`NN_rollback_` en los archivos numerados. Todo archivo sin prefijo numerico
conserva su nombre en `RevSQL/`.

## Novedades (P0035): el tercer proceso, arrancado por Ubicacion

**Novedades NO depende de las Fases 1-3 del Ordenamiento.** Buscados
`MATERIALIZA`, `CTA_ATRIBUTOS`, `CTA_TOTALES`, `CONCAT_ATRIBUTOS`,
`CALC_UBICACIONES`, `UBIC_DIRECCIONES` y `FINAL_UBIC` en los 406 KB de
`Novedad.sql`: **cero coincidencias**. Lo unico que toma del Ordenamiento es
`ORDEN_PRIORIDAD` (`Novedad.sql:8347`), que `sp_ordenamiento_consolidacion_edf`
ya escribe. Eso es lo que desbloqueo la vertiente: no faltaba F1-F3.

El legado son **diez** SPs en `Novedad.sql`, no nueve -- existe tambien
`PRO_Novedad_Linea_PICalculados_Ctls` (`:4066`), que el `111.BTQ` no invoca y
el `140.BTQ` si -- mas cuatro scripts de malla. `Mosaic` queda fuera por
decision legal, y **no toca Ubicacion**: su predicado aparece una sola vez en
todo el archivo, en `:2482`, dentro de `Info_Basica`.

**SE EMPIEZA POR UBICACION PORQUE ES PRODUCTOR PURO.** No lee ninguna temporal
ajena y cinco de los demas dependen de sus dos salidas: `Catalogo` (`:288`),
`Contact` (`:615`), `Historial` (`:1721`), `PICalculados_Ctls` (`:4808`) y
`Ubi_Agregada`, que las usa en once puntos. **Por eso las dos salidas son
contrato publico y su DDL esta pinada en `strct`**: `stg_nov_ubica_etapa_9`
con 42 columnas y `stg_nov_ubica_etapa_2` con 15. Un `CTAS` dejaria que el
tipo lo infiriera la consulta y el contrato cambiaria sin avisar.

**EL SP NO INSERTA EN `MAT_INFO_UBICACION`, y conviene saberlo antes de
buscarlo.** Termina en las dos etapas; la carga la hacen los TPT:
`etapa_9 -> Vstg_Reconocer_Info_Ubica (120.TPT:86-176) -> WHERE Severidad <> -1
(130.TPT:215) -> UPSERT (130.TPT:573-703)`. Por eso el port son dos piezas.

| Pieza | Donde |
|---|---|
| Contratos, tabla final y control | `30_ddl_novedades.sql`, `30b` mock, `31_ddl_nov_control.sql`, `31b` mock |
| Tablero de 32 criterios | `33_ddl_cert_criterios_nov.sql` |
| El port y su espejo | `sp_novedades_ubicacion_{edf,mock}.sql` |
| La pieza de los TPT | `sp_novedades_cargar_mat_ubicacion_{edf,mock}.sql` |
| Control y orquestador | `sp_nov_control_*`, `sp_novedades_ciclo_edf.sql`, `sp_novedades_mock_ciclo.sql` |
| Evaluador y tablero | `sp_cert_evaluar_criterios_nov_mock.sql`, `validacion_certificacion_nov.sql` |
| Lo que hay que pedir | `docs/PETICION_CATALOGOS_NOVEDADES.md` |

**EL CATALOGO DE CRITERIOS SALE DEL CODIGO, NO DE UN DOCUMENTO.** Unificacion
y Ordenamiento tienen su RF; Novedades no. Cada criterio cita la linea del
legado de la que sale, y si algun dia aparece un documento funcional hay que
revisarlo contra el.

**SEIS TRAMPAS DEL LEGADO, LOCALIZADAS Y PORTADAS LITERALES:**

| Que | Donde |
|---|---|
| `FLAG_OP` referencia el alias de una columna definida **dos lineas despues**. Teradata lo resuelve, **Redshift no**: hay que repetir el `CASE` | `Novedad.sql:8392-8396` |
| `V_CARGA_FULL` lee `REC_MTDAT.LOG_TD` con el esquema **hardcodeado**, ignorando el parametro | `:7366-7372` |
| Centinelas de nulo inconsistentes: `''` y `'-1'` en la etapa 9, `'SV'` en las agregaciones, y la etapa 2 une por igualdad en esas tres columnas | `:8354`, `:8374`, `:8502-8504`, `:8649-8651` |
| La homologacion de fuente **jamas se aplica**: el `COALESCE` interno nunca da NULL, asi que todo sale `'CAM'` | `:8635` |
| `TMP_UBICA_ETAPA_0` es **codigo muerto**: se crea, se analiza y se borra sin que nadie la lea. No se porta | `:7514`, `:8723` |
| **`FLAG_OP = 'E'` es codigo muerto, y con el la unica via de BAJA.** La etapa 1 anti-une `V_BLOQUEO` y la etapa 9 vuelve a unirla por la MISMA llave para preguntar por `FECHA_BLOQUEO`: lo que sobrevivio no esta en la tabla, asi que nunca da TRUE | `:7590-7594` contra `:8393`, `:8416` |

**LA SEXTA ARRASTRA AL TPT Y CAMBIA DOS CRITERIOS.** `Severidad = 2` -- el
borrado -- sale UNICAMENTE de `WHEN STG.FLAG_OP = 'E' THEN 2`
(`120.TPT:163`), de modo que **el UPSERT de `130.TPT` nunca borra una fila: el
AS-IS solo inserta y actualiza.** `NOV-UB-13` y `NOV-UB-15` decian "el mock no
siembra ubicaciones bloqueadas", como si faltara un arquetipo. **Era falso, y
ningun arquetipo lo desbloquea**: verifican una rama que el legado no puede
tomar. Ahora exigen cero bajas, que es la paridad real, y estan en PASSED.

**Y DE PASO CORRIGIO UNA DIVERGENCIA NUESTRA.** Nuestro filtro de la etapa 1
era `COALESCE(rpu.bloqueado, 0) = 0`, que excluye la FILA; el legado excluye el
ID entero. No es lo mismo porque **`cod_dw_persona_ubic` NO es unico en el
datashare** (568.657 filas para 142.067 ids, ~4:1): una hermana sin bloquear
pasaba y el `MAX(bloqueado)` de la etapa 9 le ponia `'E'`. Eramos mas anchos
que el legado. Hoy es un anti-join, igual que el original. **En el mock no
cambia nada**, porque alli el id es unico por construccion.

**Y CINCO COLUMNAS QUE EL LEGADO DEJA EN BLANCO POR ESA RUTA**, que no son un
defecto del port: `REPORTADO_DESDE`, `ULTIMO_REPORTE`, `FUENTE`,
`NUMERO_REPORTES` y `NUMERO_ENTIDADES` salen NULL y 0 **literales**
(`:8358-8363`). Sus valores reales viven en la etapa 2, que esa ruta no
consume.

**DECISION CERRADA (SLCOPRBA-1355): esas cinco NO se pueblan, y el `'CAM'` de
la fuente NO se corrige.** Se reproduce el legado tal cual. Dejan de ser
divergencias abiertas: son el comportamiento esperado, y `NOV-UB-09` verifica
que SIGAN en blanco. No volver a abrirlas como si fueran un defecto.

**EL CONTROL DE DELTA NO ES UN PORT: ES DISENO NUEVO, y el motivo es que el
del legado esta INOPERATIVO.** `111.BTQ:64-65` hace
`DELETE FROM LOG_TD WHERE Nombre_Proceso = 'P0035_Extractor_Novedades'` **al
inicio de cada corrida**, y el watermark que los SP leen es
`MAX(FECHA_HORA_FIN)` de esa misma tabla (`Novedad.sql:242-247`): se
autodestruye, devuelve NULL y **toda corrida del AS-IS es FULL**. Ademas
`140.BTQ` declara `FncUpdate_LogTD` (`:47-61`) y **no la llama** (`:853-858`).
`nov_control` se construye sobre el patron de `unif_control`, que si funciona.

**UN FAN-OUT QUE SE PAGO Y NO HAY QUE VOLVER A PAGAR.** Derivar la clase de la
ubicacion de `v_xpm_contacto_canal` **multiplica la salida por tres**: esa
vista tiene una fila por canal y no una por ubicacion. Medido en el banco:
219.000 filas para 73.000 ids. La clase sale del tipo de la **propia**
ubicacion, nunca de un join. Y en nuestro modelo **toda fila de RPU es una
direccion**: los telefonos, celulares y correos viven en `contacto_canal`, que
es otra tabla y otro grano, de modo que portar las clases TEL, CEL y EMAIL
exige traerla con `UNION ALL` como filas adicionales.

**`bdm_stage.mock_ord_prioridad` NO LA LLENA NADIE.** Esta declarada en
`05_ddl_ordenamiento_mock.sql` y la trunca `reset_mock.sql`, pero no hay un
solo `INSERT` contra ella en los tres repos, de modo que
`v_mock_rpu_post_unificacion.orden_prioridad` es **NULL siempre**. El
Ordenamiento mock escribe en `bdm_datos.rpu_orden_prioridad`, la tabla REAL,
porque el mock reutiliza `sp_ordenamiento_consolidacion_edf`. Novedades lee de
ahi en las dos vias, y esa es la unica linea que el espejo mock no sustituye.
Defecto preexistente de esa vista, anotado y no corregido.

**ORDEN EN LA BATERIA:** Novedades corre **despues** del Ordenamiento de cada
fase, porque la etapa 1 filtra por orden de prioridad no nulo (`:7593`). Al
reves saldria vacio por un efecto de secuencia y no por un defecto -- la misma
leccion que el ciclo GEO.

**NOVEDADES YA ESTA EN EL GATE (job DEV/DATABASE #409).** Se cumplio la
condicion que esta seccion exigia -- primero verde en Redshift real, el gate en
el commit siguiente --: el #409 cerro los quince `NOV-UB-01..15` con cero
FAILED. `sp_cert_asercion_final` tiene ya su rama `NOVEDADES` y
`run_cert_asercion_final.sql` **lo llama DOS VECES**, con `'UNIFICACION'` y con
`'NOVEDADES'`. No se cambio a `'TODO'` a proposito: eso encenderia Ordenamiento
de rebote, que es otra decision. Un FAILED en cualquier `NOV-UB` tumba el build.

**EL #412 LO CONFIRMO Y DE PASO COBRO EL PRIMER PRECIO DEL GATE.** La primera
pasada de DPLY salio entera en verde -- Unificacion `50|50|0`, Novedades
`15|14|1`, los dos `CERTIFICACION OK` -- y **la segunda tumbo el build** con
`NOV-UB-12` en FAILED. No era un defecto del port: era que `reset_mock.sql` no
borraba nada de Novedades y la segunda pasada heredaba el watermark de la
primera. Detalle y la regla que deja, en la seccion del banco.

**El criterio no se equivoco: la corrida de verdad no habia mirado la ventana.**
Es justo lo que el desglose por rama se anadio a detectar, y lo detecto el mismo
dia que entro al gate.

**Lo que NO se cambio, y es deliberado:** el `MAX(watermark_nuevo)` del
orquestador (`sp_novedades_ciclo_edf.sql:57-59`). Unificacion lee exactamente
igual (`16_sp_unificacion_ciclo.sql:162`) y esta certificada; dos procesos que
acotan por la misma columna no pueden tener dos semanticas de watermark. Y en
produccion el sintoma no existe: un FULL solo baja la frontera si el dato de
encima desaparecio, y ahi nada borra filas -- en la bateria desaparece porque el
reset borra la mutacion a proposito. Queda anotado como riesgo latente
compartido, no como trabajo abierto.

**ACTIVIDAD ECONOMICA YA ESTA CERTIFICADA: diez criterios `NOV-AE-01..10`.**
Ocho por consulta y dos en BLOQUEADO -- `NOV-AE-06` por
`V_ACTIVIDAD_ECONO_CIIU` y `NOV-AE-07` por `V_Hom_Tip_Ident_Linea`, los dos
catalogos que no se entregaron. **Entraron al gate sin tocarlo**: la rama
`NOVEDADES` de `sp_cert_asercion_final` cuenta los FAILED de **todo**
`cert_resultado_nov`, sin filtrar por bloque, de modo que un FAILED en
cualquier `NOV-AE` tumba el build desde el primer despliegue. El alcance del
tablero paso de 15 a 23 criterios y el catalogo de 32 a 41.

**Y `NOV-HIS-01` SALIO DEL CATALOGO: era una nota envejecida.** Decia
*"PRO_Novedad_Linea_Historial no esta portado"* y ese SP es justo el que
produce `MAT_INFO_ACTIVIDAD_ECONOMICA` -- la nomenclatura del legado esta
cruzada y manda el `120.TPT`, no el nombre. Los dominios no portados pasan de
siete a seis. Misma moraleja que la del grano de TEL: **una seccion que afirma
que algo falta envejece peor que el codigo.**

**LA LECCION, Y ES LA QUE VALE PARA CUALQUIER VENTANA: UN DELTA EN CERO NO
PRUEBA QUE NO HAYA CAMBIOS.** El #413 mostro `relaciones_entrada = 0` en los
dos DELTA de ACTECO y nadie lo miraba. No era un defecto del port: **toda
`fecha_reporte` del mock estaba en febrero** y el watermark es `2026-03-01`,
asi que la rama por fecha de
`fecha_reporte >= watermark OR fecha IS NULL`
(`sp_novedades_actividad_economica_edf.sql:149-151`) no tenia nada que
recoger. Antes de dar por buena una rama vacia hay que comparar el **rango del
dato** con el watermark.

**Y AL SEMBRAR UNA FECHA NUEVA, ELEGIR UN ARQUETIPO CUYO CRITERIO NO DEPENDA DE
ELLA.** Se movieron los ARQ 16..20 a `2026-04-10`, que son el **empate puro**
de la Regla 1 (`R1-08`) y deciden por numero de entidades reportantes. Cambia
el VALOR de la fecha, no el numero de filas ni el de suscriptores distintos:
`numero_entidades_reportan` no se mueve, y como las dos direcciones de cada
persona se mueven juntas, el empate de score del Ordenamiento tampoco se rompe.
Medido en el banco: Unificacion `50/50/0`, Ordenamiento `45/44/1` y
`grupos_con_empate` identicos (CEL 100 / DIR 200 / EMA 0 / TEL 0 con N=100).
**Radio de impacto cero**, que era el riesgo a descartar antes de tocar nada.

**Y EL #409 DEJO UN DEFECTO QUE EL TABLERO NO VEIA: EL WATERMARK SALIA DEL
RELOJ.** El orquestador cerraba la corrida pasando `v_fecha` como watermark
nuevo, y `v_fecha` es `CURRENT_DATE` cuando el Framework no manda FECHA. Con la
frontera en hoy y las relaciones fechadas en el pasado, el DELTA solo recogia
la rama `fecha IS NULL`: **daba PASSED sin haber mirado la ventana**, y la
mutacion de la fase 3 (fecha `2026-06-15`) era invisible.

Corregido copiando el bloque de `16_sp_unificacion_ciclo.sql:375-392`:
`MAX(fecha_relacion_persona_ubicaci)` del universo procesado, siembra en FULL,
`GREATEST` en DELTA. **La leccion vale para todo lo que acote por fecha: el
watermark sale del MAX del DATO, nunca de la fecha de ejecucion.** Y
`NOV-UB-12` ya no cuenta cambios a secas -- desglosa cuantos entran por fecha y
cuantos por fecha nula, y exige que los primeros sean > 0. Un criterio que no
separa las dos ramas deja pasar justo esto.

**LO QUE FALTA, Y ES PETICION, NO CODIGO:** nueve catalogos que el SP consume
y no se entregaron (`TIPO`, `ZONA`, `TIPO_IDENTIFICACION`, `INDICATIVO` y
`TIPO_CUENTA` salen NULL por eso), las cuatro columnas del contrato GEO sin
pinar (`BARRIO`, `ESTRATO`, `LOCALIDAD`, `CODIGO_POSTAL`), y el reexport de
`V_Geografia` y `V_Cod_Entrega_Dato`, que **llegaron truncados a 1000 filas
exactas**. Detalle en `docs/PETICION_CATALOGOS_NOVEDADES.md`.

**UN RIESGO HEREDADO QUE TOCA LO YA DESPLEGADO.** El mapeo mide que `id` no es
unico por fila en `xpm_location_val_contactinformations`: 568.657 filas contra
142.067 `id` distintos, ~4:1. Nuestras vistas asignan
`cod_dw_persona_ubic = ci.id`, que colapsa datos de contacto; la llave deberia
derivarse de `(id, index)`. **Afecta a Unificacion, que ya esta desplegada y
certificada.** No se toca aqui: se anota y se eleva.

## Convenciones de codigo

- **UTF-8 sin BOM. ASCII sin acentos**, a proposito, en todo el repo.
  **El paquete esta limpio y el chequeo 2 de `validar.sh` ya lo EXIGE entero**
  (SLCOPRBA-1355: 58 archivos y 157 lineas, todas comentarios -- 9 en strct,
  37 en pgm, 12 en dt). Dos cosas que conviene saber si se vuelve a tocar:
  **`docs/` y `README.md` quedan fuera a proposito**, porque son prosa en
  castellano y ahi los acentos son correctos; y **habia mojibake** (UTF-8 ya
  leido una vez como cp1252) en `02_vistas_insumo_edf_views.sql`, que hay que
  **decodificar con `cp1252` ANTES de transliterar**. Con `latin-1` la
  conversion revienta en silencio en cuanto la linea lleva un caracter
  tipografico -- una flecha, una raya o una comilla curva, que no existen en
  latin-1 --, la reparacion se salta y el acento acaba convertido en `A3`.
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
- **Subconsulta escalar en la proyeccion, y `EXISTS` correlacionado dentro de
  ella: Redshift las RECHAZA**, no es que sean poco fiables:
  `XX000: This type of correlated subquery pattern is not supported due to
  internal error`. Y el error salta en EJECUCION, no al crear el
  procedimiento. **TERCER PUNTO CIEGO DEL BANCO**, hermano de `DELTA` y del
  `RAISE`: PostgreSQL las ejecuta sin una queja, de modo que la bateria local
  dio verde y el tablero salio 12 de 15 -- y Redshift tumbo el job
  DEV/DATABASE #407 en `NOV-UB-14`. La salida es **materializar los conteos**
  en una tabla de apoyo y unirla con `CROSS JOIN`; un `LEFT JOIN` contra un
  `SELECT DISTINCT` sustituye al `EXISTS`. Es lo que ya hacia el evaluador del
  Ordenamiento y lo que no aplique aqui.
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
toda entrada tenga su archivo, `WHERE` en `UPDATE`/`DELETE`, `LISTAGG` con el
mismo `WITHIN GROUP` por `SELECT`, las reservadas de Redshift como
identificador (8), los `RAISE` con expresiones (9) y **las subconsultas en la
lista de un `SELECT` (10)**. Sale distinto de cero si algo falla.

El 10 cierra la terna de los puntos ciegos del banco: `DELTA` -> 8, `RAISE` ->
9, subconsulta correlacionada en la proyeccion -> 10. **Es AVISO y no falla**:
una subconsulta no correlacionada ahi es legitima y se usa. Lleva la cuenta de
parentesis y solo mira las que abren entre un `SELECT` y su `FROM`, de modo que
`FROM (SELECT ...)`, `JOIN (SELECT ...)` e `IN (SELECT ...)` del `WHERE` no
avisan.

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
