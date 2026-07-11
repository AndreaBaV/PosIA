#!/usr/bin/env python3
"""Importa productos desde hola2.xlsx al catálogo Neon vía hub POSIA."""

from __future__ import annotations

import json
import os
import re
import sys
import unicodedata
import uuid
import zipfile
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
CATEGORIA_DEFECTO = "abarrotes"
DISPOSITIVO_ID = "import-hola2-script"
LOTE_EVENTOS = 40


def _parse_database_url(url: str) -> dict:
    from urllib.parse import urlparse, unquote

    parsed = urlparse(url)
    return {
        "host": parsed.hostname,
        "port": parsed.port or 5432,
        "dbname": parsed.path.lstrip("/"),
        "user": unquote(parsed.username or ""),
        "password": unquote(parsed.password or ""),
        "sslmode": "require",
    }


def limpiar_conflictos_barcode(database_url: str, tienda_id: str, codigos: list[str]) -> int:
    """Elimina productos huérfanos con mismo UPC pero distinto id (re-import)."""
    if not codigos:
        return 0
    try:
        import psycopg2
    except ImportError:
        return 0
    conn = psycopg2.connect(_parse_database_url(database_url))
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                DELETE FROM products
                WHERE tienda_id = %s
                  AND codigo_barras = ANY(%s)
                """,
                (tienda_id, codigos),
            )
            eliminados = cur.rowcount
        conn.commit()
        return eliminados
    finally:
        conn.close()


def col_idx(col: str) -> int:
    n = 0
    for c in col:
        n = n * 26 + (ord(c) - 64)
    return n


def slug(texto: str, prefijo: str) -> str:
    t = (
        unicodedata.normalize("NFKD", texto.strip().lower())
        .encode("ascii", "ignore")
        .decode("ascii")
    )
    t = re.sub(r"[^a-z0-9]+", "-", t).strip("-")
    return f"{prefijo}-{t or '1'}"


def leer_filas_xlsx(ruta: Path) -> list[list[str]]:
    with zipfile.ZipFile(ruta) as z:
        shared: list[str] = []
        if "xl/sharedStrings.xml" in z.namelist():
            root = ET.fromstring(z.read("xl/sharedStrings.xml"))
            for si in root.findall("m:si", NS):
                parts = [x.text or "" for x in si.findall(".//m:t", NS)]
                shared.append("".join(parts))
        sheet = ET.fromstring(z.read("xl/worksheets/sheet1.xml"))
        filas: dict[int, list[str]] = {}
        for row in sheet.findall(".//m:sheetData/m:row", NS):
            rnum = int(row.get("r", "0"))
            cells: dict[int, str] = {}
            for c in row.findall("m:c", NS):
                ref = c.get("r", "")
                m = re.match(r"([A-Z]+)(\d+)", ref)
                if not m:
                    continue
                col = m.group(1)
                t = c.get("t")
                v = c.find("m:v", NS)
                if v is None:
                    val = ""
                elif t == "s":
                    val = shared[int(v.text)] if v.text else ""
                else:
                    val = v.text or ""
                cells[col_idx(col)] = val
            if cells:
                maxc = max(cells)
                filas[rnum] = [cells.get(i, "") for i in range(1, maxc + 1)]
        return [filas[k] for k in sorted(filas)]


def parsear_precio(texto: str) -> float | None:
    t = texto.strip().replace("$", "").replace(",", "")
    if not t:
        return None
    try:
        return float(t)
    except ValueError:
        return None


def http_json(
    method: str,
    url: str,
    api_key: str,
    body: dict | None = None,
) -> dict:
    data = None
    headers = {"x-api-key": api_key, "Accept": "application/json"}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(req, timeout=120) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} {url}: {detail}") from e
    except URLError as e:
        raise RuntimeError(f"No se pudo conectar a {url}: {e}") from e


def obtener_tienda_id(hub_url: str, api_key: str) -> str:
    data = http_json("GET", f"{hub_url.rstrip('/')}/v1/stores", api_key)
    tiendas = data.get("tiendas") or []
    if not tiendas:
        raise RuntimeError("El hub no tiene tiendas activas en Neon")
    return tiendas[0]["id"]


def mapear_ids_producto_por_upc(hub_url: str, api_key: str) -> dict[str, str]:
    """Reutiliza ids ya proyectados en Neon para re-import idempotente."""
    mapa: dict[str, str] = {}
    cursor = 0
    while True:
        data = http_json(
            "GET",
            f"{hub_url.rstrip('/')}/v1/events?since={cursor}",
            api_key,
        )
        eventos = data.get("events") or []
        if not eventos:
            break
        for ev in eventos:
            if ev.get("type") != "productUpserted":
                continue
            payload = ev.get("payload") or {}
            upc = str(payload.get("codigoBarras") or "").strip()
            prod_id = str(payload.get("id") or "").strip()
            if upc and prod_id:
                mapa[upc] = prod_id
        ultimo = int(data.get("lastSeq") or cursor)
        if ultimo <= cursor:
            break
        cursor = ultimo
    return mapa


def evento(tipo: str, payload: dict, tienda_id: str) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "type": tipo,
        "payload": payload,
        "createdAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "storeId": tienda_id,
        "deviceId": DISPOSITIVO_ID,
    }


def product_id(codigo_barras: str, nombre: str) -> str:
    if codigo_barras:
        return slug(codigo_barras, "prod")
    return slug(nombre, "prod")


def enviar_lote(hub_url: str, api_key: str, tienda_id: str, eventos: list[dict]) -> tuple[int, list[str]]:
    errores: list[str] = []
    aceptados = 0
    for evento in eventos:
        try:
            data = http_json(
                "POST",
                f"{hub_url.rstrip('/')}/v1/events",
                api_key,
                {
                    "deviceId": DISPOSITIVO_ID,
                    "storeId": tienda_id,
                    "events": [evento],
                },
            )
            if int(data.get("accepted", 0)) < 1:
                detalle = json.dumps(data)
                errores.append(
                    f"No aceptado {evento['type']} "
                    f"{evento.get('payload', {}).get('nombre', evento['id'])} "
                    f"({detalle})"
                )
            else:
                aceptados += 1
        except RuntimeError as err:
            errores.append(str(err))
    return aceptados, errores


def construir_eventos(
    filas: list[list[str]],
    tienda_id: str,
    ids_por_upc: dict[str, str] | None = None,
) -> list[dict]:
    if not filas:
        raise RuntimeError("Hoja vacía")
    headers = [h.strip().lower() for h in filas[0]]

    def idx(nombres: list[str]) -> int | None:
        for nombre in nombres:
            if nombre in headers:
                return headers.index(nombre)
        return None

    i_nombre = idx(["nombre", "producto", "articulo"])
    i_costo = idx(["costo", "costo_unitario"])
    i_precio = idx(["precio", "precio_base", "precio venta"])
    i_upc = idx(["upc", "codigo_barras", "barcode", "sku"])
    i_unidad = idx(["unidad", "unidad_medida"])
    i_categoria = idx(["categoria", "categoría", "category"])
    i_lote = idx(["lote_promocion", "lote promocion"])
    i_piezas = idx(["piezas_caja", "piezas caja"])
    i_precio_caja = idx(["precio_caja", "precio caja"])

    if i_nombre is None or i_precio is None:
        raise RuntimeError('Faltan columnas obligatorias "nombre" y "precio"')

    def celda(fila: list[str], i: int | None) -> str:
        if i is None or i >= len(fila):
            return ""
        return fila[i].strip()

    categorias: dict[str, str] = {}
    eventos: list[dict] = []

    def asegurar_categoria(nombre: str) -> str:
        clave = nombre.strip() or CATEGORIA_DEFECTO
        if clave not in categorias:
            cat_id = slug(clave, "cat")
            categorias[clave] = cat_id
            eventos.append(
                evento(
                    "categoryUpserted",
                    {
                        "id": cat_id,
                        "nombre": clave.title() if clave != CATEGORIA_DEFECTO else "Abarrotes",
                        "icono": "shopping_basket",
                        "colorHex": "#4CAF50",
                        "orden": len(categorias),
                        "activa": True,
                    },
                    tienda_id,
                )
            )
        return categorias[clave]

    productos = 0
    for fila in filas[1:]:
        nombre = celda(fila, i_nombre)
        if not nombre:
            continue
        precio = parsear_precio(celda(fila, i_precio))
        if precio is None:
            precio = parsear_precio(celda(fila, i_costo))
        if precio is None:
            print(f"Omitido (sin precio): {nombre}", file=sys.stderr)
            continue
        costo = parsear_precio(celda(fila, i_costo)) or 0.0
        categoria_txt = celda(fila, i_categoria) or CATEGORIA_DEFECTO
        cat_id = asegurar_categoria(categoria_txt)
        unidad_txt = celda(fila, i_unidad) or "pieza"
        unidad = unidad_txt.lower()
        if unidad in ("pz", "pza", "piezas", "unidad"):
            unidad = "pieza"
        piezas_txt = celda(fila, i_piezas)
        piezas = int(float(piezas_txt)) if piezas_txt else None
        codigo = celda(fila, i_upc)
        prod_id = ids_por_upc.get(codigo) if codigo and ids_por_upc else None
        if not prod_id:
            prod_id = product_id(codigo, nombre)
        payload = {
            "id": prod_id,
            "nombre": nombre,
            "codigoBarras": codigo,
            "precioBase": precio,
            "unidadMedida": unidad,
            "rutaImagen": "",
            "activo": True,
            "tiendaId": tienda_id,
            "moduloVertical": "general",
            "categoriaId": cat_id,
            "costoUnitario": costo,
            "favoritoCaja": False,
            "permiteStockNegativo": True,
        }
        if piezas:
            payload["piezasPorCaja"] = piezas
        lote = celda(fila, i_lote)
        precio_caja = parsear_precio(celda(fila, i_precio_caja))
        if lote:
            payload["notas"] = f"lote_promocion:{lote}"
        if precio_caja:
            payload["notas"] = (payload.get("notas", "") + f" precio_caja:{precio_caja}").strip()
        eventos.append(evento("productUpserted", payload, tienda_id))
        productos += 1

    if productos == 0:
        raise RuntimeError("No se encontraron productos válidos en la hoja")
    return eventos


def main() -> int:
    ruta = Path(sys.argv[1] if len(sys.argv) > 1 else "apps/posia_pos/hola2.xlsx")
    hub_url = os.environ.get("POSIA_HUB_URL", "").strip()
    api_key = os.environ.get("POSIA_HUB_API_KEY", "").strip()
    if not hub_url or not api_key:
        print("Defina POSIA_HUB_URL y POSIA_HUB_API_KEY", file=sys.stderr)
        return 1
    if not ruta.exists():
        print(f"No existe el archivo: {ruta}", file=sys.stderr)
        return 1

    filas = leer_filas_xlsx(ruta)
    tienda_id = obtener_tienda_id(hub_url, api_key)
    ids_por_upc = mapear_ids_producto_por_upc(hub_url, api_key)
    if ids_por_upc:
        print(f"Reutilizando {len(ids_por_upc)} ids de producto ya existentes en Neon")
    eventos = construir_eventos(filas, tienda_id, ids_por_upc)

    database_url = os.environ.get("DATABASE_URL", "").strip()
    if database_url:
        codigos = [
            e["payload"]["codigoBarras"]
            for e in eventos
            if e["type"] == "productUpserted"
            and e["payload"].get("codigoBarras")
        ]
        eliminados = limpiar_conflictos_barcode(database_url, tienda_id, codigos)
        if eliminados:
            print(f"Limpieza Neon: {eliminados} productos duplicados por UPC eliminados")

    total = 0
    errores_totales: list[str] = []
    for i in range(0, len(eventos), LOTE_EVENTOS):
        lote = eventos[i : i + LOTE_EVENTOS]
        aceptados, errores = enviar_lote(hub_url, api_key, tienda_id, lote)
        total += aceptados
        errores_totales.extend(errores)
        print(f"Progreso: {total}/{len(eventos)} eventos aceptados…")

    productos = sum(1 for e in eventos if e["type"] == "productUpserted")
    categorias = sum(1 for e in eventos if e["type"] == "categoryUpserted")
    print(
        f"Importación completada: {productos} productos preparados, "
        f"{categorias} categorías, {total} eventos aceptados, tienda={tienda_id}"
    )
    if errores_totales:
        print(f"Advertencias ({len(errores_totales)}):", file=sys.stderr)
        for err in errores_totales[:20]:
            print(f"  - {err}", file=sys.stderr)
        if len(errores_totales) > 20:
            print(f"  … y {len(errores_totales) - 20} más", file=sys.stderr)
    if errores_totales and total < len(eventos):
        return 1
    return 0 if total > 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
