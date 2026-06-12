# Panel de administracion POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 19:45:00 (UTC-6)  
**Ultima modificacion:** 2026-06-12 (UTC-6)

---

## Acceso

- Al **iniciar la app**: pantalla de seleccion de tienda (`PantallaAccesoTienda`)
- Pestaña **Admin** en barra inferior (requiere PIN)
- PIN por defecto: `1234` (configurable en Admin → Configuracion)
- Teclado numerico visual

---

## Secciones del panel (v6.0)

### Ventas

| Pantalla | Funcion |
|----------|---------|
| Ventas hoy | Total global + **detalle expandible por tienda** |
| Historial | 1/7/30 dias; bottom sheet detalle; anular, devolver, **eliminar** |
| Corte de caja | Apertura/cierre de turno (auto-apertura al cobrar si no hay turno) |
| Vendedores | Tarjetas, busqueda, alta, edicion, activar/desactivar |

### Catalogo

| Pantalla | Funcion |
|----------|---------|
| Categorias | Crear con **icono y color**, reordenar, editar, activar/desactivar |
| Productos | Alta basica, busqueda, asignar categoria, variantes (icono capas) |

> **Nota v6.0:** Las entradas separadas Carniceria/Farmacia fueron eliminadas del menu. Esas verticals se gestionan como **categorias** dentro de Productos. Alta robusta planificada en [PENDIENTES_V6.1.md](PENDIENTES_V6.1.md).

### Inventario

| Pantalla | Funcion | Estado |
|----------|---------|--------|
| Existencias | Stock multi-tienda; configurar minimo | Parcial — ver v6.1 |
| Movimientos | Entradas, salidas, ajustes | Parcial — ver v6.1 |
| Traspasos | Solicitar y recibir entre sucursales | Parcial — ver v6.1 |

### Personas

| Pantalla | Funcion | Estado |
|----------|---------|--------|
| Clientes | Alta, editar, busqueda, activar/desactivar | Ficha enriquecida → v6.1 |
| Proveedores | Alta, editar, busqueda, activar/desactivar | Ficha enriquecida → v6.1 |

### Reportes y sistema

| Pantalla | Funcion |
|----------|---------|
| **Tiendas** | Alta, edicion, desactivar, eliminar (max **5 activas**) |
| Reportes | Ventas por vendedor (7 dias); alertas; export CSV |
| Sincronizar | Hub, cola, sync manual |
| Configuracion | Tenant, tienda activa, nombre caja, PIN, impresora |

---

## Variantes (presentaciones)

Ruta: **Admin → Productos → icono capas** en un producto.

| Accion | Descripcion |
|--------|-------------|
| Agregar | Nombre, SKU, codigo barras, precio |
| Editar | Tocar fila de variante |
| Activar/desactivar | Interruptor en cada fila |

En caja, el producto padre con variantes abre selector de presentacion.

---

## Configuracion del dispositivo

Persistido en tabla `app_config`:

| Clave | Valor |
|-------|-------|
| `tenant_id` | UUID del tenant Neon |
| `store_id` / `tienda_id` | Tienda activa |
| `register_id` / `caja_id` | Identificador de caja |
| `pin_admin` | PIN de 4 digitos |
| `printer_mode` | archivo / red / ambos |
| `printer_host` | IP impresora ESC/POS |
| `printer_port` | Puerto (default 9100) |

Cambiar tenant o tienda requiere **reiniciar la app** para reconstruir servicios.

---

## Roadmap admin

| Version | Entregables |
|---------|-------------|
| **v6.0** ✅ | Login tienda, CRUD tiendas, categorias completas, ventas fix, busqueda parcial |
| **v6.1** 📋 | [Especificacion completa](PENDIENTES_V6.1.md) |
| **v7** | Compras a proveedores, auth multi-usuario, reportes avanzados |

---

## Referencias

- [PENDIENTES_V6.md](PENDIENTES_V6.md) — backlog v6.0
- [PENDIENTES_V6.1.md](PENDIENTES_V6.1.md) — especificacion v6.1
- [MANUAL_USUARIO.md](MANUAL_USUARIO.md) — operacion diaria en caja
