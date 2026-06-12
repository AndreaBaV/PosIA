# Base de datos local POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 18:30:00 (UTC-6)  
**Ultima modificacion:** 2026-06-11 22:00:00 (UTC-6)

---

## 1. Motor

- **SQLite** via **sqflite** en cada caja
- Archivo: `posia_local.db` en directorio de aplicacion
- Version de esquema: **3** (`SCHEMA_VERSION`)

---

## 2. Tablas principales

### Configuracion

| Tabla | Proposito |
|-------|-----------|
| `app_config` | tenant_id, store_id, register_id, hub_url |
| `sync_state` | last_synced_event_id, last_push_at |

### Catalogo

| Tabla | Proposito |
|-------|-----------|
| `categories` | Categorias personalizables (icono, color, orden) |
| `products` | Productos con categoria_id, imagen, barcode, precio base |
| `product_variants` | Presentaciones por producto padre |
| `customers` | Clientes y lista de precios |
| `wholesale_tiers` | Escalas mayoreo |
| `customer_product_prices` | Precios preferenciales |

### Personal y proveedores

| Tabla | Proposito |
|-------|-----------|
| `vendedores` | Personal de venta |
| `proveedores` | Proveedores de mercancia |

### Operacion

| Tabla | Proposito |
|-------|-----------|
| `sales` | Ventas con vendedor_id, estado, turno_caja_id |
| `sale_lines` | Lineas de venta (incluye lote farmacia) |
| `cash_shifts` | Turnos de corte de caja |
| `stock_levels` | Stock por tienda con stock_minimo |

### Inventario avanzado

| Tabla | Proposito |
|-------|-----------|
| `inventory_movements` | Ledger de entradas, salidas y ajustes |
| `transfers` / `transfer_lines` | Traspasos entre sucursales |
| `pharmacy_lots` | Lotes farmacia con caducidad |

### Sync

| Tabla | Proposito |
|-------|-----------|
| `sync_event_queue` | Eventos pendientes de envio |

---

## 3. Estados de venta

| Valor | Significado |
|-------|-------------|
| `completada` | Venta vigente |
| `cancelada` | Anulada; stock revertido |
| `devuelta` | Devolucion aplicada (planificado v4) |

---

## 4. Migraciones

Migraciones incrementales en `posia_database/lib/src/database/migraciones_esquema.dart`:

| Version | Cambio |
|---------|--------|
| v1 | Esquema inicial |
| v2 | Modulos carniceria/farmacia, pharmacy_lots |
| v3 | Categorias, vendedores, proveedores, corte caja, movimientos, traspasos, variantes |

---

## 5. Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-07 18:30 | Esquema v1 inicial |
| 2026-06-11 22:00 | Esquema v3 — tablas operativas ampliadas |
| 2026-06-11 23:00 | Aclaracion: tablas transfers/variants sin UI aun |
