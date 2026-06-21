# Registro de cambios POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001

Historial consolidado de implementaciones del POS de escritorio.

---

## 2026-06-12 — v6.2 (multipago, descuentos, favoritos, reportes)

Documentacion: ver seccion v6.2 abajo.

### Caja
- Dialogo de cobro: efectivo (cambio), tarjeta, transferencia, mixto, credito
- Descuento por linea (tocar carrito) y descuento ticket
- Barra de productos favoritos

### Admin
- Listas de precios (CRUD) + selector en ficha cliente
- Estrella favorito en catalogo productos
- Reportes: top productos + ventas por metodo de pago

### Backend
- Schema SQLite v6: descuentos, montos mixto, costo_unitario, favorito_caja, price_lists
- `CobroRequest`, `ServicioCaja.cobrar(request)`, corte de caja multipago

---

## 2026-06-12 — v6.1 (productos, inventario, fichas)

Documentacion: [ADMIN.md](ADMIN.md), [MANUAL_USUARIO.md](MANUAL_USUARIO.md).

### Schema y modelos
- Migracion schema v5: campos extendidos en clientes, proveedores y productos
- Modelos `Cliente`, `Proveedor`, `Producto` ampliados; nuevo `ResumenCliente`
- DTO `AltaProductoRequest` para alta completa de productos

### Backend
- `ServicioAdmin`: CRUD producto completo, escalas mayoreo, inventario agrupado
- Fix movimiento tipo `ajuste` (cantidad absoluta); validacion salida con stock
- Clientes: ficha, historial ventas, resumen compras
- Proveedores: ficha, vinculo producto-proveedor
- Sync: payloads v5 en producto y cliente

### UI admin
- `pantalla_formulario_producto.dart`: pestanas General/Precios/Empaque/Inventario
- Productos, inventario, movimientos y traspasos reescritos con busqueda y nombres legibles
- `pantalla_ficha_cliente.dart` y `pantalla_ficha_proveedor.dart`
- Listados clientes/proveedores navegan a fichas enriquecidas

### Tests
- `servicio_admin_v61_test.dart`: producto, inventario, traspaso, ventas cliente
- `formulario_producto_test.dart`: validacion categoria obligatoria

---

## 2026-06-12 — Documentacion v6.1

- Actualizados: [ADMIN.md](ADMIN.md), [MANUAL_USUARIO.md](MANUAL_USUARIO.md)

---

## 2026-06-12 — v6.0 (backlog operativo)

Documentacion: [CHANGELOG.md](CHANGELOG.md) (esta seccion).

### Acceso y tiendas
- Pantalla de seleccion de tienda al iniciar (`pantalla_acceso_tienda.dart`)
- Admin CRUD tiendas con limite 5 activas (`pantalla_tiendas_admin.dart`)

### Ventas
- Fix frontera de dia local en `VentaRepository.listarVentasDelDia`
- Auto-apertura de turno al cobrar sin turno abierto
- Ventas hoy: detalle expandible por tienda
- Historial: bottom sheet de detalle + eliminar venta
- Seed demo usa tienda/caja de `app_config`

### Catalogo
- Categorias: selector icono/color, reorden, sin mostrar claves tecnicas
- Menu admin sin entradas duplicadas carniceria/farmacia
- Widget `CampoBusqueda` reutilizable

### UI
- Vendedores con tarjetas y busqueda
- Productos con busqueda

---

## 2026-06-11 — Revision v5 (produccion 100%)

### Impresora configurable

| Cambio | Archivos |
|--------|----------|
| ESC/POS red puerto 9100 | `escpos_network_printer.dart` |
| Modo archivo / red / ambos con fallback | `impresora_configurable.dart` |
| Config en `app_config` | `config_repository.dart`, `config_impresora.dart` |
| UI Admin → Configuracion | `pantalla_configuracion_admin.dart` |
| Provider hardware dinamico | `app_providers.dart` |

### Operaciones de tienda

- Ticket de corte al cerrar turno (`generarTextoCorteCaja`, `pantalla_corte_caja.dart`)
- Reimprimir ticket desde historial (`pantalla_historial_ventas.dart`)
- Tenant ID configurable en UI; licencia lee config
- Stock independiente por variante + seed demo

### Tests

- `generador_ticket_test.dart`, `posia_hardware_test.dart`, `providers_test.dart`

---

## 2026-06-11 — Revision v4 (nube Neon + pendientes)

### Nube gratuita (Neon + Render)

| Cambio | Archivos |
|--------|----------|
| SSL automatico para hosts Neon | `almacen_eventos_postgres.dart` |
| Dockerfile produccion + `render.yaml` | `server/sync_api/` |
| Guia despliegue | `docs/DEPLOYMENT.md` |
| API Key en pantalla sync | `pantalla_sync_admin.dart` |

### Sync completo local ↔ nube

- `variantUpserted` — emit + aplicar
- `stockAdjusted` — emit en movimientos inventario
- `salePartialReturn` — devoluciones parciales multi-caja

### Devoluciones parciales

- `devolverLineasVenta()` en `servicio_admin.dart`
- UI en historial de ventas
- Ajuste de turno de caja

### Impresion de tickets

- `ArchivoReceiptPrinter` → `Documents/POSIA/tickets`
- `generarTextoTicket()` tras cada cobro

---

## 2026-06-11 — Revision v3.1 (configuracion + variantes)

### Configuracion del dispositivo

| Cambio | Archivos clave |
|--------|----------------|
| Persistencia tenant/tienda/caja en `app_config` | `config_repository.dart`, `config_dispositivo.dart` |
| Lectura automatica al arrancar servicios | `fabrica_servicios.dart`, `app_providers.dart` |
| UI Admin → Configuracion: tienda, nombre caja, PIN | `pantalla_configuracion_admin.dart` |

Claves en `app_config`: `tenant_id`, `tienda_id`, `caja_id`, `caja_nombre`.

### Escaneo de codigos

| Cambio | Archivos clave |
|--------|----------------|
| Driver `TecladoBarcodeScanner` (USB wedge) | `teclado_barcode_scanner.dart` |
| Escucha activa en pantalla de caja | `pantalla_caja.dart` |
| Boton **Escanear** para entrada manual | `pantalla_caja.dart` |
| Busqueda por variante y luego por producto | `servicio_caja.dart` |

### CRM y reportes

| Cambio | Archivos clave |
|--------|----------------|
| Editar clientes, vendedores, proveedores (tocar fila) | `pantalla_*_admin.dart` |
| Exportar reportes CSV al portapapeles | `pantalla_reportes_admin.dart` |
| Tienda activa dinamica (sin IDs demo hardcodeados) | historial, inventario, traspasos, reportes |

### Variantes / presentaciones

| Cambio | Archivos clave |
|--------|----------------|
| Repositorio SQLite `product_variants` | `variante_repository.dart` |
| CRUD en Admin → Productos → icono capas | `pantalla_variantes_admin.dart` |
| Selector de presentacion en caja | `pantalla_caja.dart`, `servicio_caja.dart` |
| Demo: Coca-Cola con 600ml y 2L | `datos_demo.dart` |

### Calidad

- `flutter analyze`: sin issues
- Tests `posia_database` y `posia_ui`: OK

---

## 2026-06-11 — Revision v3.0 (piloto operativo)

### Caja y admin base

- Categorias filtrables en caja
- Turno de caja obligatorio para cobrar
- Corte de caja (apertura/cierre)
- Historial 1/7/30 dias con anulacion
- Traspasos entre sucursales
- Movimientos de inventario
- PIN administrativo configurable
- Sync: `saleVoided`, `categoryUpserted`
- Asignacion de categoria y stock minimo desde admin

---

## 2026-06-21 — v1.0 móvil y usuarios seguros

- Version tienda `1.0.0+1`; AAB firmado para Play Store
- Usuarios: schema v10, PIN hasheado, roles y permisos por tienda
- Documentacion consolidada en `docs/README.md`
- Publicacion: [PUBLICACION_MOVIL.md](PUBLICACION_MOVIL.md), [PRIVACIDAD.md](PRIVACIDAD.md)

---

## Como leer este registro

| Documento | Audiencia |
|-----------|-----------|
| [MANUAL_USUARIO.md](MANUAL_USUARIO.md) | Cajeros y dueños de tienda |
| [ADMIN.md](ADMIN.md) | Panel administrativo |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Despliegue e infraestructura |
| [README.md](README.md) | Indice de documentacion |
