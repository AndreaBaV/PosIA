# POS de escritorio — Funcionalidades y roadmap

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-11 22:00:00 (UTC-6)  
**Ultima modificacion:** 2026-06-11 25:00:00 (UTC-6)

---

## 1. Vision

El POS de escritorio (Windows) es la caja principal del negocio. Debe operar **offline**, con interfaz iconografica para cajeros y un panel administrativo completo para el dueno.

---

## 2. Modulos funcionales

| Modulo | Descripcion | Estado |
|--------|-------------|--------|
| **Categorias** | Clasificacion personalizable; filtro en caja | Disponible |
| **Corte de caja** | Apertura/cierre de turno, fondo inicial, totales | Disponible |
| **Historial de ventas** | Consulta 1/7/30 dias, detalle, anulacion | Disponible |
| **Cancelaciones** | Anular venta; revierte stock y ajusta turno | Disponible |
| **Vendedores** | Alta, edicion, seleccion en caja | Disponible |
| **Clientes** | Alta, edicion, seleccion en caja | Disponible |
| **Proveedores** | Alta, edicion | Disponible |
| **Entradas/salidas** | Movimientos con motivo y auditoria | Disponible |
| **Traspasos** | Solicitud y recepcion entre sucursales | Disponible |
| **Inventario minimo** | Umbral y alertas de faltante | Disponible |
| **Lotes y caducidad** | Modulo farmacia (FEFO, alertas) | Disponible |
| **Variantes** | Presentaciones bajo producto padre | Disponible (piloto) |
| **Escaneo** | Lector USB teclado + entrada manual | Disponible |
| **Config dispositivo** | Tienda/caja/PIN por instalacion | Disponible |
| **Reportes** | Ventas por vendedor; alertas; export CSV | Disponible |
| **Devoluciones** | Devolucion parcial o total de lineas | Disponible |
| **Impresion** | Ticket venta/corte; archivo, red ESC/POS o ambos | Disponible |
| **Reimpresion** | Historial de ventas → Detalle → Reimprimir | Disponible |

Ver [ESTADO_PROYECTO.md](ESTADO_PROYECTO.md) y [CHANGELOG.md](CHANGELOG.md).

---

## 3. Caja (pantalla de venta)

### Barra de categorias

- Chips horizontales con icono y color personalizable
- Categoria **Todos** muestra catalogo completo

### Acciones de caja

| Boton | Funcion |
|-------|---------|
| Escanear | Ingreso manual de codigo de barras |
| Vendedor | Selecciona vendedor activo |
| Cliente | Asigna cliente para precios preferenciales |
| Cancelar | Vacia carrito (con confirmacion) |
| COBRAR | Cierra venta en efectivo; requiere turno abierto |

### Variantes en caja

1. Producto padre con variantes: al tocar muestra dialogo de presentaciones
2. Escaneo: busca primero en variantes, luego en productos
3. Producto padre con variantes no se vende directo por codigo padre

### Escaneo

- `TecladoBarcodeScanner`: lectores USB tipo teclado (terminan en Enter)
- Configurado en `hardwareRegistryProvider` (lee modo impresora de Admin → Configuracion)

---

## 4. Panel de administracion

Ver [ADMIN.md](ADMIN.md). Destacados:

- **Productos** → icono capas: CRUD de variantes
- **Configuracion**: tenant ID, tienda activa, nombre caja, impresora, PIN
- **Reportes**: boton exportar CSV

---

## 5. Esquema de datos (version 3)

Ver [DATABASE.md](DATABASE.md). Tabla `product_variants`:

| Columna | Uso |
|---------|-----|
| `producto_padre_id` | Producto en grilla de caja |
| `nombre` | Presentacion (600ml, 2L) |
| `codigo_barras` | Escaneo independiente |
| `precio_base` | Precio de la presentacion |

---

## 6. Orden de desarrollo restante

1. Impresion de ticket y corte (driver ESC/POS)
2. Devoluciones parciales con seleccion de lineas
3. Sync de variantes al hub (`variantUpserted`)
4. Stock por variante (opcional)
5. Multipago (fuera de alcance actual)

---

## 7. Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-11 22:00 | Documento inicial y roadmap v3 |
| 2026-06-11 25:00 | Estado actualizado post v3.1 |
