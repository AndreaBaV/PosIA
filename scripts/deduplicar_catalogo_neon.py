#!/usr/bin/env python3
"""Replica en Neon la deduplicacion de catalogo aplicada en SQLite local.

El protocolo de sync no tiene evento de borrado para categorias ni productos:
solo `categoryUpserted` / `productUpserted`. Si se limpian los duplicados en un
equipo pero no en el hub, el siguiente pull los revive. Este script hace en
Postgres exactamente la misma fusion que se aplico localmente.

Uso:
    set NEON_DATABASE_URL=postgresql://...
    python scripts/deduplicar_catalogo_neon.py            # simulacion
    python scripts/deduplicar_catalogo_neon.py --aplicar  # ejecuta

Requiere psycopg (pip install "psycopg[binary]").
"""
import argparse
import os
import sys

try:
    import psycopg
except ImportError:  # pragma: no cover
    sys.exit('Falta psycopg. Instala con: pip install "psycopg[binary]"')

# Fusion de categorias decidida con el equipo: sobrevive la activa con mas
# productos; "Aceite"->"Aceites", "Especias" y "Chiles Secos"->"Especias Y
# Chiles", "higienicos"->"Papel Higienico".
CATEGORIAS = {
    '62844046-2abf-41a4-ad82-1f7ef7b54683': 'cat-abarrotes',
    'c39294f7-bbf5-41e0-a94e-51022e287ce4': 'cat-aceites',
    'cat-aceite': 'cat-aceites',
    'd6cbf8c1-3bcd-4617-8f91-3abfb4e42b7c': 'cat-dulces-y-saborizantes',
    'cdaa7517-bcda-42be-a3a5-ee548f2bcfe8': 'cat-especias-y-chiles',
    '4f6707fc-4b2e-4866-b2d4-5eeea6f1d381': 'cat-especias-y-chiles',
    '484831f2-445c-4bda-b4f1-6bbbd873bd3e': 'cat-especias-y-chiles',
    'fa91a526-c95d-4e06-8704-f4d8bb95a532': 'cat-frutos-secos',
    'b421aed6-c87a-4371-9774-7303c72bb359': 'cat-frutos-secos',
    '89a6705c-0edf-4a67-ba0f-1219f61c4d6e': 'cat-semillas',
    'c27b8173-f601-43a3-93b2-f966db7f17a8': 'cat-semillas',
    '63908192-1f24-474b-900d-de8450efd14a': 'cat-papel-higienico',
}

# Un stub FK le sobrescribio el nombre a la categoria real.
RENOMBRAR = {'cat-semillas': 'Semillas'}


def tablas_con_columna(cur, columna):
    cur.execute(
        """SELECT table_name FROM information_schema.columns
           WHERE column_name = %s AND table_schema = 'public'""",
        (columna,),
    )
    return [r[0] for r in cur.fetchall()]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--aplicar', action='store_true')
    args = p.parse_args()

    dsn = os.environ.get('NEON_DATABASE_URL', '').strip()
    if not dsn:
        sys.exit('Define NEON_DATABASE_URL con la cadena de conexion de Neon.')

    with psycopg.connect(dsn) as conn, conn.cursor() as cur:
        for cid, nombre in RENOMBRAR.items():
            cur.execute(
                'UPDATE categories SET nombre=%s, activa=true WHERE id=%s',
                (nombre, cid),
            )
            print(f'renombrada {cid} -> {nombre} ({cur.rowcount})')

        for viejo, nuevo in CATEGORIAS.items():
            cur.execute('SELECT 1 FROM categories WHERE id=%s', (nuevo,))
            if not cur.fetchone():
                print(f'  AVISO: destino inexistente {nuevo}, se omite {viejo}')
                continue
            cur.execute(
                'UPDATE products SET categoria_id=%s WHERE categoria_id=%s',
                (nuevo, viejo),
            )
            movidos = cur.rowcount
            cur.execute('DELETE FROM categories WHERE id=%s', (viejo,))
            print(f'  {viejo[:20]:<22} -> {nuevo:<28} productos={movidos}')

        # Productos duplicados por nombre: sobrevive el de id canonico "prod-*"
        # si existe; si no, el primero por id. Se reasignan las filas hijas.
        cur.execute(
            """SELECT lower(btrim(nombre)) FROM products
               WHERE lower(btrim(nombre)) <> 'producto'
               GROUP BY 1 HAVING count(*) > 1"""
        )
        grupos = [r[0] for r in cur.fetchall()]
        hijas = tablas_con_columna(cur, 'producto_id')
        print(f'\ngrupos de productos duplicados: {len(grupos)}')
        for nombre in grupos:
            cur.execute(
                'SELECT id FROM products WHERE lower(btrim(nombre))=%s ORDER BY id',
                (nombre,),
            )
            ids = [r[0] for r in cur.fetchall()]
            vive = next((i for i in ids if i.startswith('prod-')), ids[0])
            for muere in [i for i in ids if i != vive]:
                for t in hijas:
                    try:
                        cur.execute(
                            f'UPDATE {t} SET producto_id=%s WHERE producto_id=%s',
                            (vive, muere),
                        )
                    except psycopg.errors.UniqueViolation:
                        conn.rollback()
                        cur.execute(
                            f'DELETE FROM {t} WHERE producto_id=%s', (muere,)
                        )
                cur.execute('DELETE FROM products WHERE id=%s', (muere,))
            print(f'  {nombre[:38]:<40} vive={vive}')

        if args.aplicar:
            conn.commit()
            print('\nCambios APLICADOS en Neon.')
        else:
            conn.rollback()
            print('\nSimulacion: nada se guardo. Usa --aplicar para ejecutar.')


if __name__ == '__main__':
    main()
