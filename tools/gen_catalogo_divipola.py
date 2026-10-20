"""Genera SQL/24_ddl_catalogo_divipola_cabecera.sql desde los CSV de DIVIPOLA.

Fuentes (dt, carpeta del legado, catalogos NH):
  Dane Divipola Villages Codes (NH).csv   7.978 centros poblados, codigo de 8
  DANE State Code (NH).csv                33 departamentos, codigo de 2

Solo entran las CABECERAS MUNICIPALES: codigo terminado en 000 (regla DIVIPOLA).
La columna Description (CM/CP) del CSV no sirve para eso: hay 884 'CM' que no
terminan en 000 y 902 'CP' que si.

Las claves son ASCII y en DOS variantes por nombre, para que la clave que se
calcula en Redshift, REGEXP_REPLACE(UPPER(TRIM(x)), '[^A-Z0-9]', ''), case
venga el nombre de EDF con tildes o sin ellas, sin meter un caracter no ASCII
en el repo:
  transliterada      ITAGUI       (si EDF escribe ITAGUI)
  sin lo no ASCII    ITAGI        (si EDF escribe la U con dieresis: el regex la borra)
Ademas, cada nombre aporta lo que va antes de la primera coma o punto
("BOGOTA, DISTRITO CAPITAL" -> BOGOTA) y lo que va antes de un parentesis, y
hay unos pocos alias explicitos para los nombres oficiales largos.
"""
import csv
import os
import re
import unicodedata

_AQUI = os.path.dirname(os.path.abspath(__file__))
_RAIZ = os.path.join(os.path.dirname(_AQUI), "deploy", "redshift", "SLCOPRBA-1353")
_CAT = os.path.join(os.path.dirname(os.path.dirname(_AQUI)),
                    "db_rcncr_btch_rdshft_dt_full_delta", "docs", "legado_teradata",
                    "reconocer", "catalogos")

# Nombres oficiales que nadie escribe completos. Solo los que la regla de la
# coma no resuelve.
ALIAS_CIUDAD = {
    "76001000": ["CALI"],
    "13001000": ["CARTAGENA"],
    "11001000": ["BOGOTA DC", "BOGOTA D C", "SANTAFE DE BOGOTA", "SANTA FE DE BOGOTA"],
}
ALIAS_DEPTO = {
    "11": ["BOGOTA", "BOGOTA DC", "BOGOTA D C", "DISTRITO CAPITAL", "BOGOTA DISTRITO CAPITAL"],
    "88": ["ARCHIPIELAGO DE SAN ANDRES PROVIDENCIA Y SANTA CATALINA",
           "SAN ANDRES Y PROVIDENCIA", "SAN ANDRES PROVIDENCIA Y SANTA CATALINA"],
    "76": ["VALLE"],
}


def translit(s):
    return "".join(c for c in unicodedata.normalize("NFD", s)
                   if unicodedata.category(c) != "Mn")


def claves(nombre):
    """Clave EXACTA: las dos variantes ASCII de un nombre, como las calcula
    Redshift con REGEXP_REPLACE(UPPER(TRIM(x)), '[^A-Z0-9]', '')."""
    u = nombre.upper()
    return {re.sub(r"[^A-Z0-9]", "", translit(u)), re.sub(r"[^A-Z0-9]", "", u)} - {""}


ESQ = r"[^B-DF-HJ-NP-TV-Z0-9]"


def esqueletos(nombre):
    """Clave ESQUELETO: solo consonantes ASCII y digitos. Resuelve la tilde en
    los dos sentidos -- 'Medellin' con tilde en EDF contra MEDELLIN sin ella en
    el CSV, que la clave exacta no casa (la vista borra la I con tilde y queda
    MEDELLN). Es mas ambigua (115 claves de cabecera apuntan a mas de un
    codigo, contra 67 de la exacta), por eso va segunda y con la misma guardia
    de un solo codigo."""
    u = nombre.upper()
    return {re.sub(ESQ, "", translit(u)), re.sub(ESQ, "", u)} - {""}


def variantes(nombre):
    """El nombre completo, lo previo a coma o punto y lo previo a parentesis."""
    out = {nombre}
    for sep in (",", ".", "("):
        if sep in nombre:
            out.add(nombre.split(sep)[0])
    return out


def lee(nombre_csv):
    with open(os.path.join(_CAT, nombre_csv), encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main():
    deptos = {}
    for x in lee("DANE State Code (NH).csv"):
        cod = x["Code/text"].strip()
        if cod:
            deptos[cod.zfill(2)] = x["Name"].strip()
    filas = set()
    nombres = {}
    for x in lee("Dane Divipola Villages Codes (NH).csv"):
        cod = x["Code/text"].strip().zfill(8)
        if not cod.strip("0") or not cod.endswith("000"):
            continue
        dep = cod[:2]
        nombres[cod] = translit(x["Name"].strip().upper())
        for tipo, fn in (("E", claves), ("S", esqueletos)):
            kc = set()
            for v in variantes(x["Name"].strip()) | set(ALIAS_CIUDAD.get(cod, [])):
                kc |= fn(v)
            kd = set()
            for v in {deptos.get(dep, "")} | set(ALIAS_DEPTO.get(dep, [])):
                kd |= fn(v)
            # Por si el datashare trae el departamento como codigo y no como nombre.
            kd |= {dep, str(int(dep))}
            for c in kc:
                for d in kd:
                    filas.add((int(cod), tipo, c, d))
    filas = sorted(filas)
    return filas, nombres


CAB = """-- ============================================================
-- 24_ddl_catalogo_divipola_cabecera.sql
-- 2026-10-20 (D-EDF-02, propuesta C aprobada). Ciudad de respaldo para las
-- direcciones que llegan del datashare SIN codigo DANE.
-- UTF-8 sin BOM. ASCII sin acentos a proposito.
-- GENERADO por tools/gen_catalogo_divipola.py: no se edita a mano.
--
-- ORIGEN: los CSV NH de DIVIPOLA guardados con el legado
-- (dt/docs/legado_teradata/reconocer/catalogos/), que sustituyen al
-- V_Geografia que llego truncado a 1000 filas.
--
-- QUE ES: una fila por (cabecera municipal, tipo de clave, clave de ciudad,
-- clave de departamento). Solo cabeceras: codigo de 8 digitos terminado en 000. Con
-- eso la ciudad que se asigna es la CABECERA del municipio que nombra el
-- reporte: es PROBABLE y no CONFIRMADO, porque el reporte no dice el centro
-- poblado. Las claves son ASCII y van en dos variantes (transliterada y con
-- lo no ASCII eliminado) y en dos tipos, para casar con lo que calcula la
-- vista venga EDF con tildes o sin ellas:
--   E (exacta)    REGEXP_REPLACE(UPPER(TRIM(nombre)), '[^A-Z0-9]', '')
--   S (esqueleto) REGEXP_REPLACE(UPPER(TRIM(nombre)), '[^B-DF-HJ-NP-TV-Z0-9]', '')
-- La S existe porque la E no casa 'Medellin' con tilde contra MEDELLIN. Detalle
-- en el generador.
--
-- COMO SE USA (02_vistas_insumo_edf_views.sql, v_xpm_contacto_direccion):
-- exacta con departamento, exacta sola, esqueleto con departamento y
-- esqueleto solo, en ese orden, y siempre solo si la clave apunta a UN codigo
-- (HAVING COUNT(DISTINCT) = 1).
-- Los {repetidos} nombres de cabecera que existen en mas de un departamento
-- solo casan con el departamento; sin el, quedan en NULL.
--
-- DISTSTYLE ALL: {n} filas, se une contra cada direccion.
-- DROP + CREATE y no CREATE IF NOT EXISTS: es un catalogo que se recarga
-- entero en cada despliegue, y asi un cambio de columnas no queda escondido
-- detras de una tabla vieja (la trampa del literal largo de R2-07).
-- ============================================================

DROP TABLE IF EXISTS bdm_datos.catalogo_divipola_cabecera;
CREATE TABLE bdm_datos.catalogo_divipola_cabecera (
  cod_dane_ciudad INTEGER     ENCODE AZ64,
  tipo_clave      CHAR(1)      ENCODE ZSTD,   -- E exacta | S esqueleto
  clave_ciudad    VARCHAR(120) ENCODE ZSTD,
  clave_depto     VARCHAR(120) ENCODE ZSTD
)
DISTSTYLE ALL;

INSERT INTO bdm_datos.catalogo_divipola_cabecera (cod_dane_ciudad, tipo_clave, clave_ciudad, clave_depto) VALUES
"""

if __name__ == "__main__":
    filas, nombres = main()
    vistos = {}
    for cod, n in nombres.items():
        k = re.sub(r"[^A-Z0-9]", "", n)
        vistos.setdefault(k, set()).add(cod[:2])
    repetidos = sum(1 for v in vistos.values() if len(v) > 1)
    cuerpo = ",\n".join("  (%d, '%s', '%s', '%s')" % f for f in filas)
    out = CAB.format(repetidos=repetidos, n=len(filas)) + cuerpo + ";\n\n" \
        "SELECT COUNT(*) AS filas, COUNT(DISTINCT cod_dane_ciudad) AS cabeceras\n" \
        "  FROM bdm_datos.catalogo_divipola_cabecera;\n"
    out.encode("ascii")
    dst = os.path.join(_RAIZ, "SQL", "24_ddl_catalogo_divipola_cabecera.sql")
    with open(dst, "w", encoding="ascii", newline="\n") as f:
        f.write(out)
    print("%s: %d filas, %d cabeceras, %d nombres repetidos entre departamentos"
          % (os.path.basename(dst), len(filas), len(nombres), repetidos))
