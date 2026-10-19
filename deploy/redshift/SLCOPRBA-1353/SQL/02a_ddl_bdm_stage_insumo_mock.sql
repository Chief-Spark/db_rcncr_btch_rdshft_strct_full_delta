-- ============================================================
-- 02a_ddl_bdm_stage_insumo_mock.sql
-- Tablas base bdm_stage que alimentan v_mock_* (suite mock unif).
-- CREATE IF NOT EXISTS - no inventa datos; el seed opcional va en dt.
-- UTF-8 sin BOM. Nunca GRANT TO PUBLIC.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bdm_stage;

-- SLCOPRBA-1355: se agrega la columna BLOQUEADO al contrato de la tabla mock.
--
-- POR QUE DROP + CREATE Y NO ALTER: Redshift no admite
-- ADD COLUMN IF NOT EXISTS, y CREATE TABLE IF NOT EXISTS no altera una tabla
-- que ya existe, de modo que un ALTER plano funcionaria la primera vez y
-- romperia el despliegue en todos los siguientes con "column already exists".
-- Recrear es seguro AQUI y solo aqui porque esta tabla es scaffolding de mock:
-- no guarda nada que no regenere el seed. reset_mock la trunca y
-- seed_mock_matriz la repuebla completa en cada corrida de la bateria.
--
-- PARA QUE SIRVE LA COLUMNA: los insumos de R1 y R2 filtran
-- COALESCE(rpu.bloqueado, 0) = 0, que es el filtro de estado del legado
-- Teradata. Sin la columna ese predicado era siempre verdadero y los criterios
-- R1-06 y G-04 no se podian afirmar: el codigo excluye bloqueadas, pero no
-- habia ni una bloqueada en el universo. El arquetipo ARQ 59 la siembra.
DROP TABLE IF EXISTS bdm_stage.relacion_persona_ubicacion;

CREATE TABLE bdm_stage.relacion_persona_ubicacion (
  cod_dw_persona_ubic            BIGINT,
  id_buro_persona                BIGINT,
  cod_pin_persona                BIGINT,
  cod_dw_ubic                    BIGINT,
  cod_dw_direccion_fisica        BIGINT,
  cod_dw_tipo_ubicacion_dir      INTEGER,
  ind_unificacion                INTEGER,
  orden_prioridad                INTEGER,
  fecha_relacion_persona_ubicaci DATE,
  lote                           INTEGER,
  cod_tipo_ident_fte             VARCHAR(20),
  bloqueado                      SMALLINT    -- 1 = reclamacion del titular
)
DISTSTYLE KEY DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona, cod_dw_persona_ubic);

-- SLCOPRBA-1354: se anaden municipio y departamento. Los necesitan dos
-- consumidores: el Insumo_GEO mock (columnas MUNICIPIO / DEPARTAMENTO del
-- UNLOAD, Req 2.3) y la vista v_mock_contacto_direccion, espejo de
-- v_xpm_contacto_direccion, que las expone para el Ordenamiento mock.
-- DROP + CREATE porque CREATE TABLE IF NOT EXISTS no anade columnas a una tabla
-- ya existente y Redshift no admite ALTER TABLE ADD COLUMN IF NOT EXISTS. Es
-- una tabla de semillas mock: no hay dato productivo que perder.
DROP TABLE IF EXISTS bdm_stage.ubicacion_estandarizada;
CREATE TABLE IF NOT EXISTS bdm_stage.ubicacion_estandarizada (
  cod_dw_ubic       BIGINT,
  texto_ubicacion   VARCHAR(500),
  cod_dw_ciudad     INTEGER,
  municipio         VARCHAR(100),
  departamento      VARCHAR(100),
  latitud           DECIMAL(12,8),
  longitud          DECIMAL(12,8),
  -- SLCOPRBA-1355: tipo de via de la ubicacion, el criterio de entrada de la
  -- Regla 3. Dominio del catalogo Tipo_Via del legado (Tipo_Via.txt):
  -- 'Via', 'MZ' (Manzana), 'Rural', 'Descriptiva'. La vista mock lo exponia
  -- como CAST(NULL AS VARCHAR(50)), de modo que el filtro de R3 no podia
  -- afirmarse ni negarse con dato.
  -- En la via REAL el equivalente es standardizedtipo del datashare, que
  -- v_xpm_ubicacion_estandarizada ya expone como tipo_ubicacion; el nombre de
  -- la columna se mantiene para que las dos vistas sigan siendo espejo.
  tipo_ubicacion    VARCHAR(50)
)
DISTSTYLE KEY DISTKEY (cod_dw_ubic)
SORTKEY (cod_dw_ubic);

CREATE TABLE IF NOT EXISTS bdm_stage.direccion_fisica (
  cod_dw_direccion_fisica BIGINT,
  complemento             VARCHAR(200),
  -- SLCOPRBA-1355: los cuatro componentes de via, que son TODO el criterio de
  -- la Regla 3. Faltaban en la tabla y la vista mock los exponia como
  -- CAST(NULL AS ...) en su rama de bdm_stage, de modo que R3 no tenia con que
  -- comparar: el puerto anterior los suplia troceando texto_ubicacion con
  -- SPLIT_PART, una heuristica sobre el texto en vez del dato estandarizado.
  -- Tipos IDENTICOS a bdm_datos.direccion_fisica_generada_mock, que es la otra
  -- rama del UNION ALL de la vista: un desajuste no lo avisa el despliegue
  -- (WITH NO SCHEMA BINDING), solo la primera consulta.
  tipo_via_principal      VARCHAR(50),
  via_principal           VARCHAR(100),
  via_generadora          VARCHAR(100),
  numero_puerta           VARCHAR(50),
  cod_dw_ubic             BIGINT,
  generada_enriquecida    INTEGER
)
DISTSTYLE KEY DISTKEY (cod_dw_direccion_fisica)
SORTKEY (cod_dw_direccion_fisica);

-- SLCOPRBA-1355: gana cod_suscriptor, espejo de la columna que
-- v_xpm_reporte_relacion_persona_ubica expone en crudo. DROP + CREATE porque
-- CREATE TABLE IF NOT EXISTS no anade columnas a una tabla ya existente.
DROP TABLE IF EXISTS bdm_stage.reporte_relacion_persona_ubica;
CREATE TABLE IF NOT EXISTS bdm_stage.reporte_relacion_persona_ubica (
  cod_dw_persona_ubic BIGINT,
  id_buro_suscriptor  INTEGER,
  cod_suscriptor      VARCHAR(20),
  fecha_reporte       DATE
)
DISTSTYLE KEY DISTKEY (cod_dw_persona_ubic)
SORTKEY (cod_dw_persona_ubic);

CREATE TABLE IF NOT EXISTS bdm_stage.ciiu_persona (
  id_buro_persona         BIGINT,
  cod_act_econo_ciiu_fte  VARCHAR(20)
)
DISTSTYLE KEY DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona);

CREATE TABLE IF NOT EXISTS bdm_stage.tipo_ubicacion_dir (
  cod_dw_tipo_ubicacion_dir      INTEGER,
  descripcion_tipo_ubicacion_dir VARCHAR(20)
)
DISTSTYLE ALL;

CREATE TABLE IF NOT EXISTS bdm_stage.nomenclatura (
  nomenclatura      VARCHAR(100),
  nivel_complemento INTEGER
)
DISTSTYLE ALL;

-- SLCOPRBA-1354 (M2): +nomen y +valor para igualar a
-- bdm_datos.diccionario_complementos. Las necesita la descomposicion del
-- complemento por componentes del motor: el legado une
-- NOMENCLATURA.NOMENCLATURA = DICCIONARIO_COMPLEMENTOS.Nomen para obtener el
-- Nivel_Complemento de cada componente. Sin 'nomen' la via mock no podria
-- ejercitar esa descomposicion y dejaria de ser espejo del real.
-- DROP + CREATE: tabla de semillas mock, sin dato productivo que perder.
-- ------------------------------------------------------------
-- bdm_stage.diccionario_via -- SLCOPRBA-1355
-- Diccionario de Via de la Regla 3. Puerto de REC_STAGE.DICCIONARIO_VIA
-- (P0021_UNIFICACION_111.BTQ). Es el desempate del subcaso "las dos
-- direcciones tienen coordenadas": gana la que mas se ha reportado
-- historicamente.
--
-- DOS TIPOS EN LA MISMA TABLA, uno por escenario de emparejamiento:
--   'Via_Generadora'  llave = tipo_via_principal + via_principal + numero_puerta
--                     valor = via_generadora        (lo que varia en el esc 1)
--   'Numero_Puerta'   llave = tipo_via_principal + via_principal + via_generadora
--                     valor = numero_puerta         (lo que varia en el esc 2)
--
-- La columna del valor se llama 'valor' y no 'via_generadora'. En el legado es
-- una sola columna llamada Via_Generadora que para TIPO='Numero_Puerta' guarda
-- un numero de puerta: un nombre que miente en la mitad de las filas. Nada
-- fuera del diccionario la lee, asi que renombrarla no cambia comportamiento y
-- quita la trampa.
--
-- El conteo es HISTORICO y NO por persona: cuenta reportes sobre toda la
-- poblacion que comparte ese texto_ubicacion, igual que el legado (el join del
-- constructor es por texto_ubicacion, no por id_buro_persona).
-- ------------------------------------------------------------
DROP TABLE IF EXISTS bdm_stage.diccionario_via;
CREATE TABLE IF NOT EXISTS bdm_stage.diccionario_via (
  tipo             VARCHAR(20)  NOT NULL,   -- 'Via_Generadora' | 'Numero_Puerta'
  llave            VARCHAR(300) NOT NULL,   -- los dos componentes FIJOS del escenario
  valor            VARCHAR(100),            -- el componente que VARIA
  cod_dw_municipio INTEGER,
  conteo           BIGINT
)
DISTSTYLE KEY DISTKEY (llave)
SORTKEY (tipo, llave, valor);

DROP TABLE IF EXISTS bdm_stage.diccionario_complementos;
CREATE TABLE IF NOT EXISTS bdm_stage.diccionario_complementos (
  id_buro_persona BIGINT,
  cod_dw_ubic     BIGINT,
  nomenclatura    VARCHAR(100),
  nomen           VARCHAR(10),
  valor           VARCHAR(50),
  frecuencia      INTEGER
)
DISTSTYLE KEY DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona, cod_dw_ubic);

-- SLCOPRBA-1355: contactos de canal TEL / CEL / EMA para el Ordenamiento mock.
-- Espejo de la fuente de bdm_tempo.v_xpm_contacto_canal. Sin esta tabla el
-- Ordenamiento mock solo podria puntuar el canal DIR y los criterios de
-- aceptacion que exigen scores en TEL/CEL/EMA no tendrian como cumplirse.
-- contact_type sigue la codificacion del datashare: '4','5','8' = telefono fijo,
-- '9' = celular; el resto se interpreta como correo en el insumo EMA.
-- SLCOPRBA-1355: se anade cod_tipo_cta_fte, espejo de la columna
-- accounttype de xpm_location que v_xpm_contacto_canal ya expone.
-- DROP + CREATE porque CREATE TABLE IF NOT EXISTS no anade columnas a una
-- tabla ya existente y Redshift no admite ALTER TABLE ADD COLUMN IF EXISTS.
-- Es una tabla de semillas mock: no hay dato productivo que perder.
DROP TABLE IF EXISTS bdm_stage.contacto_canal;
CREATE TABLE IF NOT EXISTS bdm_stage.contacto_canal (
  cod_dw_persona_ubic     BIGINT,
  id_buro_persona         BIGINT,
  cod_pin_persona         BIGINT,
  contact_type            VARCHAR(10),
  valor_contacto          VARCHAR(200),
  texto_ubicacion_vinculo VARCHAR(500),
  cod_dane_ciudad         INTEGER,
  fecha_contacto          DATE,
  id_buro_suscriptor      INTEGER,
  cod_tipo_cta_fte        VARCHAR(20),
  cod_suscriptor          VARCHAR(20)
)
DISTSTYLE KEY DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona, contact_type);

-- Catalogo minimo tipos RES/LAB/CRR (ids tipicos de suite mock)
DELETE FROM bdm_stage.tipo_ubicacion_dir
 WHERE cod_dw_tipo_ubicacion_dir IN (1, 2, 3);

INSERT INTO bdm_stage.tipo_ubicacion_dir (cod_dw_tipo_ubicacion_dir, descripcion_tipo_ubicacion_dir)
VALUES
  (1, 'RES'),
  (2, 'LAB'),
  (3, 'CRR');


-- ============================================================
-- SLCOPRBA-1355 -- SEMILLAS DE LA FASE 2 (Atributos de Cuenta)
--
-- POR QUE EXISTEN. El clasificador Portafolio de F2-05
-- (PRO_ORD_CTA_TOTALES_PERSONAS_2.sql:304-375) es un CASE anidado de 179
-- lineas que consume NUEVE columnas, y de ellas nuestro modelo solo tenia
-- cod_suscriptor. Estas dos tablas son las otras ocho.
--
-- LOS NOMBRES SON LOS DEL LEGADO, no los del datashare. Es la decision que se
-- tomo al planificar F2: asi el CASE se copia literal y no hay una traduccion
-- de columnas de por medio donde equivocarse.
--
-- EL COMPORTAMIENTO ACTIVO Y EL PASIVO VAN EN UNA SOLA TABLA. El legado los
-- tiene en dos (STG_COMPORTAMIENTO_CTA_ACTIVO y _PASIVO) y los lee con dos
-- LEFT JOIN para derivar Flag_Comp_Cta_Activo y _Pasivo como simple
-- "existe fila" (:290-297). Una tabla con una columna que los distinga da
-- exactamente las mismas dos banderas y evita duplicar la semilla.
--
-- DROP + CREATE como las demas de este archivo: CREATE TABLE IF NOT EXISTS no
-- anade columnas a una tabla ya existente y Redshift no admite
-- ALTER TABLE ADD COLUMN IF NOT EXISTS. Son semillas: no hay dato productivo.
-- ============================================================

DROP TABLE IF EXISTS bdm_stage.mock_cuenta;

CREATE TABLE bdm_stage.mock_cuenta (
  cod_dw_cta                   BIGINT,
  id_buro_persona              BIGINT,
  cod_pin_persona              BIGINT,
  -- cod_suscriptor es de SEIS digitos y el legado lo corta con
  -- SUBSTR(...,1,2) para el prefijo. CHAR fija el ancho: con VARCHAR, un
  -- codigo de cinco digitos daria un prefijo distinto sin avisar.
  cod_suscriptor               CHAR(6),
  -- Las seis que decide el CASE de Portafolio, con los nombres del legado.
  cod_tipo_cta_fte             VARCHAR(10),
  cod_tipo_obligacion_fte      VARCHAR(10),
  cod_tipo_rel_con_cta_fte     VARCHAR(10),
  cod_clase_garantia_buro_fte  VARCHAR(10),
  num_cuotas_pactadas          INTEGER,
  -- Ancla de la ventana de 12 meses (F2-02). add_months(fecha_nov, -12) va
  -- por CUENTA, no por corrida: PRO_ORD_CTA_TOTALES_PERSONAS.sql:93.
  fecha_nov                    DATE,
  -- Las cuatro del concatena que si podemos sembrar sin inventar credito.
  valor_saldo                  DECIMAL(18,2),
  valor_cuota_mensual          DECIMAL(18,2),
  numero_dias_mora             INTEGER,
  num_cuotas_pagadas           INTEGER
)
DISTSTYLE KEY DISTKEY (id_buro_persona)
SORTKEY (id_buro_persona, cod_dw_cta);

DROP TABLE IF EXISTS bdm_stage.mock_comportamiento_cta;

CREATE TABLE bdm_stage.mock_comportamiento_cta (
  cod_dw_cta      BIGINT,
  -- 'A' activo, 'P' pasivo. El legado lo resuelve con dos tablas; aqui una
  -- columna da las dos banderas.
  tipo            CHAR(1),
  -- La fecha que decide si el comportamiento cae DENTRO de la ventana de los
  -- 12 meses. El ARQ 101 siembra una dentro y otra fuera: sin las dos, F2-02
  -- no se puede afirmar ni negar.
  fecha_corte     DATE
)
DISTSTYLE KEY DISTKEY (cod_dw_cta)
SORTKEY (cod_dw_cta, tipo);
