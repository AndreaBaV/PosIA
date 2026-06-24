# Control de cambios — POSIA

**Autor:** Equipo POSIA  
**Matrícula:** POSIA-2026-001

Historial consolidado de versiones e implementaciones.

---

## 2026-06-24 — Paridad móvil caja + documentación

### Caja móvil
- Multipago en `PantallaCajaMovil` (efectivo, tarjeta, transferencia, mixto, crédito)
- Tickets en espera: poner, recuperar, eliminar
- Cotización desde carrito + WhatsApp
- Vaciar carrito con confirmación

### Documentación
- Consolidación en 3 documentos: manual técnico, manual de usuario, control de cambios

---

## 2026-06-21 — v1.0 móvil y usuarios seguros

- Versión tienda `1.0.0+1`; AAB firmado para Play Store
- Usuarios: schema v10, PIN hasheado, roles y permisos por tienda
- Workflow GitHub Actions `mobile-release` (Android + iOS)

---

## 2026-06-12 — v6.2 (multipago, descuentos, favoritos, reportes)

### Caja
- Diálogo de cobro: efectivo (cambio), tarjeta, transferencia, mixto, crédito
- Descuento por línea y descuento ticket
- Barra de productos favoritos

### Admin
- Listas de precios (CRUD) + selector en ficha cliente
- Estrella favorito en catálogo productos
- Reportes: top productos + ventas por método de pago

### Backend
- Schema SQLite v6: descuentos, montos mixto, costo_unitario, favorito_caja, price_lists
- `CobroRequest`, `ServicioCaja.cobrar(request)`, corte de caja multipago

---

## 2026-06-12 — v6.1 (productos, inventario, fichas)

### Schema y modelos
- Migración schema v5: campos extendidos en clientes, proveedores y productos
- Modelos `Cliente`, `Proveedor`, `Producto` ampliados; nuevo `ResumenCliente`
- DTO `AltaProductoRequest` para alta completa de productos

### Backend
- `ServicioAdmin`: CRUD producto completo, escalas mayoreo, inventario agrupado
- Fix movimiento tipo `ajuste`; validación salida con stock
- Clientes: ficha, historial ventas, resumen compras
- Proveedores: ficha, vínculo producto-proveedor
- Sync: payloads v5 en producto y cliente

### UI admin
- `pantalla_formulario_producto.dart`: pestañas General/Precios/Empaque/Inventario
- Productos, inventario, movimientos y traspasos reescritos
- `pantalla_ficha_cliente.dart` y `pantalla_ficha_proveedor.dart`

### Tests
- `servicio_admin_v61_test.dart`, `formulario_producto_test.dart`

---

## 2026-06-12 — v6.0 (backlog operativo)

### Acceso y tiendas
- Pantalla selección de tienda (`pantalla_acceso_tienda.dart`)
- Admin CRUD tiendas con límite 5 activas

### Ventas
- Fix frontera de día local en ventas del día
- Auto-apertura de turno al cobrar
- Ventas hoy: detalle expandible por tienda
- Historial: bottom sheet + eliminar venta

### Catálogo
- Categorías: icono/color, reorden
- Menú admin sin entradas duplicadas carnicería/farmacia
- Widget `CampoBusqueda` reutilizable

---

## 2026-06-11 — Revisión v5 (producción)

### Impresora configurable
- ESC/POS red puerto 9100
- Modo archivo / red / ambos con fallback
- UI Admin → Configuración

### Operaciones
- Ticket de corte al cerrar turno
- Reimprimir desde historial
- Tenant ID configurable en UI
- Stock independiente por variante

### Tests
- `generador_ticket_test.dart`, `posia_hardware_test.dart`, `providers_test.dart`

---

## 2026-06-11 — Revisión v4 (nube Neon + pendientes)

### Nube gratuita (Neon + Render)
- SSL automático para hosts Neon
- Dockerfile producción + `render.yaml`
- API Key en pantalla sync

### Sync completo
- `variantUpserted`, `stockAdjusted`, `salePartialReturn`

### Devoluciones parciales
- `devolverLineasVenta()` en servicio admin
- UI en historial; ajuste de turno

### Impresión
- `ArchivoReceiptPrinter` → `Documents/POSIA/tickets`
- `generarTextoTicket()` tras cada cobro

---

## 2026-06-11 — Revisión v3.1 (configuración + variantes)

- Persistencia tenant/tienda/caja en `app_config`
- `TecladoBarcodeScanner` (USB wedge) en caja
- Editar clientes, vendedores, proveedores
- Exportar reportes CSV
- CRUD variantes / presentaciones
- `flutter analyze` sin issues

---

## 2026-06-11 — Revisión v3.0 (piloto operativo)

- Categorías filtrables en caja
- Turno de caja obligatorio para cobrar
- Corte de caja, historial 1/7/30 días con anulación
- Traspasos, movimientos de inventario
- PIN administrativo configurable
- Sync: `saleVoided`, `categoryUpserted`

---

## 2026-06-07 — Inicio del proyecto

- Arquitectura monorepo Flutter + Melos
- Paquetes core, database, pricing, sync, hardware, ui
- Documentación inicial de arquitectura y estándares
