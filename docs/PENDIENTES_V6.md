# POSIA v6 — Backlog de pendientes operativos

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha:** 2026-06-12  
**Estado:** v6.0 completada — v6.1 documentada en [PENDIENTES_V6.1.md](PENDIENTES_V6.1.md)

---

## Resumen

La evaluación v5 (100/100) no refleja la experiencia operativa real. Este documento consolida los pendientes reportados en pruebas de campo y define el plan de trabajo v6.

| Área | Prioridad | Estado |
|------|-----------|--------|
| Acceso / tienda | P0 | ✅ v6.0 |
| Ventas y corte | P0 | ✅ v6.0 |
| Categorías | P0 | ✅ v6.0 |
| Productos | P1 | 📋 v6.1 |
| Inventario / traspasos | P1 | 📋 v6.1 |
| Clientes / proveedores | P2 | 📋 v6.1 |
| Búsqueda global | P1 | ✅ v6.0 (parcial) / 📋 v6.1 (resto) |

---

## 1. Acceso e identidad de tienda

### Requerimiento
- Pantalla de **inicio de sesión** al arrancar para identificar desde qué tienda opera la caja.
- El operador debe ver claramente la tienda activa durante la jornada.

### Alcance v6
- [x] Pantalla de selección de tienda al iniciar (`PantallaAccesoTienda`).
- [x] Persistencia de tienda en configuración del dispositivo.
- [x] Admin → **Tiendas**: alta, baja lógica (desactivar), eliminación.
- [x] Límite de **5 tiendas activas** (alineado con licencia `maxTiendas: 5`).

### Pendiente futuro
- Autenticación por usuario/contraseña por tienda.
- Multi-tenant con selector de tenant en login.

---

## 2. Gestión de tiendas (Admin)

### Requerimiento
- Añadir, desactivar y eliminar tiendas.
- Máximo 5 tiendas activas.

### Implementación
- `TiendaRepository`: `listarTodas`, `guardar`, `contarActivas`.
- `ServicioAdmin`: `registrarTienda`, `actualizarTienda`, `desactivarTienda`, `eliminarTienda`.
- UI: `PantallaTiendasAdmin` en sección Sistema.

---

## 3. Ventas del día (Admin)

### Requerimiento
- Ver **detalle por tienda** en “Ventas de hoy”, no solo totales agregados.

### Problema detectado
- `listarVentasDelDia` usaba frontera de día en **UTC**, ocultando ventas en horario local (México UTC-6).

### Implementación v6
- [x] Corrección de frontera de día local en `VentaRepository`.
- [x] Expansión de filas por tienda con listado de ventas al tocar.
- [x] `listarVentasDelDiaPorTienda` en servicio admin.

---

## 4. Historial de ventas

### Requerimiento
- Mejor UI en detalle de venta (líneas, vendedor, método de pago, hora).
- Posibilidad de **eliminar** ventas (además de anular/devolver).

### Implementación v6
- [x] Bottom sheet de detalle enriquecido.
- [x] `eliminarVenta` con reversión de stock si la venta estaba completada.
- [x] Anular (soft) se mantiene para ventas del turno abierto.

### Pendiente futuro
- Filtro por vendedor, cliente, rango de montos.
- Exportación CSV/PDF.

---

## 5. Ventas no registradas / corte de caja

### Síntomas reportados
- Ventas no aparecen en historial ni en corte de caja.

### Causas raíz identificadas
1. **Turno cerrado**: `validarCobro` bloqueaba el cobro sin turno abierto.
2. **Frontera UTC**: ventas “de hoy” no listadas en reportes locales.
3. **Seed de demo**: turno demo solo para `CAJA_DEMO_1_ID` fijo; otras cajas quedaban sin turno.

### Implementación v6
- [x] Auto-apertura de turno con fondo $0 al cobrar si no hay turno (con registro en corte).
- [x] Seed de presentación usa tienda/caja de `app_config`.
- [x] Mensaje claro en caja cuando no hay turno (antes de auto-apertura).

---

## 6. Vendedores

### Requerimiento
- Mejorar UI de gestión de vendedores.

### Implementación v6
- [x] Tarjetas con avatar, código, estado activo.
- [x] Búsqueda por nombre o código.
- [x] Confirmación al desactivar.

### Pendiente futuro
- Reporte de ventas por vendedor.
- Asignación obligatoria de vendedor antes de cobrar (configurable).

---

## 7. Categorías

### Problemas reportados
- Al crear categoría, la UI mostraba `shopping_basket` (identificador técnico del icono, no el nombre).
- Dos categorías distintas parecían iguales (mismo icono/color por defecto).
- Falta reordenar, cambiar icono y color.

### Implementación v6
- [x] Subtítulo muestra color legible, no clave de icono.
- [x] Selector de icono Material y color al crear/editar.
- [x] Reordenamiento con botones subir/bajar.
- [x] Util compartido `IconosCategoria` en `posia_ui`.

---

## 8. Productos

### Requerimiento
- Alta robusta: categoría obligatoria, múltiples precios (mayoreo, gramaje), empaque (caja/bulto) y unidades de conversión.
- Editar y eliminar productos.
- Mejor UI.

### Estado actual
- Existe alta básica, variantes y asignación de categoría por tap.
- Módulos carnicería/farmacia duplican funcionalidad que debe vivir como **categorías + reglas de precio**.

### Plan v6.1
Ver especificación detallada: **[PENDIENTES_V6.1.md](PENDIENTES_V6.1.md)** §1.

- [ ] Formulario unificado de producto con pestañas: General | Precios | Inventario | Empaque.
- [ ] Integrar `PrecioRepository` para listas mayoreo/menudeo.
- [ ] Unidades de conversión (pieza ↔ caja ↔ bulto).
- [ ] Eliminar producto con validación de stock cero.
- [x] Quitar entradas separadas “Carnicería” y “Farmacia” del menú admin; filtrar por categoría en Productos.

### v6.0 (completado)
- [x] Menú admin consolidado: carnicería/farmacia como categorías, no módulos duplicados.
- [x] Campo de búsqueda en listado de productos.

---

## 9. Búsqueda en todas las secciones

### Requerimiento
- Filtro de búsqueda en cada pantalla de administración.

### Implementación v6
- [x] Widget reutilizable `CampoBusqueda` en `posia_ui`.
- [x] Integrado en: categorías, productos, vendedores, clientes, proveedores, inventario.

### Pendiente
Ver [PENDIENTES_V6.1.md](PENDIENTES_V6.1.md): inventario, movimientos, traspasos, reportes.

---

## 10. Inventario — existencias, movimientos, traspasos

### Problemas reportados
- Existencias, movimientos y traspasos **no funcionan** correctamente.
- UI/UX deficiente.

### Diagnóstico preliminar
- Repositorios existen pero flujos UI incompletos o sin feedback de error.
- Traspasos descuentan stock origen pero recepción depende de tienda destino manual.

### Plan v6.1
Ver **[PENDIENTES_V6.1.md](PENDIENTES_V6.1.md)** §2.

- [ ] Revisar `PantallaInventarioAdmin`: ajuste +/- con motivo y sync.
- [ ] `PantallaMovimientosInventario`: listado filtrable + registro entrada/salida.
- [ ] `PantallaTraspasosAdmin`: flujo guiado origen → destino → confirmar recepción.
- [ ] Tests de integración inventario + traspaso.

---

## 11. Clientes

### Requerimiento
- Características del cliente (contacto, crédito, lista de precios).
- Historial de ventas del cliente.

### Plan v6.1
Ver **[PENDIENTES_V6.1.md](PENDIENTES_V6.1.md)** §3.

- [ ] Ficha de cliente con campos extendidos (teléfono, email, RFC, notas).
- [ ] Pestaña “Ventas” con `listarHistorialVentas` filtrado por `clienteId`.
- [x] Búsqueda incluida en v6.0.

---

## 12. Proveedores

### Requerimiento
- Misma riqueza que clientes: datos de contacto, productos suministrados, historial de compras.

### Plan v6.1
Ver **[PENDIENTES_V6.1.md](PENDIENTES_V6.1.md)** §4.

- [ ] Ficha de proveedor extendida.
- [ ] Relación producto ↔ proveedor (campo `proveedor_id` en producto).
- [ ] Órdenes de compra (v7).

---

## Orden de implementación recomendado

```
Fase A (v6.0 — completada)
├── Acceso tienda + CRUD tiendas
├── Fix ventas UTC + turno auto
├── Categorías completas
├── Historial ventas mejorado + eliminar
├── Ventas hoy por tienda
├── Vendedores UI + búsqueda
└── Menú admin consolidado

Fase B (v6.1) — [especificación](PENDIENTES_V6.1.md)
├── Productos: alta robusta multi-precio
├── Inventario funcional end-to-end
├── Clientes / proveedores enriquecidos
└── Tests E2E admin

Fase C (v7)
├── Compras a proveedores
├── Auth multi-usuario
└── Reportes avanzados
```

---

## Referencias

- [PENDIENTES_V6.1.md](PENDIENTES_V6.1.md) — especificación v6.1 (productos, inventario, clientes)
- [ESTADO_PROYECTO.md](ESTADO_PROYECTO.md) — madurez del proyecto
- [ADMIN.md](ADMIN.md) — panel administrativo
- [MANUAL_USUARIO.md](MANUAL_USUARIO.md) — operación diaria
- [CHANGELOG.md](CHANGELOG.md) — historial de cambios
