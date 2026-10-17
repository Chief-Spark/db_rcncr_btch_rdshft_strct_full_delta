import re, sys
import os
# Raiz del paquete, derivada de la ubicacion de este script: el repo se
# clona en sitios distintos y una ruta absoluta lo rompe al primer traslado.
_RAIZ = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     "deploy", "redshift", "SLCOPRBA-1353")
src = os.path.join(_RAIZ, "SQL", "30_ddl_novedades.sql")
dst = os.path.join(_RAIZ, "SQL", "30b_ddl_novedades_mock.sql")
t = open(src, encoding="ascii").read()
for n in ("bdm_tempo.stg_nov_ubica_etapa_9",
          "bdm_tempo.stg_nov_ubica_etapa_2",
          "bdm_datos.mat_info_ubicacion"):
    t = t.replace(n, n + "_mock")
cab = """-- ============================================================
-- 30b_ddl_novedades_mock.sql
-- ESPEJO MOCK de 30_ddl_novedades.sql. Generado por sustitucion: los tres
-- nombres de tabla reciben el sufijo _mock y NADA MAS cambia.
-- El diff contra el real debe salir vacio modulo ese sufijo.
-- Las justificaciones de tipo, contrato y divergencia estan en el archivo
-- real y no se duplican aqui a proposito: una copia se desincroniza.
-- ============================================================
"""
# cortar la cabecera del real (hasta la primera linea en blanco tras el cierre)
fin = t.index("\nCREATE SCHEMA IF NOT EXISTS bdm_datos;")
open(dst, "w", encoding="ascii").write(cab + t[fin+1:])
print("ok", sum(1 for _ in open(dst)), "lineas")
