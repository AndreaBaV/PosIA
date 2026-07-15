# Auditoría inicial POSIA — rama `mantenimiento`

**Fecha:** 2026-07-12  
**Rama:** `mantenimiento`  
**Alcance:** inventario y diagnóstico (sin refactors en este documento)  
**Criterio de merge a `main`:** solo cuando el cambio correspondiente esté verificado como funcional

---

## 1. Veredicto ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿`ServicioAdmin` (≈5550 líneas) es mantenible así? | **No.** Es un *God Object*: muchos dominios en un solo archivo. |
| ¿Está correctamente modularizado? | **Parcial.** Hay repositorios y otros servicios (`ServicioCaja`, `ServicioReconciliacionHub`, etc.), pero Admin concentra demasiada orquestación. |
| ¿Todo el código se utiliza? | **Casi todo lo “gordo” sí se usa** desde pantallas/providers. Hay piezas **cableadas a null**, stubs o paquetes muy delgados pendientes de madurar. |
| ¿Hay demasiados archivos? | **El volumen es normal** para un POS multi-módulo (~356 `.dart` de lib + app). El problema no es “muchos archivos”, sino **concentración extrema** en pocos archivos enormes. |

---

## 2. `ServicioAdmin` — mapa de responsabilidades

**Archivo:** `packages/posia_database/lib/src/services/servicio_admin.dart`  
**Tamaño:** ~5558 líneas / ~181 KB (el más grande del monorepo, ~3× el segundo).  
**Métodos (aprox.):** ~183 públicos + ~57 privados.

### 2.1 Secciones internas (comentarios `// ---`)

| Rango aprox. | Dominio | Notas |
|--------------|---------|--------|
| 1–230 | Construcción, deps, precio comercial, transacción | Núcleo / DI manual |
| 239–860 | Productos, importación lote, inventario consolidado | Alto tráfico admin + caja |
| 870–1310 | Sync, reconciliación, hub, instalación técnico | Crítico multi-caja; reciente foco de bugs |
| 1314–1386 | Categorías | |
| 1388–1432 | Variantes | |
| 1434–1687 | Clientes + descuentos + precios especiales | |
| 1689–2208 | Vendedores + usuarios + roles | Incluye auth helpers |
| 2210–2431 | Proveedores + compras | |
| 2433–2805 | Pedidos + cotizaciones | |
| 2807–3097 | Configuración dispositivo/caja/etiquetas/créditos | Solapa con `ServicioConfiguracionDispositivo` |
| 3099–3243 | Historial ventas, anulaciones, devoluciones | |
| 3245–3776 | Traspasos tienda/tienda | |
| 3778–3950 | Corte caja + movimientos inventario + alertas | |
| 3951–4177 | Reportes + listas de precios | |
| 4179–5005 | **Emisión de eventos sync** (`_registrarEvento*`) | ~800 líneas mecánicas; primer candidato a extraer |
| 5007–5392 | Almacenes y traspasos almacén | |
| 5394–fin | Presentaciones / tipos presentación | |

### 2.2 Por qué no es mantenible

1. **Un solo tipo** conoce sync, catálogo, usuarios, compras, pedidos, reportes, almacenes y config.
2. **API pública enorme** (~180 métodos): cualquier pantalla Admin acopla a este fachada.
3. **Duplicación de concerns:** config hub también vive en `ServicioConfiguracionDispositivo`; carnicería/farmacia ya tienen servicios aparte pero Admin sigue orquestando precios/productos.
4. **Riesgo de regresión alto:** un cambio de sync toca el mismo archivo que altas de producto o nómina-adjacent users.
5. **Tests:** hay fixtures/tests de Admin, pero cubrir 5500 líneas de forma segura es costoso; conviene partir por dominio antes de ampliar cobertura.

### 2.3 ¿Se usa?

Sí, de forma intensiva. La app no llama siempre `ServicioAdmin` directo: pasa por:

- `servicioAdminProvider` / `contenedorServiciosProvider`
- `admin_providers.dart`, `inventario_admin_providers.dart`, `sync_providers.dart`
- pantallas Admin (productos, clientes, sync, almacenes, etc.)
- utilidades de ticket/crédito/existencias

**Conclusión de uso:** no es “código muerto acumulado”; es **código vivo mal factorizado**. Los `_registrarEvento*` son privados pero indispensables para el espejo Neon.

---

## 3. Extracciones recomendadas (orden sugerido)

Hacerlas **una por PR/commit** en `mantenimiento`, con tests del dominio tocado. No fusionar a `main` hasta validar en laptop + al menos un móvil.

| # | Extracción | Riesgo | Beneficio |
|---|------------|--------|-----------|
| 1 | `AdminEmisorEventosSync` (todos los `_registrarEvento*` + `_idEventoEspejo`) | Bajo | −800 líneas; sync events en un solo sitio |
| 2 | `AdminSyncCatalogo` (`_reencolarCatalogoLocalPendiente`, sync manual/reconciliar wrappers) | Medio | Aísla el área que generó cola basura |
| 3 | `AdminCatalogoProductos` (CRUD producto, import lote, escalas) | Medio | Pantalla productos/import dejan de depender del monstruo |
| 4 | `AdminAlmacenes` | Medio | Dominio ya demarcado por comentarios |
| 5 | `AdminUsuariosRoles` | Medio-alto | Auth + permisos + sync inmediato |
| 6 | Pedidos / cotizaciones / compras / traspasos | Medio | Dominios ya seccionados |
| 7 | Config + reportes | Bajo-medio | Posible unificar con servicios de config existentes |

**Patrón sugerido:** `ServicioAdmin` queda como fachada delgada que delega (sin romper providers/pantallas).

---

## 4. Inventario del monorepo (archivos `.dart` de lib)

| Paquete / app | Archivos lib (aprox.) | Observación |
|---------------|----------------------|-------------|
| `apps/posia_pos/lib` | 95 | UI; varias pantallas grandes |
| `posia_core` | 87 | Modelos/enums/constantes — volumen esperado |
| `posia_database` | 75 | Persistencia + servicios; aquí está el peso real |
| `posia_ui` | 36 | Widgets compartidos |
| `posia_hardware` | 18 | Impresión / stubs hardware |
| `posia_voice` | 10 | Voz Jane — activo vía caja |
| `posia_sync` | 9 | Hub sync; **LAN no cableado** |
| `posia_pricing` | 7 | Motor de precios — usado |
| `posia_licensing` | 3 | Licencia inyectada en providers |
| `posia_inventory` | 3 | Gestor inventario — delgado pero usado |
| `server/` | 13 | Hub API |

**Top archivos por tamaño (señales de deuda):**

1. `servicio_admin.dart` (~181 KB)
2. `pantalla_formulario_producto.dart` (~57 KB)
3. `servicio_caja.dart` (~51 KB)
4. `aplicador_eventos_sqlite.dart` (~50 KB)
5. `pantalla_caja.dart` (~45 KB)
6. `migraciones_esquema.dart` / `migracion_integridad_referencial.dart`

---

## 5. Piezas sospechosas / incompletas (no necesariamente basura)

| Ítem | Evidencia | Acción sugerida (futura) |
|------|-----------|--------------------------|
| `LanSyncClient` | Existe, pero `FabricaServicios` pasa `clienteLan: null` siempre | Documentar como “no productivo” o cablear; no borrar aún |
| Hardware `Scale` / `CustomerDisplay` | Presentes en registry; uso real limitado | Auditar pantallas caja vs stubs |
| `ServicioCarniceria` en database | Existe y se inyecta; lógica también en `posia_core` vertical | Clarificar frontera core vs database |
| Paquetes `posia_licensing` / `posia_inventory` | Muy pocos archivos | OK si son límites de dominio; no fusionar por capricho |
| Exports de `posia_database.dart` | Exporta casi todo el lib útil | Evitar exportar internals al partir Admin |
| Docs `proyecto_jane_voice_*.plan.md` | Plan, no código | Mantener fuera de release o en `docs/` |

**Importante:** “Muchos archivos” en `posia_core` (modelos) y repositorios **no es síntoma de basura**; es separación razonable. La deuda está en **servicios/UI monolíticos**.

---

## 6. Plan de auditoría progresiva (checklist)

Trabajar solo en `mantenimiento`. Marcar al completar.

### Fase A — Sync y datos (prioridad operativa)
- [ ] Validar en dispositivo real el fix de `database_closed` + descarte cola catálogo (cambios ya en working tree de esta rama)
- [ ] Extraer emisor de eventos sync
- [ ] Extraer reencolado / sync manual / reconciliación
- [ ] Revisar `aplicador_eventos_sqlite.dart` (espejo pull Neon)
- [ ] Revisar `sync_orchestrator` + hub client (lotes, pull-first)

### Fase B — `ServicioAdmin` por dominio
- [ ] Productos + importación
- [ ] Almacenes
- [ ] Usuarios / roles
- [ ] Clientes / precios / listas
- [ ] Compras / proveedores
- [ ] Pedidos / cotizaciones
- [ ] Traspasos
- [ ] Reportes / config

### Fase C — App UI
- [ ] `pantalla_formulario_producto.dart`
- [ ] `pantalla_caja.dart` / `pantalla_caja_movil.dart`
- [ ] Providers Admin: ¿demasiada lógica en Riverpod?

### Fase D — Paquetes satélite
- [ ] `posia_hardware`: qué está productivo vs stub
- [ ] `posia_voice`: cobertura y acoplamiento a caja
- [ ] `posia_sync` LAN: decisión keep/wire/remove
- [ ] `server/sync_api`: alineación con cliente Flutter

### Fase E — Limpieza
- [ ] Dead code con analyzer / referencias cero (tras extracciones)
- [ ] Tests de humo por dominio antes de cada merge a `main`

---

## 7. Reglas de trabajo en esta rama

1. **No push a `main`** hasta validar funcionalidad del cambio concreto.
2. Preferir **commits pequeños** por dominio extraído.
3. Mantener **fachada `ServicioAdmin`** mientras existan pantallas acopladas; reducir cuerpo, no romper API de golpe.
4. Cada extracción debe incluir: compile + test del paquete + prueba manual del flujo Admin/caja tocado.
5. Actualizar este documento (sección 6) al cerrar cada ítem.

---

## 8. Estado actual de la rama (contexto)

Al crear este documento, `mantenimiento` incluye cambios locales aún no necesariamente commitados relacionados con:

- Hot-swap SQLite / mitigación `database_closed`
- Descarte de pendientes de catálogo duplicados
- Pull-first + envío por lotes
- IDs estables en upserts de catálogo

Esos cambios son **correctivos de sync**, no de modularización. Conviene:

1. Validarlos / commitearlos aparte en esta rama.
2. Empezar extracciones de `ServicioAdmin` en commits posteriores.

---

## 9. Respuesta directa a la duda de archivos

> “Hay demasiados archivos, no sé si todos sean funcionales.”

- **No hace falta fusionar paquetes** solo por tener pocos archivos (`licensing`, `inventory`).
- **Sí hace falta partir** los 5–6 archivos gigantes listados arriba.
- La mayoría de repositorios/modelos **sí se usan** vía `FabricaServicios` + Admin/Caja.
- Lo “no funcional / incompleto” más claro hoy: **sync LAN deshabilitado** (`clienteLan: null`), no un cementerio de archivos huérfanos.

Cuando quieras empezar el cambio #1 (emisor de eventos), se puede hacer en un commit dedicado sobre esta misma rama.

---

## 10. Actualización 2026-07-15 — rama `refactor/arquitectura-2026-07`

Al retomar esta auditoría se encontró, auditando Neon **en vivo** (no solo el código), que el problema no era únicamente tablas huérfanas: había pérdida real de datos de producción por un bug de sincronización.

### 10.1 Bug de pérdida de datos (corregido, commit `00dfaf0`)

`_registrarEventoCompra` (compras) y `ServicioAsistencia._emitirEvento` (asistencia) generaban el ID del evento con un UUID aleatorio en vez de uno determinístico. Cada reintento de sync creaba un evento "nuevo" que el hub nunca reconocía como el mismo, dejando nómina/asistencia varadas en `sync_events` sin proyectarse a Neon (y generando una tormenta de reintentos en compras: 62 eventos para solo 2 compras reales). Mismo bug que ya tenía nómina, corregido en el mismo commit con el patrón ya usado en el resto de emisores (`_idEventoEspejo`).

Recuperado con backfill de un solo uso (`server/sync_api/bin/backfill_ops_varados.dart`, ya ejecutado): `employee_profiles` 0→2, `payroll_periods` 0→2, `attendance_challenges` 0→1, `attendance_records` 0→2. El servidor también reproyecta esto automáticamente en cada arranque desde ahora (`_reproyectarEventosEspejoPendientes` ampliado).

### 10.2 Tablas huérfanas eliminadas de Neon (`public`)

Confirmadas sin datos (0 filas), sin eventos de sync jamás enviados para su dominio, y explícitamente excluidas por el propio código (`MapaTablasSync.soloLocal` / renombre pre-existente):

- `proveedores` — duplicado huérfano; el código ya renombra `proveedores`(sqlite)→`suppliers`(neon).
- `vendedores` — marcada `soloLocal` en el código, nunca debió sincronizarse.
- `pharmacy_lots` — marcada `soloLocal` en el código, nunca debió sincronizarse.

DDL capturado antes de borrar (ver historial de este chat / commit correspondiente). Esquema restante verificado: 38 tablas intactas, `dart analyze` y tests de `posia_database`/`posia_core`/`server/sync_api` en verde.

### 10.3 Nota de alcance

`orderUpserted`, `variantUpserted`, `lotePromocionReplaced`, `customerDiscountUpserted`, `customerProductPriceUpserted` nunca han sido enviados por ninguna tienda (cero eventos en `sync_events`). Sus tablas en Neon (`orders`, `product_variants`, `lotes_promocion`, `customer_discounts`, `customer_product_prices`) siguen en 0 filas — son features genuinamente no usadas todavía, no un bug de sync. No se tocan.

### 10.4 Registros corruptos en Neon por stubs FK que sí se proyectaron (limpiado)

El usuario reportó tiendas "Tienda", categorías "Categoría" y proveedores "Proveedor" duplicados en la consola de Neon, más categorías duplicadas por nombre (Abarrotes, Aceite/Aceites, Frutos Secos, Semillas). Investigado y confirmado: `_reencolarCatalogoLocalPendiente` solo filtraba proveedores-stub (`esStubFk`); tiendas y categorías-stub se reenviaban sin filtro. Además, `AseguradorPadresFk.asegurarPadresDeTraspaso` creaba una "tienda" falsa (`almacen:alm-1`) cuando el traspaso tenía un almacén como origen/destino, porque no usaba `esAlmacenCodificadoEnTraspaso`/`decodificarAlmacenEnTraspaso` (ya existentes en `traspaso_util.dart`) antes de llamar `asegurarTienda`.

Acciones tomadas (autorizadas explícitamente por el usuario):

- Datos en Neon: fusionadas categorías duplicadas (Abarrotes 134→canónico de 230; Aceite+Aceites→canónico de 16; Frutos Secos 1→canónico de 7; Semillas 17→canónico de 29), reasignando productos antes de borrar el duplicado. Las 4 categorías-stub ("Categoría", 28 productos en total) reasignadas a la categoría canónica de Semillas y borradas. Los 5 proveedores-stub renombrados a "Proveedor 1".."Proveedor 5" (tenían productos/compras reales apuntándoles; no se podían borrar). Las 2 tiendas-stub huérfanas (`tienda-sync`, `almacen:alm-1`, 0 referencias reales verificadas contra 13 tablas) borradas. Script: `server/sync_api/bin/limpieza_placeholders_neon.dart`.
- Código: agregado `esStubFk` a `Categoria` y `Tienda` (mismo patrón que `Proveedor`), consultado en `_registrarEventoCategoria`/`_registrarEventoTienda` y en el filtro de `_reencolarCatalogoLocalPendiente`. Corregido `asegurarPadresDeTraspaso` para reconocer traspasos con destino/origen a almacén.
- `categories` 28→19, `stores` 5→3, `suppliers` sigue en 5 (renombrados, no borrados), `products` se mantiene en 639 (solo se reasignó `categoria_id`, ningún producto se perdió).

### 10.5 Fase 3.1 — Extracción del emisor de eventos sync

Primer paso de la modularización de `ServicioAdmin` (cambio #1 recomendado en la sección 3): se extrajo la construcción de todos los `SyncEvent` a una clase dedicada.

- Nuevo: `packages/posia_database/lib/src/sync/admin_emisor_eventos_sync.dart` — `AdminEmisorEventosSync`, único lugar que arma el payload de cada evento hacia Neon (30 métodos: categoría, rol, cliente, proveedor, compra, cotización, pedido, escalas mayoreo, lote promoción, listas de precios, precios/descuentos de cliente, presentaciones, venta, anulación, devolución parcial, traspaso, variante, ajuste de stock, tienda, usuario, producto, almacén, tipo de presentación). Incluye `_idEventoEspejo` (IDs estables) y los guards `esStubFk` para categoría/proveedor/tienda.
- `ServicioAdmin` pasó de 5,810 a 5,067 líneas (−743). Queda como fachada: construye `_emisorEventos` en el constructor y delega. Los métodos que mezclan lógica de negocio con emisión (`_registrarEventoUsuario` necesita el snapshot del repositorio; `_registrarEventoPedido`/`_registrarEventoLotePromocion` necesitan empujar inmediato condicionalmente; `_registrarEventoTraspasoAlmacen` arma y persiste el `Traspaso` antes de emitir) se quedaron como wrappers delgados en `ServicioAdmin`, no se forzó su extracción.
- Verificado: `dart analyze` limpio en `posia_database` y en `apps/posia_pos` (que consume el paquete), 78 tests de `posia_database` en verde.

Sigue pendiente el resto de la Fase 3 (dividir `ServicioAdmin` por dominio: productos, almacenes, usuarios/roles, clientes/precios, compras/proveedores, pedidos/cotizaciones, traspasos, config/reportes) y las Fases 4-6 (UI grande, paquetes satélite, barrido de código muerto).

### 10.6 Fase 3.2 — Extracción del catálogo de productos

Segundo dominio extraído (CRUD producto, alta con presentaciones/escalas, inventario consolidado/agrupado):

- Nuevo: `packages/posia_database/lib/src/services/admin_catalogo_productos.dart` — `AdminCatalogoProductos`. Dueño único de: listar/obtener producto, `registrarProductoCompleto`, `actualizarProducto`, eliminar/reactivar/eliminar-permanente, `registrarProducto` (legacy), inventario consolidado y agrupado por tienda/almacén, y las validaciones `validarPrecioVenta`/`validarCodigoBarrasUnico` (antes privadas y duplicadas en el flujo de variantes y precios especiales de cliente — ahora un solo lugar, llamado también desde esas secciones de `ServicioAdmin`). Incluye `asegurarPresentacionBase` (antes vivía huérfana cerca de "Presentaciones", solo la usaba producto).
- `ServicioAdmin` pasó de 5,067 a 4,602 líneas (−465). Su API pública no cambió: cada método sigue existiendo con la misma firma, delegando en `_catalogoProductos`. Se mantuvieron en `ServicioAdmin` los métodos que cruzan dominios: `importarProductosLote`/`_resolverCategoriaImportacion`/`_guardarLotePromocionImportado` (mezclan producto+categoría+lote-promoción) y el paso final `sincronizarPresentacionesProducto` tras `registrarProductoCompleto` (requiere `SyncEventRepository`, fuera de este dominio).
- Verificado: `dart analyze` limpio en `posia_database` y `apps/posia_pos`, 78 tests en verde (incluye los específicos de duplicado de código de barras y validación de precio).

Progreso ServicioAdmin: 5,810 → 5,067 → 4,602 líneas.

### 10.7 Fase 3.3 — Extracción del dominio de almacenes

Tercer dominio extraído: catálogo de almacenes e inventario/ajustes por almacén.

- Nuevo: `packages/posia_database/lib/src/services/admin_almacenes.dart` — `AdminAlmacenes`. Dueño de `listarAlmacenes` (con siembra inicial), `registrarAlmacen`, `obtenerResumenAlmacenes`, `obtenerInventarioAlmacen`, `ajustarStockAlmacen`, `listarProductosConStockAlmacen`.
- **No** se movieron `traspasarAlmacenATienda`/`traspasarAlmacenATiendaMultiple`/`traspasarAlmacenAAlmacenMultiple`: dependen de `_registrarEventoTraspasoAlmacen`, que a su vez necesita `TraspasoRepository` — cruzan hacia el dominio de Traspasos (aún no extraído, fase futura). Se quedan en `ServicioAdmin` como el resto de casos de cruce de dominio ya documentados.
- `ServicioAdmin` pasó de 4,602 a 4,468 líneas (−134). API pública sin cambios.
- Verificado: `dart analyze` limpio en `posia_database` y `apps/posia_pos`, 78 tests en verde.

Progreso ServicioAdmin: 5,810 → 5,067 → 4,602 → 4,468 líneas.

### 10.8 Fase 3.4 — Extracción del dominio de proveedores

Cuarto dominio extraído: catálogo de proveedores.

- Nuevo: `packages/posia_database/lib/src/services/admin_proveedores.dart` — `AdminProveedores`. Dueño de `listarProveedores` (filtra `esStubFk`), `registrarProveedor`, `actualizarProveedor`, `eliminarProveedor` (con guarda de compras vía `CompraRepository`), `obtenerProveedor`.
- `vincularProductoProveedor` se quedó en `ServicioAdmin`: muta un `Producto` (dominio de `AdminCatalogoProductos`), es una operación de producto, no de proveedor.
- `ServicioAdmin` pasó de 4,468 a 4,452 líneas (−16; el dominio en sí era chico, ~85 líneas movidas).
- Verificado: `dart analyze` limpio, 78 tests en verde.

**Nota sobre Usuarios/Roles (siguiente en la lista original):** se evaluó y se decidió **no** extraerlo en esta pasada. Es el dominio de mayor riesgo (auth + PIN + permisos + sync inmediato al hub, "Riesgo Medio-alto" ya señalado en la sección 3), y su código real cruza fuertemente hacia Tiendas/Config (`cambiarTiendaActiva`, `_asegurarTiendasAdministrador`, `_sincronizarTiendasDesdeHub`), Vendedores (`_sincronizarVendedorVinculado`) y Hub (`_resolverCodigoUsuarioDisponible`, `_sincronizarInmediatoConHub`). Forzar la extracción ahora, sin poder probar login/PIN en un dispositivo real durante esta sesión, es más riesgo que beneficio. Queda pendiente para una pasada dedicada con prueba manual de login en laptop + móvil antes de fusionar.

Progreso ServicioAdmin: 5,810 → 5,067 → 4,602 → 4,468 → 4,452 líneas.

### 10.9 Fase 3.5 — Extracción del dominio de clientes

Quinto dominio extraído: clientes, su historial de compras, descuentos y precios especiales por cliente-producto (los tres vivían juntos en el archivo original, mismo criterio se mantuvo al extraerlos).

- Nuevo: `packages/posia_database/lib/src/services/admin_clientes.dart` — `AdminClientes`. Dueño de CRUD de cliente, `listarVentasCliente`/`obtenerResumenCliente` (lectura de historial), CRUD de descuentos con su validación, y CRUD de precios especiales cliente-producto (que valida contra `AdminCatalogoProductos.validarPrecioVenta` — primer caso de un dominio nuevo consumiendo la validación reutilizable creada en la Fase 3.2).
- `obtenerVendedor` se quedó en `ServicioAdmin`: estaba mezclado en la sección Clientes pero es dominio de Vendedor, no vale la pena reubicarlo sin extraer Vendedores completo.
- `ServicioAdmin` pasó de 4,452 a 4,313 líneas (−139).
- Verificado: `dart analyze` limpio, 78 tests en verde.

Progreso ServicioAdmin: 5,810 → 5,067 → 4,602 → 4,468 → 4,452 → 4,313 líneas (−1,497 desde el inicio, −26%).

### 10.10 Fase 3.6 — Extracción del dominio de compras

Sexto dominio extraído: alta de compra (con recepción a tienda o almacén) e historial.

- Nuevo: `packages/posia_database/lib/src/services/admin_compras.dart` — `AdminCompras`. Dueño de `obtenerAlmacenPorDefectoCompra`, `registrarCompra` (resuelve ubicaciones, valida, actualiza costo/proveedor de cada producto, mueve stock a tienda o almacén, registra movimiento de inventario, emite eventos), `listarCompras`, `obtenerCompra`. Compone `AdminAlmacenes` (para el almacén por defecto) igual que `AdminClientes` compone `AdminCatalogoProductos`.
- El chequeo de permiso por tienda (`_validarPermisoTienda`, dominio Usuarios) se resolvió llamando directo a `PermisosUsuario.puedeGestionarTienda` (la política en sí, sin estado ni repos) en vez de arrastrar una dependencia hacia el `ServicioAdmin` que aún tiene Usuarios sin extraer.
- Limpieza adicional: el campo `_proveedorRepository` en `ServicioAdmin` quedó muerto tras esta extracción (ya nadie lo leía directo, solo se pasaba a los servicios de dominio) — se eliminó junto con su inicialización.
- `ServicioAdmin` pasó de 4,313 a 4,117 líneas (−196).
- Verificado: `dart analyze` limpio (incluyendo el warning de campo muerto ya resuelto), 78 tests en verde.

Progreso ServicioAdmin: 5,810 → 5,067 → 4,602 → 4,468 → 4,452 → 4,313 → 4,117 líneas (−1,693 desde el inicio, −29%).

### 10.11 Fase 3.7 — Extracción del dominio de pedidos/cotizaciones

Séptimo dominio extraído: consulta, asignación y cambios de estado de pedidos, y consulta/eliminación de cotizaciones.

- Nuevo: `packages/posia_database/lib/src/services/admin_pedidos_cotizaciones.dart` — `AdminPedidosCotizaciones`. Dueño de `listarEmpleadosParaAsignacion`, `listarPedidos*`, `obtenerPedido`, `asignarPedido`, `marcarPedidoEntregado`, `cancelarPedido`, `listarCotizaciones`, `obtenerCotizacion`, `eliminarCotizacion`.
- **No** se movieron `registrarPedido`/`registrarCotizacion` (las altas): dependen de `resolverPrecioComercial`, que es un motor de precios (`MotorPrecio`) todavía embebido directo en `ServicioAdmin` sin su propio dominio extraído. Moverlas habría significado duplicar el motor de precios o crear un acople inverso (la nueva clase llamando de vuelta a `ServicioAdmin`); se dejaron donde están, consistente con el criterio ya usado (compras con permisos de tienda, etc.).
- Los 3 métodos que cambian estado de pedido (`asignarPedido`/`marcarPedidoEntregado`/`cancelarPedido`) delegan la mutación a `AdminPedidosCotizaciones` pero el *push inmediato* del evento se quedó en `ServicioAdmin` vía `_registrarEventoPedido` (que además de emitir, empuja al hub de inmediato) — para no cambiar el comportamiento de sincronización.
- `ServicioAdmin` pasó de 4,117 a 4,027 líneas (−90; el dominio movido es más chico de lo que parece porque `registrarPedido`/`registrarCotizacion`, las partes más largas, se quedaron).
- Verificado: `dart analyze` limpio, 78 tests en verde, `flutter analyze` limpio en `apps/posia_pos`.

**Nota:** el motor de precios (`MotorPrecio`/`resolverPrecioComercial`) es ahora el bloqueo recurrente para extraer Pedidos/Cotizaciones/Ventas completas. Buen candidato para una futura Fase 3.x: "AdminPricing" o similar, que le quitaría esta atadura a varios dominios a la vez.

Progreso ServicioAdmin: 5,810 → 5,067 → 4,602 → 4,468 → 4,452 → 4,313 → 4,117 → 4,027 líneas (−1,783 desde el inicio, −31%).

### 10.12 Fase 3.8 — Extracción del dominio de traspasos (entre tiendas)

Octavo dominio extraído. La sección `// --- Traspasos ---` del archivo original en realidad mezclaba tres cosas por acumulación histórica: gestión de Tiendas (CRUD, importación desde hub), administración de Ventas (`eliminarVenta`, listados), y los traspasos de mercancía en sí. Solo se extrajo lo tercero — lo demás se queda donde estaba, sin relación real con "Traspasos".

- Nuevo: `packages/posia_database/lib/src/services/admin_traspasos.dart` — `AdminTraspasos`. Dueño de `listarTraspasos`, `realizarTraspaso`/`realizarTraspasoMultiple` (traspaso directo en un paso), `solicitarTraspaso`/`recibirTraspaso` (flujo de dos pasos), y `_registrarAuditoriaInventario` (bitácora de movimientos, exclusiva de este dominio — se confirmó que no se usaba en ningún otro lado antes de moverla).
- Traspasos con almacén (`traspasarAlmacenA*`) siguen en `ServicioAdmin` desde la Fase 3.3 — dominio relacionado pero distinto, con su propio `_registrarEventoTraspasoAlmacen`.
- `ServicioAdmin` pasó de 4,027 a 3,754 líneas (−273).
- Verificado: `dart analyze` limpio, 78 tests en verde, `flutter analyze` limpio en `apps/posia_pos`.

Progreso ServicioAdmin: 5,810 → 5,067 → 4,602 → 4,468 → 4,452 → 4,313 → 4,117 → 4,027 → 3,754 líneas (−2,056 desde el inicio, −35%).

### 10.13 Fase 3.9 — Categorías y Variantes

Noveno paso: dos dominios chicos, ambos satélites de Producto.

- Nuevo: `packages/posia_database/lib/src/services/admin_categorias.dart` — `AdminCategorias`. Dueño de `listarCategorias`, `registrarCategoria`, `actualizarCategoria`, `reordenarCategorias`, `eliminarCategoria`. `_resolverCategoriaImportacion` y `asignarCategoriaProducto` se quedaron en `ServicioAdmin` (cruzan hacia Producto/Importación).
- Variantes (`listarVariantes`, `registrarVariante`, `actualizarVariante`) se movieron directo a `AdminCatalogoProductos` en vez de crear una clase nueva de 3 métodos: una variante es, conceptualmente, un sub-recurso de producto, y ya dependía de `validarPrecioVenta` (misma clase).
- Limpieza: `_categoriaRepository` y `_varianteRepository` quedaron muertos en `ServicioAdmin` tras esto — eliminados (mismo patrón que `_proveedorRepository` en la Fase 3.6).
- `ServicioAdmin` pasó de 3,754 a 3,703 líneas (−51; la mayoría de las líneas de estos dominios ya se habían movido o eran delegación mínima).
- Verificado: `dart analyze` limpio, 78 tests en verde, `flutter analyze` limpio en `apps/posia_pos`.

Progreso ServicioAdmin: 5,810 → 5,067 → 4,602 → 4,468 → 4,452 → 4,313 → 4,117 → 4,027 → 3,754 → **3,703** líneas (−2,107 desde el inicio, −36%).
