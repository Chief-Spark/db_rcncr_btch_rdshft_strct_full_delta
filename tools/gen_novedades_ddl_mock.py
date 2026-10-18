import re, sys
import os
# Raiz del paquete, derivada de la ubicacion de este script: el repo se
# clona en sitios distintos y una ruta absoluta lo rompe al primer traslado.
_RAIZ = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     "deploy", "redshift", "SLCOPRBA-1353")

CAB = """-- ============================================================
-- {dst}
-- ESPEJO MOCK de {src}. Generado por sustitucion: los
-- nombres de tabla reciben el sufijo _mock y NADA MAS cambia.
-- El diff contra el real debe salir vacio modulo ese sufijo.
-- Las justificaciones de tipo, contrato y divergencia estan en el archivo
-- real y no se duplican aqui a proposito: una copia se desincroniza.
-- ============================================================
"""


def espejo(src, dst, tablas):
    """Copia src a dst sufijando `tablas` con _mock y rehaciendo la cabecera.

    EL CORTE VA ANCLADO al primer CREATE SCHEMA y no a un indice de texto
    cualquiera: la cabecera del real menciona nombres de tabla en prosa y un
    corte mal puesto parte una linea en dos (leccion SLCOPRBA-1355).
    """
    ps = os.path.join(_RAIZ, "SQL", src)
    pd = os.path.join(_RAIZ, "SQL", dst)
    t = open(ps, encoding="ascii").read()
    for n in tablas:
        # \b para que un nombre no enganche el prefijo de otro mas largo
        t = re.sub(r'\b' + re.escape(n) + r'\b', n + "_mock", t)
    fin = t.index("\nCREATE SCHEMA IF NOT EXISTS bdm_datos;")
    open(pd, "w", encoding="ascii").write(CAB.format(src=src, dst=dst) + t[fin + 1:])
    print("ok", dst, sum(1 for _ in open(pd)), "lineas")


espejo("30_ddl_novedades.sql", "30b_ddl_novedades_mock.sql",
       ("bdm_tempo.stg_nov_ubica_etapa_9",
        "bdm_tempo.stg_nov_ubica_etapa_2",
        "bdm_datos.mat_info_ubicacion"))

espejo("34_ddl_nov_actividad_economica.sql", "34b_ddl_nov_actividad_economica_mock.sql",
       ("bdm_tempo.stg_nov_acteco_etapa_1",
        "bdm_datos.mat_info_actividad_economica"))
