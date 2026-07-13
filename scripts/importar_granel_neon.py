#!/usr/bin/env python3
"""Importa productos por kilogramo (presentaciones en gramos/kg) al catálogo Neon.

Formato de hoja (plantilla):
  nombre | presentacion_gramos | precio | categoria

- La primera fila de un producto lleva el nombre; filas siguientes del mismo
  producto dejan nombre vacío y solo indican otra presentación.
- La categoría es libre (puede ser mixta). Si falta, se usa abarrotes.
- La unidad de medida siempre es kilogramo.
- Si existe fila con 1000 g, ese precio es el precio por kilo (precioBase).
- Si no hay 1000 g, se toma la presentación de mayor gramos y se proyecta a kilo:
  precio_kilo = precio_max * (1000 / gramos_max). Ejemplo: 500 g × $40 → $80/kg.

Uso:
  POSIA_HUB_URL=... POSIA_HUB_API_KEY=... \\
    python3 scripts/importar_granel_neon.py apps/posia_pos/hola2.xlsx --hoja Granel
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
import uuid
import zipfile
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

NS = {
    "m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "pr": "http://schemas.openxmlformats.org/package/2006/relationships",
}
CATEGORIA_DEFECTO = "abarrotes"
DISPOSITIVO_ID = "import-granel-script"
LOTE_EVENTOS = 25


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


def parsear_numero(texto: str) -> float | None:
    t = str(texto).strip().replace("$", "").replace(",", "")
    if not t:
        return None
    try:
        return float(t)
    except ValueError:
        return None


def http_json(method: str, url: str, api_key: str, body: dict | None = None) -> dict:
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


def evento(tipo: str, payload: dict, tienda_id: str) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "type": tipo,
        "payload": payload,
        "createdAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "storeId": tienda_id,
        "deviceId": DISPOSITIVO_ID,
    }


def _shared_strings(z: zipfile.ZipFile) -> list[str]:
    shared: list[str] = []
    if "xl/sharedStrings.xml" not in z.namelist():
        return shared
    root = ET.fromstring(z.read("xl/sharedStrings.xml"))
    for si in root.findall("m:si", NS):
        parts = [x.text or "" for x in si.findall(".//m:t", NS)]
        shared.append("".join(parts))
    return shared


def _listar_hojas(z: zipfile.ZipFile) -> list[tuple[str, str]]:
    """Retorna [(nombre_hoja, ruta_xml), ...] en orden del libro."""
    wb = ET.fromstring(z.read("xl/workbook.xml"))
    rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    rid_a_target: dict[str, str] = {}
    for rel in rels:
        rid = rel.get("Id")
        target = rel.get("Target")
        if rid and target:
            if not target.startswith("xl/"):
                target = f"xl/{target.lstrip('/')}"
            rid_a_target[rid] = target
    hojas: list[tuple[str, str]] = []
    for sheet in wb.findall("m:sheets/m:sheet", NS):
        nombre = sheet.get("name") or ""
        rid = sheet.get(
            "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
        )
        if not nombre or not rid:
            continue
        target = rid_a_target.get(rid)
        if target:
            hojas.append((nombre, target))
    return hojas


def _parsear_hoja(z: zipfile.ZipFile, ruta: str, shared: list[str]) -> list[list[str]]:
    sheet = ET.fromstring(z.read(ruta))
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


def leer_filas_xlsx(ruta: Path, hoja: str | None = None) -> list[list[str]]:
    with zipfile.ZipFile(ruta) as z:
        shared = _shared_strings(z)
        hojas = _listar_hojas(z)
        if not hojas:
            raise RuntimeError("El libro no tiene hojas")
        if hoja:
            clave = hoja.strip().lower()
            elegida = next((h for h in hojas if h[0].strip().lower() == clave), None)
            if elegida is None:
                nombres = ", ".join(n for n, _ in hojas)
                raise RuntimeError(f'Hoja "{hoja}" no encontrada. Disponibles: {nombres}')
            return _parsear_hoja(z, elegida[1], shared)
        return _parsear_hoja(z, hojas[0][1], shared)


def listar_nombres_hojas(ruta: Path) -> list[str]:
    with zipfile.ZipFile(ruta) as z:
        return [n for n, _ in _listar_hojas(z)]


def agrupar_productos_granel(filas: list[list[str]]) -> list[dict]:
    if not filas:
        raise RuntimeError("Hoja vacía")
    headers = [h.strip().lower() for h in filas[0]]

    def idx(*nombres: str) -> int | None:
        for nombre in nombres:
            if nombre in headers:
                return headers.index(nombre)
        # aliases parciales
        for i, h in enumerate(headers):
            for nombre in nombres:
                if nombre in h:
                    return i
        return None

    i_nombre = idx("nombre", "producto", "articulo")
    i_gramos = idx(
        "presentacion_gramos",
        "presentación en gramos",
        "presentacion en gramos",
        "gramos",
        "gr",
        "g",
    )
    i_precio = idx("precio", "precio_base", "precio venta")
    i_categoria = idx("categoria", "categoría", "category")

    if i_nombre is None or i_gramos is None or i_precio is None:
        raise RuntimeError(
            'Se requieren columnas "nombre", "presentacion_gramos" (o gramos) y "precio"'
        )

    def celda(fila: list[str], i: int | None) -> str:
        if i is None or i >= len(fila):
            return ""
        return str(fila[i]).strip()

    productos: list[dict] = []
    actual: dict | None = None

    for fila in filas[1:]:
        nombre = celda(fila, i_nombre)
        gramos = parsear_numero(celda(fila, i_gramos))
        precio = parsear_numero(celda(fila, i_precio))
        categoria = celda(fila, i_categoria)

        if nombre:
            actual = {
                "nombre": nombre,
                "categoria": categoria or CATEGORIA_DEFECTO,
                "presentaciones": [],
            }
            productos.append(actual)
        if actual is None:
            continue
        if gramos is None or precio is None:
            continue
        if gramos <= 0 or precio < 0:
            continue
        if categoria and not actual.get("categoria_fija"):
            actual["categoria"] = categoria
        actual["presentaciones"].append((gramos, precio))

    validos = [p for p in productos if p["presentaciones"]]
    if not validos:
        raise RuntimeError("No se encontraron productos con presentaciones válidas")
    return validos


def calcular_precio_kilo(presentaciones: list[tuple[float, float]]) -> float:
    for gramos, precio in presentaciones:
        if abs(gramos - 1000.0) < 0.01:
            return round(precio, 2)
    gramos_max, precio_max = max(presentaciones, key=lambda x: x[0])
    return round(precio_max * (1000.0 / gramos_max), 2)


def construir_eventos(productos: list[dict], tienda_id: str) -> list[dict]:
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
                        "nombre": "Abarrotes" if clave.lower() == CATEGORIA_DEFECTO else clave.title(),
                        "icono": "category",
                        "colorHex": "#607D8B",
                        "orden": len(categorias),
                        "activa": True,
                    },
                    tienda_id,
                )
            )
        return categorias[clave]

    for prod in productos:
        nombre = prod["nombre"]
        presentaciones: list[tuple[float, float]] = prod["presentaciones"]
        precio_kilo = calcular_precio_kilo(presentaciones)
        cat_id = asegurar_categoria(prod.get("categoria") or CATEGORIA_DEFECTO)
        prod_id = slug(nombre, "prod")

        eventos.append(
            evento(
                "productUpserted",
                {
                    "id": prod_id,
                    "nombre": nombre,
                    "codigoBarras": "",
                    "precioBase": precio_kilo,
                    "unidadMedida": "kilogramo",
                    "rutaImagen": "",
                    "activo": True,
                    "tiendaId": tienda_id,
                    "moduloVertical": "general",
                    "categoriaId": cat_id,
                    "costoUnitario": 0.0,
                    "favoritoCaja": False,
                    "permiteStockNegativo": True,
                    "notas": "importacion:kg",
                },
                tienda_id,
            )
        )

        payload_pres: list[dict] = [
            {
                "id": f"{prod_id}-base",
                "tipoPresentacionId": None,
                "nombre": "1 kg",
                "factorABase": 1.0,
                "esPresentacionBase": True,
                "codigoBarras": "",
                "precio": precio_kilo,
                "activo": True,
            }
        ]
        for gramos, precio in presentaciones:
            if abs(gramos - 1000.0) < 0.01:
                continue
            etiqueta = (
                f"{int(gramos)} g" if float(gramos).is_integer() else f"{gramos} g"
            )
            payload_pres.append(
                {
                    "id": f"{prod_id}-{int(gramos)}g",
                    "tipoPresentacionId": None,
                    "nombre": etiqueta,
                    "factorABase": round(gramos / 1000.0, 6),
                    "esPresentacionBase": False,
                    "codigoBarras": "",
                    "precio": round(precio, 2),
                    "activo": True,
                }
            )

        eventos.append(
            evento(
                "productPresentationsReplaced",
                {"productoId": prod_id, "presentaciones": payload_pres},
                tienda_id,
            )
        )

    return eventos


def enviar_lote(
    hub_url: str, api_key: str, tienda_id: str, eventos: list[dict]
) -> tuple[int, list[str]]:
    errores: list[str] = []
    aceptados = 0
    for ev in eventos:
        for intento in range(4):
            try:
                data = http_json(
                    "POST",
                    f"{hub_url.rstrip('/')}/v1/events",
                    api_key,
                    {
                        "deviceId": DISPOSITIVO_ID,
                        "storeId": tienda_id,
                        "events": [ev],
                    },
                )
                if int(data.get("accepted", 0)) < 1:
                    errores.append(
                        f"No aceptado {ev['type']} "
                        f"{ev.get('payload', {}).get('nombre') or ev.get('payload', {}).get('productoId')}"
                    )
                else:
                    aceptados += 1
                break
            except RuntimeError as err:
                mensaje = str(err)
                es_transitorio = any(
                    token in mensaje
                    for token in ("503", "502", "504", "Connection refused", "timed out")
                )
                if es_transitorio and intento < 3:
                    time.sleep(2**intento)
                    continue
                errores.append(mensaje)
                break
    return aceptados, errores


def main() -> int:
    parser = argparse.ArgumentParser(description="Importa productos granel a Neon")
    parser.add_argument(
        "archivo",
        nargs="?",
        default="apps/posia_pos/hola2.xlsx",
        help="Ruta al XLSX o CSV",
    )
    parser.add_argument(
        "--hoja",
        default="Granel",
        help='Nombre de la hoja (default: "Granel")',
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Solo muestra resumen sin enviar al hub",
    )
    args = parser.parse_args()

    ruta = Path(args.archivo)
    if not ruta.exists():
        print(f"No existe el archivo: {ruta}", file=sys.stderr)
        return 1

    filas = leer_filas_xlsx(ruta, hoja=args.hoja)
    productos = agrupar_productos_granel(filas)
    print(f"Hoja '{args.hoja}': {len(productos)} productos a granel")
    sin_kilo = 0
    for p in productos:
        tiene_kilo = any(abs(g - 1000) < 0.01 for g, _ in p["presentaciones"])
        if not tiene_kilo:
            sin_kilo += 1
            pk = calcular_precio_kilo(p["presentaciones"])
            print(f"  - {p['nombre']}: sin 1000g -> precio/kg derivado ${pk:.2f}")
    print(f"Con precio/kg explicito: {len(productos) - sin_kilo}; derivados: {sin_kilo}")

    if args.dry_run:
        for p in productos[:5]:
            print(
                f"  {p['nombre']}: {p['presentaciones']} -> "
                f"${calcular_precio_kilo(p['presentaciones']):.2f}/kg"
            )
        if len(productos) > 5:
            print(f"  … y {len(productos) - 5} más")
        return 0

    hub_url = os.environ.get("POSIA_HUB_URL", "").strip()
    api_key = os.environ.get("POSIA_HUB_API_KEY", "").strip()
    if not hub_url or not api_key:
        print("Defina POSIA_HUB_URL y POSIA_HUB_API_KEY", file=sys.stderr)
        return 1

    tienda_id = obtener_tienda_id(hub_url, api_key)
    eventos = construir_eventos(productos, tienda_id)
    total = 0
    errores_totales: list[str] = []
    for i in range(0, len(eventos), LOTE_EVENTOS):
        lote = eventos[i : i + LOTE_EVENTOS]
        aceptados, errores = enviar_lote(hub_url, api_key, tienda_id, lote)
        total += aceptados
        errores_totales.extend(errores)
        print(f"Progreso: {total}/{len(eventos)} eventos aceptados…")

    n_prod = sum(1 for e in eventos if e["type"] == "productUpserted")
    n_pres = sum(1 for e in eventos if e["type"] == "productPresentationsReplaced")
    print(
        f"Importación granel: {n_prod} productos, {n_pres} sets de presentaciones, "
        f"{total} eventos aceptados, tienda={tienda_id}"
    )
    if errores_totales:
        print(f"Advertencias ({len(errores_totales)}):", file=sys.stderr)
        for err in errores_totales[:20]:
            print(f"  - {err}", file=sys.stderr)
    if errores_totales and total < len(eventos):
        return 1
    return 0 if total > 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
